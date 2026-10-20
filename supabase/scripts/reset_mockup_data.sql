-- Removes all mockup data before the real launch. NOT a migration: run it by
-- hand, once, when testing is finished.
--
-- Keeps: RHU facilities, system settings and Super Admin accounts.
-- Removes: patients, documents, generated reports, notifications, audit logs,
--          sync tombstones, PIN credentials, and every admin/staff account
--          together with its sign-in (auth) account.
--
-- 1. Empty the document file bucket first (SQL cannot delete storage files):
--      npx supabase storage rm -r --linked ss:///medsentry-medical-documents
-- 2. Dry run (default): reports what would be removed and changes nothing:
--      npx supabase db query --linked -f supabase/scripts/reset_mockup_data.sql
-- 3. To really delete, uncomment the next line and run the same command.
-- SET medsentry.confirm_reset = 'yes';
--
-- Every device should then sign out (or clear site data on the web) so old
-- local copies are not uploaded again.

DO $$
DECLARE
  confirmed boolean :=
    coalesce(current_setting('medsentry.confirm_reset', true), '') = 'yes';
  summary text;
BEGIN
  SELECT format(
    '%s patients, %s documents, %s reports, %s notifications, %s audit log entries, %s admin/staff accounts',
    (SELECT count(*) FROM public.patients),
    (SELECT count(*) FROM public.documents),
    (SELECT count(*) FROM public.generated_reports),
    (SELECT count(*) FROM public.notifications),
    (SELECT count(*) FROM public.audit_logs),
    (SELECT count(*) FROM public.users WHERE role <> 'super_admin')
  ) INTO summary;

  IF NOT confirmed THEN
    RAISE NOTICE 'DRY RUN, nothing deleted. Would remove: %', summary;
    RETURN;
  END IF;

  DELETE FROM public.documents;
  DELETE FROM public.patients;
  DELETE FROM public.generated_reports;
  DELETE FROM public.notifications;
  DELETE FROM public.sync_tombstones;

  -- Sign-in accounts first; their profiles are removed right after.
  DELETE FROM auth.users
  WHERE id IN (
    SELECT auth_user_id FROM public.users
    WHERE role <> 'super_admin' AND auth_user_id IS NOT NULL
  );
  DELETE FROM public.users WHERE role <> 'super_admin';

  -- Last, so the audit rows written by the deletions above go too.
  DELETE FROM public.audit_logs;

  RAISE NOTICE 'Removed: %', summary;
END;
$$;
