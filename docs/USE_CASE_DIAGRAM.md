# MedSentry use-case diagram

The editable source for the complete diagram is [use_case_diagram.puml](use_case_diagram.puml). Open it with a PlantUML-compatible viewer in VS Code to render it.

The diagram reflects the currently implemented app behavior. It deliberately excludes roadmap-only features such as pharmacy inventory, immunization, prenatal care, and FHSIS PDF/Excel export.

Implemented roles:

- **Clinic Administrator** — system administration, staff accounts, audit/compliance, archive recovery, backup and restore.
- **Health Staff** — patient registration, queue/triage, consultations, documents, certificates, reports, and sync.

Both roles share authentication, dashboard, patient/EMR viewing, document viewing, report viewing, and synchronization-status access. The diagram also shows the external biometric provider, Supabase cloud service, and local file system/printer integrations.
