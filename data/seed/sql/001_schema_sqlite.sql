-- =============================================================================
-- DO NOT RUN THIS FILE IN SUPABASE / POSTGRESQL
-- SQLite-only syntax (PRAGMA, integer booleans, etc.).
-- Supabase uses the fresh migration in supabase/migrations; see docs/DATABASE_SETUP.md.
-- =============================================================================
-- MedSentry local SQLite schema (legacy/manual tooling only).
-- =============================================================================

PRAGMA foreign_keys = ON;

-- USERS
CREATE TABLE IF NOT EXISTS users (
    id              TEXT NOT NULL PRIMARY KEY,
    email           TEXT NOT NULL UNIQUE,
    first_name      TEXT NOT NULL,
    last_name       TEXT NOT NULL,
    role            TEXT NOT NULL CHECK (role IN ('admin', 'staff')),
    license_number  TEXT,
    specialization  TEXT,
    contact_number  TEXT,
    is_active       INTEGER NOT NULL DEFAULT 1,
    pin_enabled     INTEGER NOT NULL DEFAULT 0,
    pin_hash        TEXT,
    password_hash   TEXT NOT NULL,
    created_at      TEXT NOT NULL,
    updated_at      TEXT NOT NULL
);

-- PATIENTS
CREATE TABLE IF NOT EXISTS patients (
    id                          TEXT NOT NULL PRIMARY KEY,
    first_name                  TEXT NOT NULL,
    last_name                   TEXT NOT NULL,
    middle_name                 TEXT,
    suffix                      TEXT,
    date_of_birth               TEXT,
    gender                      TEXT,
    civil_status                TEXT,
    religion                    TEXT,
    contact_number              TEXT,
    email                       TEXT,
    address                     TEXT,
    barangay                    TEXT,
    purok_sitio                 TEXT,
    city                        TEXT,
    province                    TEXT,
    zip_code                    TEXT,
    philhealth_number           TEXT,
    philhealth_category         TEXT,
    local_lgu_id_number         TEXT,
    blood_type                  TEXT,
    emergency_contact_name      TEXT,
    emergency_contact_number    TEXT,
    emergency_contact_relation  TEXT,
    occupation                  TEXT,
    employer                    TEXT,
    is_pwd                      INTEGER NOT NULL DEFAULT 0,
    is_solo_parent              INTEGER NOT NULL DEFAULT 0,
    is_indigenous_person        INTEGER NOT NULL DEFAULT 0,
    tribe_ethnolinguistic_group TEXT,
    is_4ps_beneficiary          INTEGER NOT NULL DEFAULT 0,
    household_id_number         TEXT,
    water_source                TEXT,
    toilet_facility             TEXT,
    height                      REAL,
    weight                      REAL,
    allergies                   TEXT,
    medical_history             TEXT,
    category                    TEXT,
    created_at                  TEXT,
    updated_at                  TEXT,
    last_visit_date             TEXT,
    sync_status                 INTEGER,
    sync_error                  TEXT
);

-- QUEUE ITEMS
CREATE TABLE IF NOT EXISTS queue_items (
    id                  TEXT NOT NULL PRIMARY KEY,
    patient_id          TEXT NOT NULL REFERENCES patients(id),
    status              TEXT NOT NULL,
    priority            TEXT NOT NULL DEFAULT 'normal',
    nurse_id            TEXT REFERENCES users(id),
    room_number         TEXT,
    category            TEXT,
    vitals_bp           TEXT,
    vitals_weight       REAL,
    vitals_temperature  REAL,
    vitals_notes        TEXT,
    arrival_time        TEXT NOT NULL,
    start_time          TEXT,
    end_time            TEXT,
    created_at          TEXT NOT NULL,
    updated_at          TEXT NOT NULL
);

-- CONSULTATIONS
CREATE TABLE IF NOT EXISTS consultations (
    id          TEXT NOT NULL PRIMARY KEY,
    patient_id  TEXT NOT NULL REFERENCES patients(id),
    queue_id    TEXT REFERENCES queue_items(id),
    subjective  TEXT,
    objective   TEXT,
    assessment  TEXT,
    plan        TEXT,
    icd10_code  TEXT,
    created_by  TEXT NOT NULL REFERENCES users(id),
    created_at  TEXT NOT NULL,
    updated_at  TEXT NOT NULL
);

-- DOCUMENTS
CREATE TABLE IF NOT EXISTS documents (
    id          TEXT NOT NULL PRIMARY KEY,
    patient_id  TEXT NOT NULL REFERENCES patients(id),
    title       TEXT NOT NULL,
    description TEXT,
    type        TEXT NOT NULL,
    file_type   TEXT,
    file_path   TEXT,
    file_url    TEXT,
    uploaded_by TEXT NOT NULL REFERENCES users(id),
    status      TEXT NOT NULL DEFAULT 'pending',
    created_at  TEXT NOT NULL,
    updated_at  TEXT NOT NULL
);

-- AUDIT LOGS
CREATE TABLE IF NOT EXISTS audit_logs (
    id          INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    user_id     TEXT NOT NULL REFERENCES users(id),
    action      TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id   TEXT,
    description TEXT,
    old_values  TEXT,
    new_values  TEXT,
    timestamp   TEXT NOT NULL
);

-- SETTINGS
CREATE TABLE IF NOT EXISTS settings (
    key         TEXT NOT NULL PRIMARY KEY,
    value       TEXT NOT NULL,
    updated_at  TEXT NOT NULL
);

-- SYNC QUEUE
CREATE TABLE IF NOT EXISTS sync_queue_items (
    id           INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    entity_table TEXT NOT NULL,
    record_id    TEXT NOT NULL,
    operation    TEXT NOT NULL,
    data         TEXT NOT NULL,
    created_at   TEXT NOT NULL,
    is_synced    INTEGER NOT NULL DEFAULT 0,
    synced_at    TEXT,
    error        TEXT
);

-- MEDICAL SNIPPETS
CREATE TABLE IF NOT EXISTS medical_snippets (
    id          TEXT NOT NULL PRIMARY KEY,
    shortcut    TEXT NOT NULL,
    title       TEXT NOT NULL,
    content     TEXT NOT NULL,
    category    TEXT,
    is_active   INTEGER NOT NULL DEFAULT 1,
    created_at  TEXT NOT NULL,
    updated_at  TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_patients_name ON patients (last_name, first_name);
CREATE INDEX IF NOT EXISTS idx_queue_status ON queue_items (status);
CREATE INDEX IF NOT EXISTS idx_consultations_patient ON consultations (patient_id);
CREATE INDEX IF NOT EXISTS idx_audit_timestamp ON audit_logs (timestamp);
