-- Fresh MedSentry Supabase schema. Apply with `supabase db reset` or
-- `supabase migration up` against an empty project.
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

CREATE TABLE public.users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_user_id uuid UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL,
  email text NOT NULL,
  first_name text NOT NULL,
  last_name text NOT NULL,
  role text NOT NULL DEFAULT 'staff' CHECK (role IN ('admin', 'staff')),
  license_number text,
  specialization text,
  contact_number text,
  profile_image_url text,
  is_active boolean NOT NULL DEFAULT true,
  pin_enabled boolean NOT NULL DEFAULT false,
  last_login_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT users_email_not_blank CHECK (length(btrim(email)) > 0)
);

CREATE UNIQUE INDEX users_email_lower_uidx ON public.users (lower(email));
CREATE INDEX users_role_active_idx ON public.users (role, is_active);

CREATE TABLE public.patients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  first_name text NOT NULL,
  last_name text NOT NULL,
  middle_name text,
  suffix text,
  date_of_birth timestamptz,
  gender text,
  civil_status text,
  religion text,
  contact_number text,
  email text,
  address text,
  barangay text,
  purok_sitio text,
  city text,
  province text,
  zip_code text,
  philhealth_number text,
  philhealth_category text,
  local_lgu_id text,
  blood_type text,
  emergency_contact_name text,
  emergency_contact_number text,
  emergency_contact_relation text,
  occupation text,
  employer text,
  is_pwd boolean NOT NULL DEFAULT false,
  is_solo_parent boolean NOT NULL DEFAULT false,
  is_indigenous_person boolean NOT NULL DEFAULT false,
  tribe_ethnolinguistic_group text,
  is_4ps_beneficiary boolean NOT NULL DEFAULT false,
  household_id_number text,
  water_source text,
  toilet_facility text,
  height double precision CHECK (height IS NULL OR height > 0),
  weight double precision CHECK (weight IS NULL OR weight > 0),
  allergies text,
  medical_history text,
  category text,
  is_archived boolean NOT NULL DEFAULT false,
  archived_at timestamptz,
  last_visit_date timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT patients_name_not_blank CHECK (
    length(btrim(first_name)) > 0 AND length(btrim(last_name)) > 0
  )
);

CREATE INDEX patients_name_idx ON public.patients (lower(last_name), lower(first_name));
CREATE INDEX patients_barangay_idx ON public.patients (barangay) WHERE NOT is_archived;
CREATE INDEX patients_active_idx ON public.patients (updated_at DESC) WHERE NOT is_archived;
CREATE UNIQUE INDEX patients_philhealth_uidx ON public.patients
  (regexp_replace(upper(philhealth_number), '[^A-Z0-9]', '', 'g'))
  WHERE philhealth_number IS NOT NULL AND btrim(philhealth_number) <> '';
CREATE UNIQUE INDEX patients_lgu_id_uidx ON public.patients (lower(btrim(local_lgu_id)))
  WHERE local_lgu_id IS NOT NULL AND btrim(local_lgu_id) <> '';

