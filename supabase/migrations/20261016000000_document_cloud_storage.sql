BEGIN;

ALTER TABLE public.documents
  ADD COLUMN IF NOT EXISTS storage_path text;

INSERT INTO storage.buckets
  (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  (
    'medsentry-medical-documents',
    'medsentry-medical-documents',
    false,
    10485760,
    ARRAY['application/pdf', 'image/jpeg', 'image/png']
  )
ON CONFLICT (id) DO UPDATE
SET public = false,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS medical_documents_select ON storage.objects;
DROP POLICY IF EXISTS medical_documents_insert ON storage.objects;
DROP POLICY IF EXISTS medical_documents_update ON storage.objects;
DROP POLICY IF EXISTS medical_documents_delete ON storage.objects;

CREATE POLICY medical_documents_select ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'medsentry-medical-documents' AND EXISTS (
      SELECT 1
      FROM public.documents AS d
      WHERE d.id::text = storage.filename(name)
        AND d.clinic_id::text = (storage.foldername(name))[1]
        AND (
          public.medsentry_is_super_admin() OR
          d.clinic_id = public.medsentry_current_clinic_id()
        )
    )
  );

CREATE POLICY medical_documents_insert ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'medsentry-medical-documents' AND EXISTS (
      SELECT 1
      FROM public.documents AS d
      WHERE d.id::text = storage.filename(name)
        AND d.clinic_id::text = (storage.foldername(name))[1]
        AND (
          public.medsentry_is_super_admin() OR
          d.clinic_id = public.medsentry_current_clinic_id()
        )
    )
  );

CREATE POLICY medical_documents_update ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'medsentry-medical-documents' AND EXISTS (
      SELECT 1
      FROM public.documents AS d
      WHERE d.id::text = storage.filename(name)
        AND d.clinic_id::text = (storage.foldername(name))[1]
        AND (
          public.medsentry_is_super_admin() OR
          d.clinic_id = public.medsentry_current_clinic_id()
        )
    )
  )
  WITH CHECK (
    bucket_id = 'medsentry-medical-documents' AND EXISTS (
      SELECT 1
      FROM public.documents AS d
      WHERE d.id::text = storage.filename(name)
        AND d.clinic_id::text = (storage.foldername(name))[1]
        AND (
          public.medsentry_is_super_admin() OR
          d.clinic_id = public.medsentry_current_clinic_id()
        )
    )
  );

CREATE POLICY medical_documents_delete ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'medsentry-medical-documents' AND EXISTS (
      SELECT 1
      FROM public.documents AS d
      WHERE d.id::text = storage.filename(name)
        AND d.clinic_id::text = (storage.foldername(name))[1]
        AND (
          public.medsentry_is_super_admin() OR
          d.clinic_id = public.medsentry_current_clinic_id()
        )
    )
  );

COMMIT;
