-- Repairs permanent patient deletion, blocks resurrection of deleted records,
-- and closes privilege/forgery gaps in auth profile creation and audit inserts.
BEGIN;

-- -----------------------------------------------------------------------------
-- 1. Audit trigger: a hard-deleted patient cannot be referenced by the audit
--    row written for its own deletion (audit_logs.patient_id is a foreign key),
--    and the retired consultations table must never be queried.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.medsentry_audit_row()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  row_data jsonb;
  old_data jsonb;
  new_data jsonb;
  target_id text;
  target_clinic_id uuid;
  target_patient_id uuid;
  operation_action text;
BEGIN
  IF TG_OP <> 'INSERT' THEN old_data := to_jsonb(OLD); END IF;
  IF TG_OP <> 'DELETE' THEN new_data := to_jsonb(NEW); END IF;
  row_data := COALESCE(new_data, old_data);
  target_id := row_data ->> 'id';
  target_clinic_id := NULLIF(row_data ->> 'clinic_id', '')::uuid;
  target_patient_id := CASE
    WHEN TG_TABLE_NAME = 'patients' AND TG_OP = 'DELETE' THEN NULL
    WHEN TG_TABLE_NAME = 'patients' THEN NULLIF(target_id, '')::uuid
    ELSE NULLIF(row_data ->> 'patient_id', '')::uuid
  END;

  -- A dependent row deleted together with its patient must not reference it.
  IF target_patient_id IS NOT NULL AND TG_OP = 'DELETE' AND NOT EXISTS (
    SELECT 1 FROM public.patients AS p WHERE p.id = target_patient_id
  ) THEN
    target_patient_id := NULL;
  END IF;

  IF TG_TABLE_NAME = 'users' THEN
    IF TG_OP = 'INSERT' THEN
      operation_action := 'CREATE_USER';
    ELSIF TG_OP = 'DELETE' THEN
      operation_action := 'DELETE_USER';
    ELSIF old_data ->> 'role' IS DISTINCT FROM new_data ->> 'role' THEN
      operation_action := 'CHANGE_ROLE';
    ELSE
      operation_action := 'UPDATE_USER';
    END IF;
  ELSE
    operation_action := CASE
      WHEN TG_OP = 'UPDATE'
        AND old_data ->> 'deleted_at' IS NULL
        AND new_data ->> 'deleted_at' IS NOT NULL THEN 'DELETE_'
      WHEN TG_TABLE_NAME = 'patients' AND TG_OP = 'UPDATE'
        AND old_data ->> 'is_archived' = 'false'
        AND new_data ->> 'is_archived' = 'true' THEN 'DELETE_'
      WHEN TG_OP = 'INSERT' THEN 'CREATE_'
      WHEN TG_OP = 'UPDATE' THEN 'UPDATE_'
      ELSE 'DELETE_'
    END || upper(CASE TG_TABLE_NAME
      WHEN 'audit_logs' THEN 'audit_log'
      WHEN 'system_settings' THEN 'settings'
      ELSE rtrim(TG_TABLE_NAME, 's')
    END);
  END IF;

  INSERT INTO public.audit_logs
    (clinic_id, user_id, action, entity_type, entity_id, patient_id, old_values, new_values)
  VALUES
    (target_clinic_id, public.medsentry_current_user_id(), operation_action, TG_TABLE_NAME,
     target_id, target_patient_id, old_data, new_data);
  RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION public.medsentry_audit_row() FROM PUBLIC, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 2. Sync deletes. The previous version deleted from queue_items (dropped on
--    2026-10-08) and issued_certificates (never a server table), so every
--    permanent patient delete failed with "relation does not exist".
--    Deletion is idempotent: a retry after a lost response succeeds quietly,
--    and a tombstone is written only for a row this actor actually removed.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.medsentry_apply_sync_delete(entity text, target_record_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  actor_id uuid;
  actor_clinic_id uuid;
  is_super boolean;
  resolved_clinic_id uuid;
BEGIN
  actor_id := public.medsentry_current_user_id();
  actor_clinic_id := public.medsentry_current_clinic_id();
  is_super := public.medsentry_is_super_admin();

  IF actor_id IS NULL THEN
    RAISE EXCEPTION 'active user session required' USING ERRCODE = '42501';
  END IF;

  CASE entity
    WHEN 'patients' THEN
      SELECT clinic_id INTO resolved_clinic_id
      FROM public.patients
      WHERE id = target_record_id
        AND (is_super OR clinic_id = actor_clinic_id)
      FOR UPDATE;

      IF resolved_clinic_id IS NOT NULL THEN
        -- Other devices drop their local document copies from these tombstones.
        INSERT INTO public.sync_tombstones (clinic_id, entity_type, record_id, deleted_by)
        SELECT d.clinic_id, 'documents', d.id, actor_id
        FROM public.documents AS d
        WHERE d.patient_id = target_record_id
        ON CONFLICT (clinic_id, entity_type, record_id) DO NOTHING;

        DELETE FROM public.documents WHERE patient_id = target_record_id;
        DELETE FROM public.patients WHERE id = target_record_id;
      END IF;

    WHEN 'documents' THEN
      UPDATE public.documents SET deleted_at = COALESCE(deleted_at, now())
      WHERE id = target_record_id
        AND (is_super OR clinic_id = actor_clinic_id)
      RETURNING clinic_id INTO resolved_clinic_id;

    WHEN 'generated_reports' THEN
      UPDATE public.generated_reports SET deleted_at = COALESCE(deleted_at, now())
      WHERE id = target_record_id
        AND (is_super OR clinic_id = actor_clinic_id)
      RETURNING clinic_id INTO resolved_clinic_id;

    ELSE
      RAISE EXCEPTION 'unsupported sync delete type' USING ERRCODE = '22023';
  END CASE;

  IF resolved_clinic_id IS NULL THEN
    RETURN;
  END IF;

  INSERT INTO public.sync_tombstones (clinic_id, entity_type, record_id, deleted_by)
  VALUES (resolved_clinic_id, entity, target_record_id, actor_id)
  ON CONFLICT (clinic_id, entity_type, record_id) DO NOTHING;
END;
$$;

REVOKE ALL ON FUNCTION public.medsentry_apply_sync_delete(text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.medsentry_apply_sync_delete(text, uuid) TO authenticated;

CREATE INDEX IF NOT EXISTS documents_patient_idx ON public.documents (patient_id);

-- -----------------------------------------------------------------------------
-- 3. A device holding a stale, unsynced copy of a deleted record must not
--    re-create it. Clients recognise SQLSTATE MS410 and drop their copy.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.medsentry_block_tombstoned_insert()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.sync_tombstones AS t
    WHERE t.clinic_id = NEW.clinic_id
      AND t.entity_type = TG_TABLE_NAME
      AND t.record_id = NEW.id
  ) THEN
    RAISE EXCEPTION '% record % was deleted', TG_TABLE_NAME, NEW.id
      USING ERRCODE = 'MS410';
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.medsentry_block_tombstoned_insert() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS patients_block_tombstoned ON public.patients;
CREATE TRIGGER patients_block_tombstoned
  BEFORE INSERT ON public.patients
  FOR EACH ROW EXECUTE FUNCTION public.medsentry_block_tombstoned_insert();

DROP TRIGGER IF EXISTS documents_block_tombstoned ON public.documents;
CREATE TRIGGER documents_block_tombstoned
  BEFORE INSERT ON public.documents
  FOR EACH ROW EXECUTE FUNCTION public.medsentry_block_tombstoned_insert();

-- -----------------------------------------------------------------------------
-- 4. Profile creation must not trust raw_user_meta_data: any signed-in user
--    can rewrite it with auth.updateUser({ data: { role: 'super_admin' } }).
--    Only server-controlled app metadata is honoured; otherwise the
--    provision-user function creates the profile explicitly.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.medsentry_create_profile_for_auth_user()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  requested_role text;
BEGIN
  IF NEW.email IS NULL THEN RETURN NEW; END IF;
  IF EXISTS (SELECT 1 FROM public.users WHERE auth_user_id = NEW.id) THEN
    RETURN NEW;
  END IF;

  requested_role := NEW.raw_app_meta_data ->> 'role';
  IF requested_role IS NULL OR requested_role NOT IN ('super_admin', 'admin', 'staff') THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.users (auth_user_id, email, first_name, last_name, role, clinic_id)
  VALUES (
    NEW.id,
    lower(NEW.email),
    COALESCE(NULLIF(NEW.raw_user_meta_data ->> 'first_name', ''), split_part(NEW.email, '@', 1)),
    COALESCE(NULLIF(NEW.raw_user_meta_data ->> 'last_name', ''), ''),
    requested_role,
    CASE WHEN requested_role = 'super_admin' THEN NULL
         ELSE NULLIF(NEW.raw_app_meta_data ->> 'clinic_id', '')::uuid
    END
  )
  ON CONFLICT DO NOTHING;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.medsentry_create_profile_for_auth_user() FROM PUBLIC, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 5. Audit log inserts: a clinic user may record actions only for their own
--    clinic and only on behalf of users of that clinic (shared devices).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.medsentry_user_in_current_clinic(target_user_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users AS u
    WHERE u.id = target_user_id
      AND u.clinic_id = public.medsentry_current_clinic_id()
  );
$$;

REVOKE ALL ON FUNCTION public.medsentry_user_in_current_clinic(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.medsentry_user_in_current_clinic(uuid) TO authenticated;

DROP POLICY IF EXISTS audit_logs_insert ON public.audit_logs;
CREATE POLICY audit_logs_insert ON public.audit_logs FOR INSERT TO authenticated
  WITH CHECK (
    (SELECT public.medsentry_is_super_admin()) OR (
      (SELECT public.medsentry_current_role()) IN ('admin', 'staff') AND
      clinic_id = (SELECT public.medsentry_current_clinic_id()) AND
      (user_id IS NULL OR public.medsentry_user_in_current_clinic(user_id))
    )
  );

-- -----------------------------------------------------------------------------
-- 6. Audit logs only grow. occurred_at is supplied by clients (offline devices
--    upload old entries late), so incremental pulls page by a server-assigned
--    arrival time instead of downloading the whole table on every sync.
-- -----------------------------------------------------------------------------
ALTER TABLE public.audit_logs
  ADD COLUMN IF NOT EXISTS recorded_at timestamptz NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS audit_logs_clinic_recorded_idx
  ON public.audit_logs (clinic_id, recorded_at);

-- -----------------------------------------------------------------------------
-- 7. Evaluate the session helpers once per statement instead of once per row.
--    Full-table sync pulls otherwise run three profile lookups per row.
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS patients_access ON public.patients;
CREATE POLICY patients_access ON public.patients FOR ALL TO authenticated
  USING (
    (SELECT public.medsentry_is_super_admin()) OR
    ((SELECT public.medsentry_current_role()) IN ('admin', 'staff') AND
     clinic_id = (SELECT public.medsentry_current_clinic_id()))
  )
  WITH CHECK (
    (SELECT public.medsentry_is_super_admin()) OR
    ((SELECT public.medsentry_current_role()) IN ('admin', 'staff') AND
     clinic_id = (SELECT public.medsentry_current_clinic_id()))
  );

DROP POLICY IF EXISTS documents_access ON public.documents;
CREATE POLICY documents_access ON public.documents FOR ALL TO authenticated
  USING (
    deleted_at IS NULL AND (
      (SELECT public.medsentry_is_super_admin()) OR
      ((SELECT public.medsentry_current_role()) IN ('admin', 'staff') AND
       clinic_id = (SELECT public.medsentry_current_clinic_id()))
    )
  )
  WITH CHECK (
    deleted_at IS NULL AND (
      (SELECT public.medsentry_is_super_admin()) OR
      ((SELECT public.medsentry_current_role()) IN ('admin', 'staff') AND
       clinic_id = (SELECT public.medsentry_current_clinic_id()))
    )
  );

DROP POLICY IF EXISTS audit_logs_read ON public.audit_logs;
CREATE POLICY audit_logs_read ON public.audit_logs FOR SELECT TO authenticated
  USING (
    (SELECT public.medsentry_is_super_admin()) OR
    ((SELECT public.medsentry_current_role()) = 'admin' AND
     clinic_id = (SELECT public.medsentry_current_clinic_id()))
  );

DROP POLICY IF EXISTS sync_tombstones_access ON public.sync_tombstones;
CREATE POLICY sync_tombstones_access ON public.sync_tombstones FOR ALL TO authenticated
  USING (
    (SELECT public.medsentry_is_super_admin()) OR
    ((SELECT public.medsentry_current_role()) IN ('admin', 'staff') AND
     clinic_id = (SELECT public.medsentry_current_clinic_id()))
  )
  WITH CHECK (
    (SELECT public.medsentry_is_super_admin()) OR
    ((SELECT public.medsentry_current_role()) IN ('admin', 'staff') AND
     clinic_id = (SELECT public.medsentry_current_clinic_id()))
  );

DROP POLICY IF EXISTS generated_reports_access ON public.generated_reports;
CREATE POLICY generated_reports_access ON public.generated_reports FOR ALL TO authenticated
  USING (
    deleted_at IS NULL AND (
      (SELECT public.medsentry_is_super_admin()) OR
      ((SELECT public.medsentry_current_role()) IN ('admin', 'staff') AND
       clinic_id = (SELECT public.medsentry_current_clinic_id()))
    )
  )
  WITH CHECK (
    deleted_at IS NULL AND (
      (SELECT public.medsentry_is_super_admin()) OR
      ((SELECT public.medsentry_current_role()) IN ('admin', 'staff') AND
       clinic_id = (SELECT public.medsentry_current_clinic_id()))
    )
  );

COMMIT;