CREATE TABLE public.queue_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id uuid NOT NULL REFERENCES public.patients(id) ON DELETE RESTRICT,
  is_senior boolean NOT NULL DEFAULT false,
  is_pregnant boolean NOT NULL DEFAULT false,
  is_pwd boolean NOT NULL DEFAULT false,
  is_infant boolean NOT NULL DEFAULT false,
  arrival_time timestamptz NOT NULL DEFAULT now(),
  start_time timestamptz,
  end_time timestamptz,
  status text NOT NULL DEFAULT 'waiting'
    CHECK (status IN ('waiting', 'inProgress', 'completed', 'cancelled')),
  nurse_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  doctor_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  complaint text,
  notes text,
  purpose text,
  temperature double precision CHECK (temperature IS NULL OR temperature > 0),
  blood_pressure_systolic double precision CHECK (
    blood_pressure_systolic IS NULL OR blood_pressure_systolic > 0
  ),
  blood_pressure_diastolic double precision CHECK (
    blood_pressure_diastolic IS NULL OR blood_pressure_diastolic > 0
  ),
  heart_rate double precision CHECK (heart_rate IS NULL OR heart_rate > 0),
  respiratory_rate double precision CHECK (respiratory_rate IS NULL OR respiratory_rate > 0),
  oxygen_saturation double precision CHECK (
    oxygen_saturation IS NULL OR oxygen_saturation BETWEEN 0 AND 100
  ),
  weight double precision CHECK (weight IS NULL OR weight > 0),
  height double precision CHECK (height IS NULL OR height > 0),
  red_flags jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(red_flags) = 'array'),
  pain_scale integer CHECK (pain_scale IS NULL OR pain_scale BETWEEN 0 AND 10),
  is_essentially_normal boolean NOT NULL DEFAULT false,
  priority text NOT NULL DEFAULT 'normal'
    CHECK (priority IN ('low', 'normal', 'high', 'emergency')),
  room_number text,
  bmi double precision CHECK (bmi IS NULL OR bmi > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  UNIQUE (id, patient_id),
  CHECK (start_time IS NULL OR start_time >= arrival_time),
  CHECK (end_time IS NULL OR start_time IS NULL OR end_time >= start_time)
);

CREATE INDEX queue_status_arrival_idx ON public.queue_items (status, arrival_time);
CREATE INDEX queue_patient_idx ON public.queue_items (patient_id, arrival_time DESC);
CREATE INDEX queue_staff_idx ON public.queue_items (nurse_id, doctor_id);

CREATE TABLE public.consultations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id uuid NOT NULL REFERENCES public.patients(id) ON DELETE RESTRICT,
  queue_id uuid,
  doctor_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  consultation_date timestamptz,
  subjective text,
  objective text,
  assessment text,
  plan text,
  icd10_code text,
  icd10_description text,
  is_follow_up boolean NOT NULL DEFAULT false,
  follow_up_instructions text,
  notes text,
  created_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  UNIQUE (id, patient_id),
  FOREIGN KEY (queue_id, patient_id)
    REFERENCES public.queue_items(id, patient_id) ON DELETE RESTRICT
);

CREATE INDEX consultations_patient_date_idx
  ON public.consultations (patient_id, consultation_date DESC);
CREATE INDEX consultations_queue_idx ON public.consultations (queue_id);
CREATE INDEX consultations_author_idx ON public.consultations (created_by);

CREATE TABLE public.prescriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  consultation_id uuid NOT NULL REFERENCES public.consultations(id) ON DELETE RESTRICT,
  medication_name text NOT NULL CHECK (length(btrim(medication_name)) > 0),
  generic_name text,
  dosage text NOT NULL CHECK (length(btrim(dosage)) > 0),
  frequency text NOT NULL CHECK (length(btrim(frequency)) > 0),
  duration text NOT NULL CHECK (length(btrim(duration)) > 0),
  instructions text,
  quantity integer NOT NULL CHECK (quantity > 0),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE INDEX prescriptions_consultation_idx ON public.prescriptions (consultation_id);

CREATE TABLE public.lab_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  consultation_id uuid NOT NULL REFERENCES public.consultations(id) ON DELETE RESTRICT,
  test_name text NOT NULL CHECK (length(btrim(test_name)) > 0),
  test_code text,
  instructions text,
  status text NOT NULL DEFAULT 'pending' CHECK (length(btrim(status)) > 0),
  requested_date timestamptz,
  completed_date timestamptz,
  results text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  CHECK (completed_date IS NULL OR requested_date IS NULL OR completed_date >= requested_date)
);

CREATE INDEX lab_orders_consultation_idx ON public.lab_orders (consultation_id);
CREATE INDEX lab_orders_status_idx ON public.lab_orders (status, requested_date DESC);

CREATE TABLE public.documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id uuid NOT NULL REFERENCES public.patients(id) ON DELETE RESTRICT,
  consultation_id uuid,
  type text NOT NULL CHECK (length(btrim(type)) > 0),
  title text NOT NULL CHECK (length(btrim(title)) > 0),
  description text,
  file_size bigint NOT NULL DEFAULT 0 CHECK (file_size >= 0),
  mime_type text,
  scanned_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  scan_date timestamptz,
  verified_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  verified_date timestamptz,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'verified', 'archived')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  FOREIGN KEY (consultation_id, patient_id)
    REFERENCES public.consultations(id, patient_id) ON DELETE RESTRICT
);

