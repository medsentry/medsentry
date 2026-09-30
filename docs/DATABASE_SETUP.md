# Database Setup

## Fresh Local Supabase

Prerequisites: Supabase CLI and Docker Desktop.

```powershell
supabase start
supabase db reset
```

`db reset` creates an empty local database and applies `supabase/migrations`. It does not add patients or clinical demo records.

For a hosted Supabase project, link the project and apply the same migrations:

```powershell
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
```

Never use a service-role key in the Flutter application. The client should use only the project URL and publishable/anon key.

The Flutter client accepts target-specific compile-time configuration. Use the URL and anon/publishable key printed by `supabase start` for local development, and the corresponding project values for production:

```powershell
flutter run --dart-define=MEDSENTRY_SUPABASE_URL=YOUR_SUPABASE_URL --dart-define=MEDSENTRY_SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_KEY
```

## First Administrator

Create the first identity using a trusted Supabase Auth administrator workflow. The auth trigger creates its application profile with the safe `staff` role. Promote exactly one profile to the initial administrator from the Supabase SQL editor, using the email for the identity just created:

```sql
UPDATE public.users
SET role = 'admin'
WHERE auth_user_id = (
  SELECT id FROM auth.users WHERE lower(email) = lower('admin@example.org')
)
AND NOT EXISTS (SELECT 1 FROM public.users WHERE role = 'admin');
```

User creation and password resets go through the `provision-user` Edge Function, which checks the caller's active admin profile and calls Supabase Auth Admin using a server-only secret. Deploy it with `supabase functions deploy provision-user`; Supabase provides `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` to the hosted function environment. Profile, role, and status edits use the database-authorized `medsentry_update_user_account` RPC and are audited.

## Current Integration Boundaries

- Supabase Auth owns cloud passwords. `public.users` stores the profile and role, linked by `auth_user_id`; deleting an Auth identity preserves its profile and clinical ownership references.
- Offline sign-in still uses the app's separate local credential cache. It is not uploaded to Supabase.
- New cloud users are created through the secured `provision-user` Edge Function; the server-side function requires the Supabase service-role secret, which must never be configured in Flutter.
- Patient, queue, consultation, document metadata, prescription, and lab-order sync uses UUIDs, timestamp-aware pulls, and durable local deletion tombstones. Last-write-wins is still the conflict policy, not a user-mediated merge.
- Admin settings and generated-report metadata sync; report files stay local. App-generated notifications and their read state are not synchronized yet.
- Document bytes remain in the app's encrypted local store. Only document metadata is synchronized; local file paths are deliberately excluded. Private cloud object storage and signed, authorized downloads are not implemented.
- Reports are generated from source data and local files; there is no persistent cloud report table.
- There is no deployment database or Supabase CLI available in this workspace, so hosted migration execution and live RLS/auth verification remain deployment checks.
