-- Publish RLS-filtered changes for authenticated MedSentry clients.
DO $$
DECLARE
  table_name text;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'users',
    'patients',
    'queue_items',
    'consultations',
    'prescriptions',
    'lab_orders',
    'documents',
    'audit_logs',
    'generated_reports',
    'system_settings',
    'notifications',
    'medical_snippets',
    'sync_tombstones'
  ] LOOP
    BEGIN
      EXECUTE format(
        'ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',
        table_name
      );
    EXCEPTION
      WHEN duplicate_object THEN NULL;
    END;
  END LOOP;
END;
$$;-- Enable RLS-filtered change events for tables consumed by offline clients.
DO $$
DECLARE
  table_name text;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'users',
    'patients',
    'queue_items',
    'consultations',
    'prescriptions',
    'lab_orders',
    'documents',
    'audit_logs',
    'generated_reports',
    'system_settings',
    'notifications',
    'medical_snippets',
    'sync_tombstones'
  ] LOOP
    BEGIN
      EXECUTE format(
        'ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',
        table_name
      );
    EXCEPTION
      WHEN duplicate_object THEN NULL;
    END;
  END LOOP;
END;
$$;