CREATE INDEX documents_patient_date_idx ON public.documents (patient_id, created_at DESC);
CREATE INDEX documents_consultation_idx ON public.documents (consultation_id);

CREATE TABLE public.audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  action text NOT NULL,
  entity_type text NOT NULL,
  entity_id text,
  patient_id uuid REFERENCES public.patients(id) ON DELETE SET NULL,
  old_values jsonb,
  new_values jsonb,
  occurred_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX audit_logs_time_idx ON public.audit_logs (occurred_at DESC);
CREATE INDEX audit_logs_user_time_idx ON public.audit_logs (user_id, occurred_at DESC);
CREATE INDEX audit_logs_patient_time_idx ON public.audit_logs (patient_id, occurred_at DESC);

CREATE TABLE public.sync_tombstones (
  entity_type text NOT NULL CHECK (entity_type IN (
    'patients', 'queue_items', 'consultations', 'prescriptions', 'lab_orders',
    'documents', 'generated_reports'
  )),
  record_id uuid NOT NULL,
  deleted_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  deleted_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (entity_type, record_id)
);

CREATE INDEX sync_tombstones_time_idx ON public.sync_tombstones (deleted_at DESC);

CREATE TABLE public.generated_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL CHECK (length(btrim(title)) > 0),
  type text NOT NULL CHECK (length(btrim(type)) > 0),
  generated_at timestamptz NOT NULL DEFAULT now(),
  start_date timestamptz,
  end_date timestamptz,
  created_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date)
);

CREATE INDEX generated_reports_date_idx ON public.generated_reports (generated_at DESC);

