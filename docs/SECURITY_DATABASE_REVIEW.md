# MedSentry Security and Database Review

## Scope

This is a source-level review of the checked-out application and SQL scripts. No live Supabase database, production data, project dashboard, or backup was available. Table contents, duplicate/orphan counts, deployed policies, function ownership, provider settings, and actual role behavior therefore remain unverified. The PostgreSQL changes below must be tested in a non-production Supabase project before deployment.

## Architecture Found

- Flutter/Riverpod client with a `SimpleDatabase` JSON store. Desktop writes `local_store.json`; web writes the store to browser preferences/local storage. Backups copy/export that JSON.
- Supabase Auth is used for online sign-in. The checked-in `anon` publishable key is client-visible by design and is not a service-role credential.
- Cloud sync pushes and pulls patients, queue items, consultations, prescriptions, lab orders, and document metadata. Durable tombstones propagate patient archives and clinical soft-deletes. Conflicts use updated timestamps and preserve pending local edits.
- The fresh PostgreSQL migration defines: `users`, `patients`, `queue_items`, `consultations`, `prescriptions`, `lab_orders`, `documents`, `audit_logs`, `sync_tombstones`, `generated_reports`, `system_settings`, `notifications`, and `medical_snippets`.
- Clinical foreign keys use RESTRICT or SET NULL to preserve history. Patient removal archives; other supported deletions use audited soft-delete timestamps and a protected tombstone feed.
- All user roles are constrained to `admin` and `staff`; Supabase Auth identities link to separate application profiles. The deployment remains single-clinic; there is no clinic/organization isolation key.

## Changes Made

- Added a reproducible Supabase initial migration with RLS, least-privilege grants, auth-linked profiles, two-role constraints, audit triggers, admin RPCs, and soft-delete tombstones.
- Added a server-side Edge Function for staff provisioning/password reset. Flutter only uses the publishable key; Supabase Auth owns provider passwords. Cloud passwords are not written to the local cache.
- Added durable local deletion outbox state, cloud tombstone propagation, and timestamp-aware pulls for implemented clinical entities.
- Removed obsolete PostgreSQL seed/setup scripts containing development data and documented fresh empty-database setup.

## Remaining Risks and Required Work

- Patient and clinical metadata in the JSON/browser store and backups are not encrypted at rest. Document bytes are encrypted locally, but browser storage remains exposed to same-origin script compromise.
- Offline password authentication remains for legacy local accounts only. Newly provisioned cloud users do not have a local password hash; offline access requires a previously configured local PIN.
- RLS is single-clinic only. Since rows lack a clinic/organization ownership key, this migration cannot isolate multiple clinics or organizations. Do not use it for a multi-tenant deployment.
- Sync still uses last-write-wins timestamps and is not atomic across multi-record workflows. Validate conflict behavior across concurrent devices before production.
- Local audit entries such as offline login/logout are not uploaded. Cloud clinical changes are audited in PostgreSQL; retention, export, and backup controls need an operational policy.
- Document metadata sync is implemented, but encrypted file bytes are not uploaded to private Supabase Storage. Cross-device document retrieval is not complete.
- Local system-alert generation and read state remain device-local; the cloud `notifications` table is prepared for admin-authored announcements but the current client does not synchronize it.
- SQL has not been executed against PostgreSQL in this workspace. Apply to a disposable project, then verify RLS as anonymous, staff, admin, inactive, and unprovisioned identities before production.
- Rotate any real provider account credential that was previously present in the run notes. Removing it from the current file does not remove it from Git history or revoke it at the provider.

## Verification

- Focused Flutter tests passed after the account and sync changes. Static Dart diagnostics report no errors in the touched files.
- The migration passed local static invariant checks; PostgreSQL execution and live RLS tests are still pending because no local PostgreSQL/Supabase CLI was available.