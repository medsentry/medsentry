# MedSentry

Offline-first Rural Health Unit (RHU) records and document management system,
built with Flutter and Supabase.

## Run the web app (PWA)

```sh
flutter build web --release --base-href /
npx serve build/web -s -p 8080
```

## Accounts

Accounts are created by an administrator (Settings > Staff). Never commit
passwords, keys, or exported data: this repository is public.

Debug builds create local development accounts using the password passed with
`--dart-define=MEDSENTRY_SEED_PASSWORD=...`. Release builds never create them.

## Database

The Supabase schema is managed by `supabase/migrations`. Apply migrations in order when setting up a new project. Existing projects must apply `20261016000000_document_cloud_storage.sql` to enable private, clinic-scoped document file sync.

The migration creates a private `medsentry-medical-documents` Storage bucket and its tenant-scoped access policies. Cloud files are transferred over HTTPS and use Supabase-managed encryption at rest; local copies remain encrypted on each device. Authorized users in a clinic can access that clinic's cloud files.

On a fresh project the initial migration creates one locked Super Admin
(`superadmin@medsentry.invalid`, random password). Set its real email and
password from the Supabase Dashboard (Authentication > Users) before use.

Do not run legacy SQL seed scripts or add synthetic patient records to production.

## Secrets

- The Supabase publishable key in `lib/src/config/supabase_config.dart` is meant
  to be public; data is protected by row-level security.
- The service-role key lives only in Supabase Edge Function secrets
  (`SUPABASE_SERVICE_ROLE_KEY`). Never put it in the app or this repository.
- SMTP credentials are set in the Supabase Dashboard, not in `config.toml`.