CREATE TABLE public.system_settings (
  key text PRIMARY KEY CHECK (length(btrim(key)) > 0),
  value jsonb NOT NULL,
  updated_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.notifications (
  id text PRIMARY KEY CHECK (length(btrim(id)) > 0),
  type text NOT NULL CHECK (type IN (
    'incompleteRecord', 'syncFailed', 'pendingDocument', 'suspiciousActivity',
    'systemUpdate', 'queueAlert', 'general'
  )),
  target text NOT NULL DEFAULT 'all' CHECK (target IN ('admin', 'staff', 'all')),
  priority text NOT NULL DEFAULT 'normal'
    CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
  title text NOT NULL CHECK (length(btrim(title)) > 0),
  message text NOT NULL CHECK (length(btrim(message)) > 0),
  action_route text,
  is_read boolean NOT NULL DEFAULT false,
  created_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX notifications_target_created_idx ON public.notifications (target, created_at DESC);

CREATE TABLE public.medical_snippets (
  id text PRIMARY KEY CHECK (length(btrim(id)) > 0),
  shortcut text NOT NULL CHECK (length(btrim(shortcut)) > 0),
  title text NOT NULL CHECK (length(btrim(title)) > 0),
  content text NOT NULL CHECK (length(btrim(content)) > 0),
  category text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (shortcut)
);

CREATE INDEX medical_snippets_active_idx ON public.medical_snippets (is_active, shortcut);
CREATE UNIQUE INDEX medical_snippets_shortcut_lower_uidx
  ON public.medical_snippets (lower(shortcut));

CREATE FUNCTION public.medsentry_current_user_id()
RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT u.id FROM public.users AS u
  WHERE u.auth_user_id = (SELECT auth.uid()) AND u.is_active
$$;

CREATE FUNCTION public.medsentry_current_role()
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT u.role FROM public.users AS u
  WHERE u.auth_user_id = (SELECT auth.uid()) AND u.is_active
$$;

REVOKE ALL ON FUNCTION public.medsentry_current_user_id() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.medsentry_current_role() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.medsentry_current_user_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.medsentry_current_role() TO authenticated;

CREATE FUNCTION public.medsentry_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

CREATE FUNCTION public.medsentry_audit_row()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  row_data jsonb;
  old_data jsonb;
  new_data jsonb;
  target_id text;
  target_patient_id uuid;
  operation_action text;
BEGIN
  IF TG_OP <> 'INSERT' THEN old_data := to_jsonb(OLD); END IF;
  IF TG_OP <> 'DELETE' THEN new_data := to_jsonb(NEW); END IF;
  row_data := COALESCE(new_data, old_data);
  target_id := row_data ->> 'id';
  target_patient_id := CASE
    WHEN TG_TABLE_NAME = 'patients' THEN NULLIF(target_id, '')::uuid
    ELSE NULLIF(row_data ->> 'patient_id', '')::uuid
  END;
  IF target_patient_id IS NULL AND row_data ? 'consultation_id' THEN
    SELECT c.patient_id INTO target_patient_id
    FROM public.consultations AS c
    WHERE c.id = NULLIF(row_data ->> 'consultation_id', '')::uuid;
  END IF;

  IF TG_TABLE_NAME = 'users' THEN
    IF TG_OP = 'INSERT' THEN
      operation_action := 'CREATE_USER';
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
      WHEN 'queue_items' THEN 'queue'
      WHEN 'consultations' THEN 'consultation'
      WHEN 'audit_logs' THEN 'audit_log'
      WHEN 'system_settings' THEN 'settings'
      ELSE rtrim(TG_TABLE_NAME, 's')
    END);
  END IF;

  INSERT INTO public.audit_logs
    (user_id, action, entity_type, entity_id, patient_id, old_values, new_values)
  VALUES
    (public.medsentry_current_user_id(), operation_action, TG_TABLE_NAME,
     target_id, target_patient_id, old_data, new_data);
  RETURN NULL;
END;
$$;

CREATE FUNCTION public.medsentry_apply_sync_delete(entity text, target_record_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  actor_id uuid;
BEGIN
  IF public.medsentry_current_role() IS DISTINCT FROM 'admin'
    AND public.medsentry_current_role() IS DISTINCT FROM 'staff' THEN
    RAISE EXCEPTION 'active staff session required' USING ERRCODE = '42501';
  END IF;
  actor_id := public.medsentry_current_user_id();

  CASE entity
    WHEN 'patients' THEN
      UPDATE public.patients
      SET is_archived = true, archived_at = COALESCE(archived_at, now())
      WHERE id = target_record_id;
    WHEN 'queue_items' THEN
      UPDATE public.queue_items SET deleted_at = COALESCE(deleted_at, now())
      WHERE id = target_record_id;
    WHEN 'consultations' THEN
      UPDATE public.consultations SET deleted_at = COALESCE(deleted_at, now())
      WHERE id = target_record_id;
    WHEN 'prescriptions' THEN
      UPDATE public.prescriptions SET deleted_at = COALESCE(deleted_at, now())
      WHERE id = target_record_id;
    WHEN 'lab_orders' THEN
      UPDATE public.lab_orders SET deleted_at = COALESCE(deleted_at, now())
      WHERE id = target_record_id;
    WHEN 'documents' THEN
      UPDATE public.documents SET deleted_at = COALESCE(deleted_at, now())
      WHERE id = target_record_id;
    WHEN 'generated_reports' THEN
      UPDATE public.generated_reports SET deleted_at = COALESCE(deleted_at, now())
      WHERE id = target_record_id;
    ELSE
      RAISE EXCEPTION 'unsupported sync delete type' USING ERRCODE = '22023';
  END CASE;

  INSERT INTO public.sync_tombstones (entity_type, record_id, deleted_by)
  VALUES (entity, target_record_id, actor_id)
  ON CONFLICT (entity_type, record_id) DO NOTHING;
END;
$$;

CREATE FUNCTION public.medsentry_log_auth_event(event_action text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  actor_id uuid;
BEGIN
  actor_id := public.medsentry_current_user_id();
  IF actor_id IS NULL THEN
    RAISE EXCEPTION 'active user session required' USING ERRCODE = '42501';
  END IF;
  IF event_action IS NULL OR event_action NOT IN ('LOGIN', 'LOGOUT', 'CHANGE_PASSWORD') THEN
    RAISE EXCEPTION 'unsupported auth event' USING ERRCODE = '22023';
  END IF;
  INSERT INTO public.audit_logs (user_id, action, entity_type, entity_id)
  VALUES (actor_id, event_action, 'auth', actor_id::text);
  IF event_action = 'LOGIN' THEN
    UPDATE public.users SET last_login_at = now() WHERE id = actor_id;
  END IF;
END;
$$;

CREATE FUNCTION public.medsentry_audit_password_reset(target_user_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  actor_id uuid;
BEGIN
  actor_id := public.medsentry_current_user_id();
  IF actor_id IS NULL OR public.medsentry_current_role() IS DISTINCT FROM 'admin' THEN
    RAISE EXCEPTION 'admin role required' USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = target_user_id) THEN
    RAISE EXCEPTION 'user profile not found' USING ERRCODE = 'P0002';
  END IF;
  INSERT INTO public.audit_logs (user_id, action, entity_type, entity_id)
  VALUES (actor_id, 'RESET_PASSWORD', 'user', target_user_id::text);
END;
$$;

CREATE FUNCTION public.medsentry_create_profile_for_auth_user()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF NEW.email IS NULL THEN RETURN NEW; END IF;
  INSERT INTO public.users (auth_user_id, email, first_name, last_name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NULLIF(NEW.raw_user_meta_data ->> 'first_name', ''), split_part(NEW.email, '@', 1)),
    COALESCE(NULLIF(NEW.raw_user_meta_data ->> 'last_name', ''), ''),
    'staff'
  )
  ON CONFLICT (auth_user_id) DO UPDATE
    SET email = EXCLUDED.email, updated_at = now();
  RETURN NEW;
END;
$$;

CREATE FUNCTION public.medsentry_update_user_account(
  target_user_id uuid,
  requested_role text,
  requested_active boolean,
  requested_first_name text,
  requested_last_name text,
  requested_license_number text,
  requested_specialization text,
  requested_contact_number text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  actor_id uuid;
  actor_role text;
  existing_role text;
  existing_active boolean;
BEGIN
  actor_id := public.medsentry_current_user_id();
  actor_role := public.medsentry_current_role();
  IF actor_id IS NULL OR actor_role IS NULL THEN
    RAISE EXCEPTION 'active user session required' USING ERRCODE = '42501';
  END IF;
  IF requested_role IS NULL OR requested_role NOT IN ('admin', 'staff') THEN
    RAISE EXCEPTION 'invalid role' USING ERRCODE = '22023';
  END IF;
  SELECT role, is_active INTO existing_role, existing_active
  FROM public.users WHERE id = target_user_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'user profile not found' USING ERRCODE = 'P0002'; END IF;
  IF actor_role <> 'admin' THEN
    IF actor_id <> target_user_id THEN
      RAISE EXCEPTION 'admin role required to edit another user' USING ERRCODE = '42501';
    END IF;
    IF requested_role IS DISTINCT FROM existing_role
      OR requested_active IS DISTINCT FROM existing_active THEN
      RAISE EXCEPTION 'admin role required to change account access' USING ERRCODE = '42501';
    END IF;
  END IF;
  IF actor_id = target_user_id AND requested_active = false THEN
    RAISE EXCEPTION 'cannot deactivate the current account' USING ERRCODE = '42501';
  END IF;
  IF existing_role = 'admin' AND existing_active
    AND (requested_role <> 'admin' OR NOT requested_active)
    AND (SELECT count(*) FROM public.users WHERE role = 'admin' AND is_active) <= 1 THEN
    RAISE EXCEPTION 'cannot remove the last active administrator' USING ERRCODE = '42501';
  END IF;
  IF length(btrim(requested_first_name)) = 0 OR length(btrim(requested_last_name)) = 0 THEN
    RAISE EXCEPTION 'first and last name are required' USING ERRCODE = '22023';
  END IF;
  UPDATE public.users
  SET role = requested_role,
      is_active = requested_active,
      first_name = btrim(requested_first_name),
      last_name = btrim(requested_last_name),
      license_number = requested_license_number,
      specialization = requested_specialization,
      contact_number = requested_contact_number
  WHERE id = target_user_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'user profile not found' USING ERRCODE = 'P0002'; END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.medsentry_set_updated_at() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.medsentry_audit_row() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.medsentry_create_profile_for_auth_user() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.medsentry_apply_sync_delete(text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.medsentry_apply_sync_delete(text, uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.medsentry_log_auth_event(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.medsentry_log_auth_event(text) TO authenticated;
REVOKE ALL ON FUNCTION public.medsentry_audit_password_reset(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.medsentry_audit_password_reset(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.medsentry_update_user_account(uuid, text, boolean, text, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.medsentry_update_user_account(uuid, text, boolean, text, text, text, text, text) TO authenticated;

CREATE TRIGGER auth_user_profile_created
  AFTER INSERT OR UPDATE OF email ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.medsentry_create_profile_for_auth_user();

DO $$
DECLARE table_name text;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'users', 'patients', 'queue_items', 'consultations', 'prescriptions',
    'lab_orders', 'documents', 'generated_reports', 'system_settings',
    'notifications', 'medical_snippets'
  ] LOOP
    EXECUTE format(
      'CREATE TRIGGER %I BEFORE UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.medsentry_set_updated_at()',
      table_name || '_set_updated_at', table_name
    );
  END LOOP;

  FOREACH table_name IN ARRAY ARRAY[
    'users', 'patients', 'queue_items', 'consultations', 'prescriptions',
    'lab_orders', 'documents', 'generated_reports', 'system_settings',
    'notifications', 'medical_snippets'
  ] LOOP
    EXECUTE format(
      'CREATE TRIGGER %I AFTER INSERT OR UPDATE OR DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.medsentry_audit_row()',
      table_name || '_audit', table_name
    );
  END LOOP;
END;
$$;

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.queue_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consultations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prescriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lab_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sync_tombstones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.generated_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.medical_snippets ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon, authenticated;
GRANT SELECT ON public.users TO authenticated;
GRANT SELECT, INSERT, UPDATE ON
  public.patients, public.queue_items, public.consultations,
  public.prescriptions, public.lab_orders, public.documents TO authenticated;
GRANT SELECT ON public.audit_logs TO authenticated;
GRANT SELECT ON public.sync_tombstones TO authenticated;
GRANT SELECT, INSERT ON public.generated_reports TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.system_settings TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.notifications TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.medical_snippets TO authenticated;

CREATE POLICY users_read_self_or_admin ON public.users FOR SELECT TO authenticated
  USING (id = public.medsentry_current_user_id()
    OR public.medsentry_current_role() = 'admin');

CREATE POLICY patients_read ON public.patients FOR SELECT TO authenticated
  USING (public.medsentry_current_role() IN ('admin', 'staff'));
CREATE POLICY patients_insert ON public.patients FOR INSERT TO authenticated
  WITH CHECK (public.medsentry_current_role() IN ('admin', 'staff'));
CREATE POLICY patients_update ON public.patients FOR UPDATE TO authenticated
  USING (public.medsentry_current_role() IN ('admin', 'staff'))
  WITH CHECK (public.medsentry_current_role() IN ('admin', 'staff'));

CREATE POLICY queue_read ON public.queue_items FOR SELECT TO authenticated
  USING (deleted_at IS NULL AND public.medsentry_current_role() IN ('admin', 'staff'));
CREATE POLICY queue_insert ON public.queue_items FOR INSERT TO authenticated
  WITH CHECK (public.medsentry_current_role() IN ('admin', 'staff'));
CREATE POLICY queue_update ON public.queue_items FOR UPDATE TO authenticated
  USING (deleted_at IS NULL AND public.medsentry_current_role() IN ('admin', 'staff'))
  WITH CHECK (deleted_at IS NULL AND public.medsentry_current_role() IN ('admin', 'staff'));

CREATE POLICY consultations_read ON public.consultations FOR SELECT TO authenticated
  USING (deleted_at IS NULL AND public.medsentry_current_role() IN ('admin', 'staff'));
CREATE POLICY consultations_insert ON public.consultations FOR INSERT TO authenticated
  WITH CHECK (public.medsentry_current_role() IN ('admin', 'staff'));
CREATE POLICY consultations_update ON public.consultations FOR UPDATE TO authenticated
  USING (deleted_at IS NULL AND public.medsentry_current_role() IN ('admin', 'staff'))
  WITH CHECK (deleted_at IS NULL AND public.medsentry_current_role() IN ('admin', 'staff'));

CREATE POLICY prescriptions_clinical_access ON public.prescriptions FOR ALL TO authenticated
  USING (deleted_at IS NULL AND public.medsentry_current_role() IN ('admin', 'staff'))
  WITH CHECK (deleted_at IS NULL AND public.medsentry_current_role() IN ('admin', 'staff'));
CREATE POLICY lab_orders_clinical_access ON public.lab_orders FOR ALL TO authenticated
  USING (deleted_at IS NULL AND public.medsentry_current_role() IN ('admin', 'staff'))
  WITH CHECK (deleted_at IS NULL AND public.medsentry_current_role() IN ('admin', 'staff'));
CREATE POLICY documents_read ON public.documents FOR SELECT TO authenticated
  USING (deleted_at IS NULL AND public.medsentry_current_role() IN ('admin', 'staff'));
CREATE POLICY documents_insert ON public.documents FOR INSERT TO authenticated
  WITH CHECK (public.medsentry_current_role() IN ('admin', 'staff'));
CREATE POLICY documents_update ON public.documents FOR UPDATE TO authenticated
  USING (deleted_at IS NULL AND public.medsentry_current_role() IN ('admin', 'staff'))
  WITH CHECK (deleted_at IS NULL AND public.medsentry_current_role() IN ('admin', 'staff'));

CREATE POLICY audit_admin_read ON public.audit_logs FOR SELECT TO authenticated
  USING (public.medsentry_current_role() = 'admin');
CREATE POLICY tombstones_clinical_read ON public.sync_tombstones FOR SELECT TO authenticated
  USING (public.medsentry_current_role() IN ('admin', 'staff'));
CREATE POLICY reports_clinical_read ON public.generated_reports FOR SELECT TO authenticated
  USING (deleted_at IS NULL AND public.medsentry_current_role() IN ('admin', 'staff'));
CREATE POLICY reports_insert ON public.generated_reports FOR INSERT TO authenticated
  WITH CHECK (deleted_at IS NULL AND public.medsentry_current_role() IN ('admin', 'staff')
    AND (created_by IS NULL OR created_by = public.medsentry_current_user_id()));
CREATE POLICY settings_admin_access ON public.system_settings FOR ALL TO authenticated
  USING (public.medsentry_current_role() = 'admin')
  WITH CHECK (public.medsentry_current_role() = 'admin');
CREATE POLICY notifications_read ON public.notifications FOR SELECT TO authenticated
  USING (public.medsentry_current_role() = 'admin'
    OR (public.medsentry_current_role() = 'staff' AND target IN ('staff', 'all')));
CREATE POLICY notifications_admin_write ON public.notifications FOR ALL TO authenticated
  USING (public.medsentry_current_role() = 'admin')
  WITH CHECK (public.medsentry_current_role() = 'admin');
CREATE POLICY snippets_read ON public.medical_snippets FOR SELECT TO authenticated
  USING (public.medsentry_current_role() = 'admin'
    OR (is_active AND public.medsentry_current_role() = 'staff'));
CREATE POLICY snippets_admin_write ON public.medical_snippets FOR ALL TO authenticated
  USING (public.medsentry_current_role() = 'admin')
  WITH CHECK (public.medsentry_current_role() = 'admin');

COMMENT ON TABLE public.documents IS
  'Metadata only. Document bytes remain in the app encrypted local store; private Supabase Storage sync is not implemented.';
COMMENT ON TABLE public.audit_logs IS
  'Database-generated security and clinical change history. Client roles cannot insert, update, or delete audit rows.';