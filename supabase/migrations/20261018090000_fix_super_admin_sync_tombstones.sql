-- Migration: Fix Super Admin Sync Tombstones and Allow Outbound Audit Logs
-- Date: 2026-10-18

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
      UPDATE public.patients
      SET is_archived = true, archived_at = COALESCE(archived_at, now())
      WHERE id = target_record_id
        AND (is_super OR clinic_id = actor_clinic_id)
      RETURNING clinic_id INTO resolved_clinic_id;
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

  resolved_clinic_id := COALESCE(resolved_clinic_id, actor_clinic_id);

  IF resolved_clinic_id IS NOT NULL THEN
    INSERT INTO public.sync_tombstones (clinic_id, entity_type, record_id, deleted_by)
    VALUES (resolved_clinic_id, entity, target_record_id, actor_id)
    ON CONFLICT (clinic_id, entity_type, record_id) DO NOTHING;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.medsentry_apply_sync_delete(text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.medsentry_apply_sync_delete(text, uuid) TO authenticated;

-- Allow authenticated users to sync outbound audit logs
GRANT INSERT ON public.audit_logs TO authenticated;

DROP POLICY IF EXISTS audit_logs_insert ON public.audit_logs;
CREATE POLICY audit_logs_insert ON public.audit_logs FOR INSERT TO authenticated
  WITH CHECK (
    public.medsentry_is_super_admin() OR
    (public.medsentry_current_role() IN ('admin', 'staff') AND (clinic_id IS NULL OR clinic_id = public.medsentry_current_clinic_id()))
  );

