-- Migration: Fix Archive & Recovery permanent deletion for patients
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
      SELECT clinic_id INTO resolved_clinic_id
      FROM public.patients
      WHERE id = target_record_id
        AND (is_super OR clinic_id = actor_clinic_id);

      IF resolved_clinic_id IS NOT NULL THEN
        -- Delete dependent rows to avoid RESTRICT foreign key constraint failures
        DELETE FROM public.documents WHERE patient_id = target_record_id;
        DELETE FROM public.issued_certificates WHERE patient_id = target_record_id;
        DELETE FROM public.queue_items WHERE patient_id = target_record_id;
        
        -- Permanent deletion of patient record
        DELETE FROM public.patients
        WHERE id = target_record_id
          AND (is_super OR clinic_id = actor_clinic_id);
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

