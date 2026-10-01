-- =============================================================================
-- DO NOT RUN THIS FILE IN SUPABASE / POSTGRESQL
-- SQLite-only syntax (PRAGMA, integer booleans, etc.).
-- Supabase uses the fresh migration in supabase/migrations; see docs/DATABASE_SETUP.md.
-- =============================================================================
-- MedSentry local SQLite schema (multi-RHU architecture).
-- =============================================================================

PRAGMA foreign_keys = ON;

-- CLINICS
CREATE TABLE IF NOT EXISTS clinics (
    id              TEXT NOT NULL PRIMARY KEY,
    name            TEXT NOT NULL,
    code            TEXT NOT NULL UNIQUE,
    address         TEXT,
    contact_number  TEXT,
    email           TEXT,
    status          TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
    created_at      TEXT NOT NULL,
    updated_at      TEXT NOT NULL
);

-- USERS
CREATE TABLE IF NOT EXISTS users (
    id              TEXT NOT NULL PRIMARY KEY,
    clinic_id       TEXT REFERENCES clinics(id),
    email           TEXT NOT NULL UNIQUE,
    first_name      TEXT NOT NULL,
    last_name       TEXT NOT NULL,
    role            TEXT NOT NULL CHECK (role IN ('super_admin', 'admin', 'staff')),
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
    clinic_id                   TEXT NOT NULL REFERENCES clinics(id),
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
    is_archived                 INTEGER NOT NULL DEFAULT 0,
    archived_at                 TEXT,
    created_at                  TEXT,
    updated_at                  TEXT,
    last_visit_date             TEXT,
    sync_status                 INTEGER,
    sync_error                  TEXT
);

-- QUEUE ITEMS
CREATE TABLE IF NOT EXISTS queue_items (
    id                  TEXT NOT NULL PRIMARY KEY,
    clinic_id           TEXT NOT NULL REFERENCES clinics(id),
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
    updated_at          TEXT NOT NULL,
    deleted_at          TEXT
);

-- CONSULTATIONS
CREATE TABLE IF NOT EXISTS consultations (
    id          TEXT NOT NULL PRIMARY KEY,
    clinic_id   TEXT NOT NULL REFERENCES clinics(id),
    patient_id  TEXT NOT NULL REFERENCES patients(id),
    queue_id    TEXT REFERENCES queue_items(id),
    subjective  TEXT,
    objective   TEXT,
    assessment  TEXT,
    plan        TEXT,
    icd10_code  TEXT,
    created_by  TEXT NOT NULL REFERENCES users(id),
    created_at  TEXT NOT NULL,
    updated_at  TEXT NOT NULL,
    deleted_at  TEXT
);

-- PRESCRIPTIONS
CREATE TABLE IF NOT EXISTS prescriptions (
    id                  TEXT NOT NULL PRIMARY KEY,
    clinic_id           TEXT NOT NULL REFERENCES clinics(id),
    consultation_id     TEXT NOT NULL REFERENCES consultations(id),
    medication_name     TEXT NOT NULL,
    generic_name        TEXT,
    dosage              TEXT NOT NULL,
    frequency           TEXT NOT NULL,
    duration            TEXT NOT NULL,
    instructions        TEXT,
    quantity            INTEGER NOT NULL,
    notes               TEXT,
    created_at          TEXT NOT NULL,
    updated_at          TEXT NOT NULL,
    deleted_at          TEXT
);

-- LAB ORDERS
CREATE TABLE IF NOT EXISTS lab_orders (
    id                  TEXT NOT NULL PRIMARY KEY,
    clinic_id           TEXT NOT NULL REFERENCES clinics(id),
    consultation_id     TEXT NOT NULL REFERENCES consultations(id),
    test_name           TEXT NOT NULL,
    test_code           TEXT,
    instructions        TEXT,
    status              TEXT NOT NULL DEFAULT 'pending',
    requested_date      TEXT,
    completed_date      TEXT,
    results             TEXT,
    notes               TEXT,
    created_at          TEXT NOT NULL,
    updated_at          TEXT NOT NULL,
    deleted_at          TEXT
);

-- DOCUMENTS
CREATE TABLE IF NOT EXISTS documents (
    id          TEXT NOT NULL PRIMARY KEY,
    clinic_id   TEXT NOT NULL REFERENCES clinics(id),
    patient_id  TEXT NOT NULL REFERENCES patients(id),
    consultation_id TEXT REFERENCES consultations(id),
    title       TEXT NOT NULL,
    description TEXT,
    type        TEXT NOT NULL,
    file_type   TEXT,
    file_path   TEXT,
    file_url    TEXT,
    uploaded_by TEXT NOT NULL REFERENCES users(id),
    status      TEXT NOT NULL DEFAULT 'pending',
    created_at  TEXT NOT NULL,
    updated_at  TEXT NOT NULL,
    deleted_at  TEXT
);

-- AUDIT LOGS
CREATE TABLE IF NOT EXISTS audit_logs (
    id          INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    clinic_id   TEXT REFERENCES clinics(id),
    user_id     TEXT NOT NULL REFERENCES users(id),
    action      TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id   TEXT,
    patient_id  TEXT REFERENCES patients(id),
    description TEXT,
    old_values  TEXT,
    new_values  TEXT,
    timestamp   TEXT NOT NULL
);

-- SETTINGS
CREATE TABLE IF NOT EXISTS settings (
    clinic_id   TEXT REFERENCES clinics(id),
    key         TEXT NOT NULL,
    value       TEXT NOT NULL,
    updated_at  TEXT NOT NULL,
    PRIMARY KEY (clinic_id, key)
);

-- SYNC QUEUE
CREATE TABLE IF NOT EXISTS sync_queue_items (
    id           INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    clinic_id    TEXT NOT NULL REFERENCES clinics(id),
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
    clinic_id   TEXT REFERENCES clinics(id),
    shortcut    TEXT NOT NULL,
    title       TEXT NOT NULL,
    content     TEXT NOT NULL,
    category    TEXT,
    is_active   INTEGER NOT NULL DEFAULT 1,
    created_at  TEXT NOT NULL,
    updated_at  TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_patients_clinic_name ON patients (clinic_id, last_name, first_name);
CREATE INDEX IF NOT EXISTS idx_queue_clinic_status ON queue_items (clinic_id, status);
CREATE INDEX IF NOT EXISTS idx_consultations_clinic_patient ON consultations (clinic_id, patient_id);
CREATE INDEX IF NOT EXISTS idx_audit_clinic_timestamp ON audit_logs (clinic_id, timestamp);
