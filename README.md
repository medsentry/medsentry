# medsentry

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:


For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
## Database

The Supabase schema is managed by `supabase/migrations`. Apply migrations in order when setting up a new project. Existing projects must apply `20261016000000_document_cloud_storage.sql` to enable private, clinic-scoped document file sync.

The migration creates a private `medsentry-medical-documents` Storage bucket and its tenant-scoped access policies. Cloud files are transferred over HTTPS and use Supabase-managed encryption at rest; local copies remain encrypted on each device. Authorized users in a clinic can access that clinic's cloud files.

`supabase_setup.sql` recreates the schema and is only for a fresh/test project; do not run it against a production database. Do not run legacy SQL seed scripts or add synthetic patient records to production.
