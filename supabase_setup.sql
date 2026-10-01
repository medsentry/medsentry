-- =============================================================================
-- MedSentry — Fresh Multi-RHU Database and Secure Platform Architecture
-- Strict Tenant Isolation, Role-Based Access Control, and Clean Database Setup
-- No dummy clinical records (patients, queue, consultations, etc.)
-- Single Super Administrator Provisioned:
--   Email: superadmin@gmail.com
--   Password: Password123!
--   Role: super_admin
--   Scope: All RHUs (clinic_id = NULL)
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- Clean existing objects
DROP TRIGGER IF EXISTS auth_user_profile_created ON auth.users CASCADE;
DROP TABLE IF EXISTS public.documents CASCADE;
DROP TABLE IF EXISTS public.lab_orders CASCADE;
DROP TABLE IF EXISTS public.prescriptions CASCADE;
DROP TABLE IF EXISTS public.consultations CASCADE;
DROP TABLE IF EXISTS public.queue_items CASCADE;
DROP TABLE IF EXISTS public.patients CASCADE;
DROP TABLE IF EXISTS public.audit_logs CASCADE;
DROP TABLE IF EXISTS public.sync_tombstones CASCADE;
DROP TABLE IF EXISTS public.generated_reports CASCADE;
DROP TABLE IF EXISTS public.system_settings CASCADE;
DROP TABLE IF EXISTS public.notifications CASCADE;
DROP TABLE IF EXISTS public.medical_snippets CASCADE;
DROP TABLE IF EXISTS public.users CASCADE;
DROP TABLE IF EXISTS public.clinics CASCADE;

DROP FUNCTION IF EXISTS public.medsentry_current_user_id() CASCADE;
DROP FUNCTION IF EXISTS public.medsentry_current_role() CASCADE;
DROP FUNCTION IF EXISTS public.medsentry_current_clinic_id() CASCADE;
DROP FUNCTION IF EXISTS public.medsentry_is_super_admin() CASCADE;
DROP FUNCTION IF EXISTS public.medsentry_set_updated_at() CASCADE;
DROP FUNCTION IF EXISTS public.medsentry_audit_row() CASCADE;
DROP FUNCTION IF EXISTS public.medsentry_apply_sync_delete(text, uuid) CASCADE;
DROP FUNCTION IF EXISTS public.medsentry_log_auth_event(text) CASCADE;
DROP FUNCTION IF EXISTS public.medsentry_audit_password_reset(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.medsentry_create_profile_for_auth_user() CASCADE;
DROP FUNCTION IF EXISTS public.medsentry_update_user_account(uuid, text, boolean, text, text, text, text, text) CASCADE;

-- -----------------------------------------------------------------------------
-- 1. CLINICS (TENANTS)
-- -----------------------------------------------------------------------------
CREATE TABLE public.clinics (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  code text NOT NULL UNIQUE,
  address text,
  contact_number text,
  email text,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT clinics_name_not_blank CHECK (length(btrim(name)) > 0),
  CONSTRAINT clinics_code_not_blank CHECK (length(btrim(code)) > 0)
);

CREATE INDEX clinics_status_idx ON public.clinics (status);

-- -----------------------------------------------------------------------------
-- 2. USERS (SUPER_ADMIN, ADMIN, STAFF)
-- -----------------------------------------------------------------------------
CREATE TABLE public.users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id uuid REFERENCES public.clinics(id) ON DELETE RESTRICT,
  auth_user_id uuid UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL,
  email text NOT NULL,
  first_name text NOT NULL,
  last_name text NOT NULL,
  role text NOT NULL DEFAULT 'staff' CHECK (role IN ('super_admin', 'admin', 'staff')),
  license_number text,
  specialization text,
  contact_number text,
  profile_image_url text,
  is_active boolean NOT NULL DEFAULT true,
  pin_enabled boolean NOT NULL DEFAULT false,
  last_login_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT users_email_not_blank CHECK (length(btrim(email)) > 0),
  CONSTRAINT users_role_clinic_check CHECK (
    (role = 'super_admin' AND clinic_id IS NULL) OR
    (role IN ('admin', 'staff') AND clinic_id IS NOT NULL)
  )
);

CREATE UNIQUE INDEX users_email_lower_uidx ON public.users (lower(email));
CREATE INDEX users_clinic_role_active_idx ON public.users (clinic_id, role, is_active);

-- -----------------------------------------------------------------------------
-- 3. PATIENTS (TENANT ISOLATED)
-- -----------------------------------------------------------------------------
CREATE TABLE public.patients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id uuid NOT NULL REFERENCES public.clinics(id) ON DELETE RESTRICT,
  first_name text NOT NULL,
  last_name text NOT NULL,
  middle_name text,
  suffix text,
  date_of_birth timestamptz,
  gender text,
  civil_status text,
  religion text,
  contact_number text,
  email text,
  address text,
  barangay text,
  purok_sitio text,
  city text,
  province text,
  zip_code text,
  philhealth_number text,
  philhealth_category text,
  local_lgu_id text,
  blood_type text,
  emergency_contact_name text,
  emergency_contact_number text,
  emergency_contact_relation text,
  occupation text,
  employer text,
  is_pwd boolean NOT NULL DEFAULT false,
  is_solo_parent boolean NOT NULL DEFAULT false,
  is_indigenous_person boolean NOT NULL DEFAULT false,
  tribe_ethnolinguistic_group text,
  is_4ps_beneficiary boolean NOT NULL DEFAULT false,
  household_id_number text,
  water_source text,
  toilet_facility text,
  height double precision CHECK (height IS NULL OR height > 0),
  weight double precision CHECK (weight IS NULL OR weight > 0),
  allergies text,
  medical_history text,
  category text,
  is_archived boolean NOT NULL DEFAULT false,
  archived_at timestamptz,
  last_visit_date timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT patients_name_not_blank CHECK (
    length(btrim(first_name)) > 0 AND length(btrim(last_name)) > 0
  )
);

CREATE INDEX patients_clinic_name_idx ON public.patients (clinic_id, lower(last_name), lower(first_name));
CREATE INDEX patients_clinic_barangay_idx ON public.patients (clinic_id, barangay) WHERE NOT is_archived;
CREATE INDEX patients_clinic_active_idx ON public.patients (clinic_id, updated_at DESC) WHERE NOT is_archived;
CREATE UNIQUE INDEX patients_clinic_philhealth_uidx ON public.patients
  (clinic_id, regexp_replace(upper(philhealth_number), '[^A-Z0-9]', '', 'g'))
  WHERE philhealth_number IS NOT NULL AND btrim(philhealth_number) <> '';
CREATE UNIQUE INDEX patients_clinic_lgu_id_uidx ON public.patients (clinic_id, lower(btrim(local_lgu_id)))
  WHERE local_lgu_id IS NOT NULL AND btrim(local_lgu_id) <> '';

-- -----------------------------------------------------------------------------
-- 4. QUEUE ITEMS (TENANT ISOLATED)
-- -----------------------------------------------------------------------------
CREATE TABLE public.queue_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id uuid NOT NULL REFERENCES public.clinics(id) ON DELETE RESTRICT,
  patient_id uuid NOT NULL REFERENCES public.patients(id) ON DELETE RESTRICT,
  is_senior boolean NOT NULL DEFAULT false,
  is_pregnant boolean NOT NULL DEFAULT false,
  is_pwd boolean NOT NULL DEFAULT false,
  is_infant boolean NOT NULL DEFAULT false,
  arrival_time timestamptz NOT NULL DEFAULT now(),
  start_time timestamptz,
  end_time timestamptz,
  status text NOT NULL DEFAULT 'waiting'
    CHECK (status IN ('waiting', 'inProgress', 'completed', 'cancelled')),
  nurse_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  doctor_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  complaint text,
  notes text,
  purpose text,
  temperature double precision CHECK (temperature IS NULL OR temperature > 0),
  blood_pressure_systolic double precision CHECK (
    blood_pressure_systolic IS NULL OR blood_pressure_systolic > 0
  ),
  blood_pressure_diastolic double precision CHECK (
    blood_pressure_diastolic IS NULL OR blood_pressure_diastolic > 0
  ),
  heart_rate double precision CHECK (heart_rate IS NULL OR heart_rate > 0),
  respiratory_rate double precision CHECK (respiratory_rate IS NULL OR respiratory_rate > 0),
  oxygen_saturation double precision CHECK (
    oxygen_saturation IS NULL OR oxygen_saturation BETWEEN 0 AND 100
  ),
  weight double precision CHECK (weight IS NULL OR weight > 0),
  height double precision CHECK (height IS NULL OR height > 0),
  red_flags jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(red_flags) = 'array'),
  pain_scale integer CHECK (pain_scale IS NULL OR pain_scale BETWEEN 0 AND 10),
  is_essentially_normal boolean NOT NULL DEFAULT false,
  priority text NOT NULL DEFAULT 'normal'
    CHECK (priority IN ('low', 'normal', 'high', 'emergency')),
  room_number text,
  bmi double precision CHECK (bmi IS NULL OR bmi > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  UNIQUE (id, patient_id),
  CHECK (start_time IS NULL OR start_time >= arrival_time),
  CHECK (end_time IS NULL OR start_time IS NULL OR end_time >= start_time)
);

CREATE INDEX queue_clinic_status_arrival_idx ON public.queue_items (clinic_id, status, arrival_time);
CREATE INDEX queue_clinic_patient_idx ON public.queue_items (clinic_id, patient_id, arrival_time DESC);
CREATE INDEX queue_clinic_staff_idx ON public.queue_items (clinic_id, nurse_id, doctor_id);

-- -----------------------------------------------------------------------------
-- 5. CONSULTATIONS (TENANT ISOLATED)
-- -----------------------------------------------------------------------------
CREATE TABLE public.consultations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id uuid NOT NULL REFERENCES public.clinics(id) ON DELETE RESTRICT,
  patient_id uuid NOT NULL REFERENCES public.patients(id) ON DELETE RESTRICT,
  queue_id uuid,
  doctor_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  consultation_date timestamptz,
  subjective text,
  objective text,
  assessment text,
  plan text,
  icd10_code text,
  icd10_description text,
  is_follow_up boolean NOT NULL DEFAULT false,
  follow_up_instructions text,
  notes text,
  created_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  UNIQUE (id, patient_id),
  FOREIGN KEY (queue_id, patient_id)
    REFERENCES public.queue_items(id, patient_id) ON DELETE RESTRICT
);

CREATE INDEX consultations_clinic_patient_date_idx
  ON public.consultations (clinic_id, patient_id, consultation_date DESC);
CREATE INDEX consultations_clinic_queue_idx ON public.consultations (clinic_id, queue_id);
CREATE INDEX consultations_clinic_author_idx ON public.consultations (clinic_id, created_by);

-- -----------------------------------------------------------------------------
-- 6. PRESCRIPTIONS (TENANT ISOLATED)
-- -----------------------------------------------------------------------------
CREATE TABLE public.prescriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id uuid NOT NULL REFERENCES public.clinics(id) ON DELETE RESTRICT,
  consultation_id uuid NOT NULL REFERENCES public.consultations(id) ON DELETE RESTRICT,
  medication_name text NOT NULL CHECK (length(btrim(medication_name)) > 0),
  generic_name text,
  dosage text NOT NULL CHECK (length(btrim(dosage)) > 0),
  frequency text NOT NULL CHECK (length(btrim(frequency)) > 0),
  duration text NOT NULL CHECK (length(btrim(duration)) > 0),
  instructions text,
  quantity integer NOT NULL CHECK (quantity > 0),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE INDEX prescriptions_clinic_consultation_idx ON public.prescriptions (clinic_id, consultation_id);

-- -----------------------------------------------------------------------------
-- 7. LAB ORDERS (TENANT ISOLATED)
-- -----------------------------------------------------------------------------
CREATE TABLE public.lab_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id uuid NOT NULL REFERENCES public.clinics(id) ON DELETE RESTRICT,
  consultation_id uuid NOT NULL REFERENCES public.consultations(id) ON DELETE RESTRICT,
  test_name text NOT NULL CHECK (length(btrim(test_name)) > 0),
  test_code text,
  instructions text,
  status text NOT NULL DEFAULT 'pending' CHECK (length(btrim(status)) > 0),
  requested_date timestamptz,
  completed_date timestamptz,
  results text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  CHECK (completed_date IS NULL OR requested_date IS NULL OR completed_date >= requested_date)
);

CREATE INDEX lab_orders_clinic_consultation_idx ON public.lab_orders (clinic_id, consultation_id);
CREATE INDEX lab_orders_clinic_status_idx ON public.lab_orders (clinic_id, status, requested_date DESC);

-- -----------------------------------------------------------------------------
-- 8. DOCUMENTS (TENANT ISOLATED)
-- -----------------------------------------------------------------------------
CREATE TABLE public.documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id uuid NOT NULL REFERENCES public.clinics(id) ON DELETE RESTRICT,
  patient_id uuid NOT NULL REFERENCES public.patients(id) ON DELETE RESTRICT,
  consultation_id uuid,
  type text NOT NULL CHECK (length(btrim(type)) > 0),
  title text NOT NULL CHECK (length(btrim(title)) > 0),
  description text,
  file_size bigint NOT NULL DEFAULT 0 CHECK (file_size >= 0),
  mime_type text,
  scanned_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  scan_date timestamptz,
  verified_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  verified_date timestamptz,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'verified', 'archived')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  FOREIGN KEY (consultation_id, patient_id)
    REFERENCES public.consultations(id, patient_id) ON DELETE RESTRICT
);

CREATE INDEX documents_clinic_patient_date_idx ON public.documents (clinic_id, patient_id, created_at DESC);
CREATE INDEX documents_clinic_consultation_idx ON public.documents (clinic_id, consultation_id);

-- -----------------------------------------------------------------------------
-- 9. AUDIT LOGS (TENANT ISOLATED + PLATFORM SCOPE)
-- -----------------------------------------------------------------------------
CREATE TABLE public.audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id uuid REFERENCES public.clinics(id) ON DELETE CASCADE,
  user_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  action text NOT NULL,
  entity_type text NOT NULL,
  entity_id text,
  patient_id uuid REFERENCES public.patients(id) ON DELETE SET NULL,
  old_values jsonb,
  new_values jsonb,
  occurred_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX audit_logs_clinic_time_idx ON public.audit_logs (clinic_id, occurred_at DESC);
CREATE INDEX audit_logs_user_time_idx ON public.audit_logs (user_id, occurred_at DESC);
CREATE INDEX audit_logs_patient_time_idx ON public.audit_logs (patient_id, occurred_at DESC);

-- -----------------------------------------------------------------------------
-- 10. SYNC TOMBSTONES (TENANT ISOLATED)
-- -----------------------------------------------------------------------------
CREATE TABLE public.sync_tombstones (
  clinic_id uuid NOT NULL REFERENCES public.clinics(id) ON DELETE CASCADE,
  entity_type text NOT NULL CHECK (entity_type IN (
    'patients', 'queue_items', 'consultations', 'prescriptions', 'lab_orders',
    'documents', 'generated_reports'
  )),
  record_id uuid NOT NULL,
  deleted_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  deleted_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (clinic_id, entity_type, record_id)
);

CREATE INDEX sync_tombstones_clinic_time_idx ON public.sync_tombstones (clinic_id, deleted_at DESC);

-- -----------------------------------------------------------------------------
-- 11. GENERATED REPORTS (TENANT ISOLATED)
-- -----------------------------------------------------------------------------
CREATE TABLE public.generated_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id uuid NOT NULL REFERENCES public.clinics(id) ON DELETE RESTRICT,
  title text NOT NULL CHECK (length(btrim(title)) > 0),
  type text NOT NULL CHECK (length(btrim(type)) > 0),
  generated_at timestamptz NOT NULL DEFAULT now(),
  start_date timestamptz,
  end_date timestamptz,
  created_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date)
);

CREATE INDEX generated_reports_clinic_date_idx ON public.generated_reports (clinic_id, generated_at DESC);

-- -----------------------------------------------------------------------------
-- 12. SYSTEM SETTINGS
-- -----------------------------------------------------------------------------
CREATE TABLE public.system_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id uuid REFERENCES public.clinics(id) ON DELETE CASCADE,
  key text NOT NULL CHECK (length(btrim(key)) > 0),
  value jsonb NOT NULL,
  updated_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT system_settings_clinic_key_uidx UNIQUE NULLS NOT DISTINCT (clinic_id, key)
);

-- -----------------------------------------------------------------------------
-- 13. NOTIFICATIONS
-- -----------------------------------------------------------------------------
CREATE TABLE public.notifications (
  id text PRIMARY KEY CHECK (length(btrim(id)) > 0),
  clinic_id uuid REFERENCES public.clinics(id) ON DELETE CASCADE,
  type text NOT NULL CHECK (type IN (
    'incompleteRecord', 'syncFailed', 'pendingDocument', 'suspiciousActivity',
    'systemUpdate', 'queueAlert', 'general'
  )),
  target text NOT NULL DEFAULT 'all' CHECK (target IN ('super_admin', 'admin', 'staff', 'all')),
  priority text NOT NULL DEFAULT 'normal'
    CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
  title text NOT NULL CHECK (length(btrim(title)) > 0),
  message text NOT NULL CHECK (length(btrim(message)) > 0),
  action_route text,
  is_read boolean NOT NULL DEFAULT false,
  created_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX notifications_clinic_target_created_idx ON public.notifications (clinic_id, target, created_at DESC);

-- -----------------------------------------------------------------------------
-- 14. MEDICAL SNIPPETS
-- -----------------------------------------------------------------------------
CREATE TABLE public.medical_snippets (
  id text PRIMARY KEY CHECK (length(btrim(id)) > 0),
  clinic_id uuid REFERENCES public.clinics(id) ON DELETE CASCADE,
  shortcut text NOT NULL CHECK (length(btrim(shortcut)) > 0),
  title text NOT NULL CHECK (length(btrim(title)) > 0),
  content text NOT NULL CHECK (length(btrim(content)) > 0),
  category text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT medical_snippets_clinic_shortcut_uidx UNIQUE NULLS NOT DISTINCT (clinic_id, shortcut)
);

CREATE INDEX medical_snippets_clinic_active_idx ON public.medical_snippets (clinic_id, is_active, shortcut);

-- -----------------------------------------------------------------------------
-- 15. SECURITY DEFINER HELPER FUNCTIONS
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.medsentry_current_user_id()
RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT u.id FROM public.users AS u
  WHERE u.auth_user_id = (SELECT auth.uid()) AND u.is_active;
$$;

CREATE OR REPLACE FUNCTION public.medsentry_current_role()
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT u.role FROM public.users AS u
  WHERE u.auth_user_id = (SELECT auth.uid()) AND u.is_active;
$$;

CREATE OR REPLACE FUNCTION public.medsentry_current_clinic_id()
RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT u.clinic_id FROM public.users AS u
  WHERE u.auth_user_id = (SELECT auth.uid()) AND u.is_active;
$$;

CREATE OR REPLACE FUNCTION public.medsentry_is_super_admin()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT COALESCE(
    (SELECT u.role = 'super_admin' FROM public.users AS u WHERE u.auth_user_id = (SELECT auth.uid()) AND u.is_active),
    false
  );
$$;

REVOKE ALL ON FUNCTION public.medsentry_current_user_id() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.medsentry_current_role() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.medsentry_current_clinic_id() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.medsentry_is_super_admin() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.medsentry_current_user_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.medsentry_current_role() TO authenticated;
GRANT EXECUTE ON FUNCTION public.medsentry_current_clinic_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.medsentry_is_super_admin() TO authenticated;

-- Timestamp update trigger function
CREATE OR REPLACE FUNCTION public.medsentry_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

-- Audit row trigger function
CREATE OR REPLACE FUNCTION public.medsentry_audit_row()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  row_data jsonb;
  old_data jsonb;
  new_data jsonb;
  target_id text;
  target_clinic_id uuid;
  target_patient_id uuid;
  operation_action text;
BEGIN
  IF TG_OP <> 'INSERT' THEN old_data := to_jsonb(OLD); END IF;
  IF TG_OP <> 'DELETE' THEN new_data := to_jsonb(NEW); END IF;
  row_data := COALESCE(new_data, old_data);
  target_id := row_data ->> 'id';
  target_clinic_id := NULLIF(row_data ->> 'clinic_id', '')::uuid;
  target_patient_id := CASE
    WHEN TG_TABLE_NAME = 'patients' THEN NULLIF(target_id, '')::uuid
    ELSE NULLIF(row_data ->> 'patient_id', '')::uuid
  END;

  IF target_patient_id IS NULL AND row_data ? 'consultation_id' THEN
    SELECT c.patient_id INTO target_patient_id
    FROM public.consultations AS c
    WHERE c.id = NULLIF(row_data ->> 'consultation_id', '')::uuid;
  END IF;

  IF TG_TABLE_NAME = 'users' THEN
    IF TG_OP = 'INSERT' THEN
      operation_action := 'CREATE_USER';
    ELSIF old_data ->> 'role' IS DISTINCT FROM new_data ->> 'role' THEN
      operation_action := 'CHANGE_ROLE';
    ELSE
      operation_action := 'UPDATE_USER';
    END IF;
  ELSE
    operation_action := CASE
      WHEN TG_OP = 'UPDATE'
        AND old_data ->> 'deleted_at' IS NULL
        AND new_data ->> 'deleted_at' IS NOT NULL THEN 'DELETE_'
      WHEN TG_TABLE_NAME = 'patients' AND TG_OP = 'UPDATE'
        AND old_data ->> 'is_archived' = 'false'
        AND new_data ->> 'is_archived' = 'true' THEN 'DELETE_'
      WHEN TG_OP = 'INSERT' THEN 'CREATE_'
      WHEN TG_OP = 'UPDATE' THEN 'UPDATE_'
      ELSE 'DELETE_'
    END || upper(CASE TG_TABLE_NAME
      WHEN 'queue_items' THEN 'queue'
      WHEN 'consultations' THEN 'consultation'
      WHEN 'audit_logs' THEN 'audit_log'
      WHEN 'system_settings' THEN 'settings'
      ELSE rtrim(TG_TABLE_NAME, 's')
    END);
  END IF;

  INSERT INTO public.audit_logs
    (clinic_id, user_id, action, entity_type, entity_id, patient_id, old_values, new_values)
  VALUES
    (target_clinic_id, public.medsentry_current_user_id(), operation_action, TG_TABLE_NAME,
     target_id, target_patient_id, old_data, new_data);
  RETURN NULL;
END;
$$;

-- Apply sync delete function
CREATE OR REPLACE FUNCTION public.medsentry_apply_sync_delete(entity text, target_record_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  actor_id uuid;
  actor_clinic_id uuid;
  is_super boolean;
BEGIN
  actor_id := public.medsentry_current_user_id();
  actor_clinic_id := public.medsentry_current_clinic_id();
  is_super := public.medsentry_is_super_admin();

  IF actor_id IS NULL THEN
    RAISE EXCEPTION 'active user session required' USING ERRCODE = '42501';
  END IF;

  CASE entity
    WHEN 'patients' THEN
      UPDATE public.patients
      SET is_archived = true, archived_at = COALESCE(archived_at, now())
      WHERE id = target_record_id
        AND (is_super OR clinic_id = actor_clinic_id);
    WHEN 'queue_items' THEN
      UPDATE public.queue_items SET deleted_at = COALESCE(deleted_at, now())
      WHERE id = target_record_id
        AND (is_super OR clinic_id = actor_clinic_id);
    WHEN 'consultations' THEN
      UPDATE public.consultations SET deleted_at = COALESCE(deleted_at, now())
      WHERE id = target_record_id
        AND (is_super OR clinic_id = actor_clinic_id);
    WHEN 'prescriptions' THEN
      UPDATE public.prescriptions SET deleted_at = COALESCE(deleted_at, now())
      WHERE id = target_record_id
        AND (is_super OR clinic_id = actor_clinic_id);
    WHEN 'lab_orders' THEN
      UPDATE public.lab_orders SET deleted_at = COALESCE(deleted_at, now())
      WHERE id = target_record_id
        AND (is_super OR clinic_id = actor_clinic_id);
    WHEN 'documents' THEN
      UPDATE public.documents SET deleted_at = COALESCE(deleted_at, now())
      WHERE id = target_record_id
        AND (is_super OR clinic_id = actor_clinic_id);
    WHEN 'generated_reports' THEN
      UPDATE public.generated_reports SET deleted_at = COALESCE(deleted_at, now())
      WHERE id = target_record_id
        AND (is_super OR clinic_id = actor_clinic_id);
    ELSE
      RAISE EXCEPTION 'unsupported sync delete type' USING ERRCODE = '22023';
  END CASE;

  IF actor_clinic_id IS NOT NULL THEN
    INSERT INTO public.sync_tombstones (clinic_id, entity_type, record_id, deleted_by)
    VALUES (actor_clinic_id, entity, target_record_id, actor_id)
    ON CONFLICT (clinic_id, entity_type, record_id) DO NOTHING;
  END IF;
END;
$$;

-- Auth event logger function
CREATE OR REPLACE FUNCTION public.medsentry_log_auth_event(event_action text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  actor_id uuid;
  actor_clinic_id uuid;
BEGIN
  actor_id := public.medsentry_current_user_id();
  actor_clinic_id := public.medsentry_current_clinic_id();
  IF actor_id IS NULL THEN
    RAISE EXCEPTION 'active user session required' USING ERRCODE = '42501';
  END IF;
  IF event_action IS NULL OR event_action NOT IN ('LOGIN', 'LOGOUT', 'CHANGE_PASSWORD') THEN
    RAISE EXCEPTION 'unsupported auth event' USING ERRCODE = '22023';
  END IF;
  INSERT INTO public.audit_logs (clinic_id, user_id, action, entity_type, entity_id)
  VALUES (actor_clinic_id, actor_id, event_action, 'auth', actor_id::text);
  IF event_action = 'LOGIN' THEN
    UPDATE public.users SET last_login_at = now() WHERE id = actor_id;
  END IF;
END;
$$;

-- Password reset audit function
CREATE OR REPLACE FUNCTION public.medsentry_audit_password_reset(target_user_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  actor_id uuid;
  actor_clinic_id uuid;
BEGIN
  actor_id := public.medsentry_current_user_id();
  actor_clinic_id := public.medsentry_current_clinic_id();
  IF actor_id IS NULL OR (public.medsentry_current_role() NOT IN ('super_admin', 'admin')) THEN
    RAISE EXCEPTION 'administrator role required' USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = target_user_id) THEN
    RAISE EXCEPTION 'user profile not found' USING ERRCODE = 'P0002';
  END IF;
  INSERT INTO public.audit_logs (clinic_id, user_id, action, entity_type, entity_id)
  VALUES (actor_clinic_id, actor_id, 'RESET_PASSWORD', 'user', target_user_id::text);
END;
$$;

-- New auth user trigger function
CREATE OR REPLACE FUNCTION public.medsentry_create_profile_for_auth_user()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF NEW.email IS NULL THEN RETURN NEW; END IF;
  IF EXISTS (SELECT 1 FROM public.users WHERE auth_user_id = NEW.id) THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.users (auth_user_id, email, first_name, last_name, role, clinic_id)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NULLIF(NEW.raw_user_meta_data ->> 'first_name', ''), split_part(NEW.email, '@', 1)),
    COALESCE(NULLIF(NEW.raw_user_meta_data ->> 'last_name', ''), ''),
    COALESCE(NEW.raw_user_meta_data ->> 'role', 'staff'),
    NULLIF(NEW.raw_user_meta_data ->> 'clinic_id', '')::uuid
  )
  ON CONFLICT (auth_user_id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- Account update function
CREATE OR REPLACE FUNCTION public.medsentry_update_user_account(
  target_user_id uuid,
  requested_role text,
  requested_active boolean,
  requested_first_name text,
  requested_last_name text,
  requested_license_number text,
  requested_specialization text,
  requested_contact_number text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  actor_id uuid;
  actor_role text;
  actor_clinic_id uuid;
  target_clinic_id uuid;
  existing_role text;
  existing_active boolean;
BEGIN
  actor_id := public.medsentry_current_user_id();
  actor_role := public.medsentry_current_role();
  actor_clinic_id := public.medsentry_current_clinic_id();
  IF actor_id IS NULL OR actor_role IS NULL THEN
    RAISE EXCEPTION 'active user session required' USING ERRCODE = '42501';
  END IF;
  IF requested_role IS NULL OR requested_role NOT IN ('super_admin', 'admin', 'staff') THEN
    RAISE EXCEPTION 'invalid role' USING ERRCODE = '22023';
  END IF;

  SELECT role, is_active, clinic_id INTO existing_role, existing_active, target_clinic_id
  FROM public.users WHERE id = target_user_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'user profile not found' USING ERRCODE = 'P0002'; END IF;

  -- Permission checks: super_admin can edit any; admin can only edit users within their clinic
  IF actor_role = 'admin' THEN
    IF target_clinic_id IS DISTINCT FROM actor_clinic_id THEN
      RAISE EXCEPTION 'cannot manage users from other clinics' USING ERRCODE = '42501';
    END IF;
    IF requested_role = 'super_admin' THEN
      RAISE EXCEPTION 'admin cannot promote to super_admin' USING ERRCODE = '42501';
    END IF;
  ELSIF actor_role = 'staff' THEN
    IF actor_id <> target_user_id THEN
      RAISE EXCEPTION 'staff cannot edit other users' USING ERRCODE = '42501';
    END IF;
    IF requested_role IS DISTINCT FROM existing_role OR requested_active IS DISTINCT FROM existing_active THEN
      RAISE EXCEPTION 'staff cannot alter role or active status' USING ERRCODE = '42501';
    END IF;
  END IF;

  IF length(btrim(requested_first_name)) = 0 OR length(btrim(requested_last_name)) = 0 THEN
    RAISE EXCEPTION 'first and last name are required' USING ERRCODE = '22023';
  END IF;

  UPDATE public.users
  SET role = requested_role,
      is_active = requested_active,
      first_name = btrim(requested_first_name),
      last_name = btrim(requested_last_name),
      license_number = requested_license_number,
      specialization = requested_specialization,
      contact_number = requested_contact_number,
      updated_at = now()
  WHERE id = target_user_id;
END;
$$;

-- Permissions on functions
REVOKE ALL ON FUNCTION public.medsentry_set_updated_at() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.medsentry_audit_row() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.medsentry_create_profile_for_auth_user() FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.medsentry_apply_sync_delete(text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.medsentry_apply_sync_delete(text, uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.medsentry_log_auth_event(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.medsentry_log_auth_event(text) TO authenticated;

REVOKE ALL ON FUNCTION public.medsentry_audit_password_reset(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.medsentry_audit_password_reset(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.medsentry_update_user_account(uuid, text, boolean, text, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.medsentry_update_user_account(uuid, text, boolean, text, text, text, text, text) TO authenticated;

-- Triggers for auth profile
CREATE TRIGGER auth_user_profile_created
  AFTER INSERT OR UPDATE OF email ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.medsentry_create_profile_for_auth_user();

-- Updated_at & audit triggers
DO $$
DECLARE t_name text;
BEGIN
  FOREACH t_name IN ARRAY ARRAY[
    'clinics', 'users', 'patients', 'queue_items', 'consultations', 'prescriptions',
    'lab_orders', 'documents', 'generated_reports', 'system_settings',
    'notifications', 'medical_snippets'
  ] LOOP
    EXECUTE format(
      'CREATE TRIGGER %I BEFORE UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.medsentry_set_updated_at()',
      t_name || '_set_updated_at', t_name
    );
  END LOOP;

  FOREACH t_name IN ARRAY ARRAY[
    'clinics', 'users', 'patients', 'queue_items', 'consultations', 'prescriptions',
    'lab_orders', 'documents', 'generated_reports', 'system_settings',
    'notifications', 'medical_snippets'
  ] LOOP
    EXECUTE format(
      'CREATE TRIGGER %I AFTER INSERT OR UPDATE OR DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.medsentry_audit_row()',
      t_name || '_audit', t_name
    );
  END LOOP;
END;
$$;

-- -----------------------------------------------------------------------------
-- 16. ROW LEVEL SECURITY (RLS) POLICIES
-- -----------------------------------------------------------------------------
ALTER TABLE public.clinics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.queue_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consultations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prescriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lab_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sync_tombstones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.generated_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.medical_snippets ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon, authenticated;

-- Table Grants
GRANT SELECT, INSERT, UPDATE, DELETE ON public.clinics TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.users TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.patients, public.queue_items, public.consultations,
  public.prescriptions, public.lab_orders, public.documents TO authenticated;
GRANT SELECT ON public.audit_logs TO authenticated;
GRANT SELECT, INSERT ON public.sync_tombstones TO authenticated;
GRANT SELECT, INSERT ON public.generated_reports TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.system_settings TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.notifications TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.medical_snippets TO authenticated;

-- Clinics Policies
CREATE POLICY clinics_super_admin_all ON public.clinics FOR ALL TO authenticated
  USING (public.medsentry_is_super_admin())
  WITH CHECK (public.medsentry_is_super_admin());

CREATE POLICY clinics_tenant_read ON public.clinics FOR SELECT TO authenticated
  USING (id = public.medsentry_current_clinic_id());

-- Users Policies
CREATE POLICY users_super_admin_all ON public.users FOR ALL TO authenticated
  USING (public.medsentry_is_super_admin())
  WITH CHECK (public.medsentry_is_super_admin());

CREATE POLICY users_tenant_admin_read ON public.users FOR SELECT TO authenticated
  USING (
    public.medsentry_current_role() = 'admin' AND clinic_id = public.medsentry_current_clinic_id()
  );

CREATE POLICY users_self_read ON public.users FOR SELECT TO authenticated
  USING (id = public.medsentry_current_user_id());

-- Patients Policies (Tenant Isolation)
CREATE POLICY patients_access ON public.patients FOR ALL TO authenticated
  USING (
    public.medsentry_is_super_admin() OR
    (public.medsentry_current_role() IN ('admin', 'staff') AND clinic_id = public.medsentry_current_clinic_id())
  )
  WITH CHECK (
    public.medsentry_is_super_admin() OR
    (public.medsentry_current_role() IN ('admin', 'staff') AND clinic_id = public.medsentry_current_clinic_id())
  );

-- Queue Items Policies (Tenant Isolation)
CREATE POLICY queue_items_access ON public.queue_items FOR ALL TO authenticated
  USING (
    deleted_at IS NULL AND (
      public.medsentry_is_super_admin() OR
      (public.medsentry_current_role() IN ('admin', 'staff') AND clinic_id = public.medsentry_current_clinic_id())
    )
  )
  WITH CHECK (
    deleted_at IS NULL AND (
      public.medsentry_is_super_admin() OR
      (public.medsentry_current_role() IN ('admin', 'staff') AND clinic_id = public.medsentry_current_clinic_id())
    )
  );

-- Consultations Policies (Tenant Isolation)
CREATE POLICY consultations_access ON public.consultations FOR ALL TO authenticated
  USING (
    deleted_at IS NULL AND (
      public.medsentry_is_super_admin() OR
      (public.medsentry_current_role() IN ('admin', 'staff') AND clinic_id = public.medsentry_current_clinic_id())
    )
  )
  WITH CHECK (
    deleted_at IS NULL AND (
      public.medsentry_is_super_admin() OR
      (public.medsentry_current_role() IN ('admin', 'staff') AND clinic_id = public.medsentry_current_clinic_id())
    )
  );

-- Prescriptions Policies (Tenant Isolation)
CREATE POLICY prescriptions_access ON public.prescriptions FOR ALL TO authenticated
  USING (
    deleted_at IS NULL AND (
      public.medsentry_is_super_admin() OR
      (public.medsentry_current_role() IN ('admin', 'staff') AND clinic_id = public.medsentry_current_clinic_id())
    )
  )
  WITH CHECK (
    deleted_at IS NULL AND (
      public.medsentry_is_super_admin() OR
      (public.medsentry_current_role() IN ('admin', 'staff') AND clinic_id = public.medsentry_current_clinic_id())
    )
  );

-- Lab Orders Policies (Tenant Isolation)
CREATE POLICY lab_orders_access ON public.lab_orders FOR ALL TO authenticated
  USING (
    deleted_at IS NULL AND (
      public.medsentry_is_super_admin() OR
      (public.medsentry_current_role() IN ('admin', 'staff') AND clinic_id = public.medsentry_current_clinic_id())
    )
  )
  WITH CHECK (
    deleted_at IS NULL AND (
      public.medsentry_is_super_admin() OR
      (public.medsentry_current_role() IN ('admin', 'staff') AND clinic_id = public.medsentry_current_clinic_id())
    )
  );

-- Documents Policies (Tenant Isolation)
CREATE POLICY documents_access ON public.documents FOR ALL TO authenticated
  USING (
    deleted_at IS NULL AND (
      public.medsentry_is_super_admin() OR
      (public.medsentry_current_role() IN ('admin', 'staff') AND clinic_id = public.medsentry_current_clinic_id())
    )
  )
  WITH CHECK (
    deleted_at IS NULL AND (
      public.medsentry_is_super_admin() OR
      (public.medsentry_current_role() IN ('admin', 'staff') AND clinic_id = public.medsentry_current_clinic_id())
    )
  );

-- Audit Logs Policies
CREATE POLICY audit_logs_read ON public.audit_logs FOR SELECT TO authenticated
  USING (
    public.medsentry_is_super_admin() OR
    (public.medsentry_current_role() = 'admin' AND clinic_id = public.medsentry_current_clinic_id())
  );

-- Sync Tombstones Policies
CREATE POLICY sync_tombstones_access ON public.sync_tombstones FOR ALL TO authenticated
  USING (
    public.medsentry_is_super_admin() OR
    (public.medsentry_current_role() IN ('admin', 'staff') AND clinic_id = public.medsentry_current_clinic_id())
  )
  WITH CHECK (
    public.medsentry_is_super_admin() OR
    (public.medsentry_current_role() IN ('admin', 'staff') AND clinic_id = public.medsentry_current_clinic_id())
  );

-- Generated Reports Policies
CREATE POLICY generated_reports_access ON public.generated_reports FOR ALL TO authenticated
  USING (
    deleted_at IS NULL AND (
      public.medsentry_is_super_admin() OR
      (public.medsentry_current_role() IN ('admin', 'staff') AND clinic_id = public.medsentry_current_clinic_id())
    )
  )
  WITH CHECK (
    deleted_at IS NULL AND (
      public.medsentry_is_super_admin() OR
      (public.medsentry_current_role() IN ('admin', 'staff') AND clinic_id = public.medsentry_current_clinic_id())
    )
  );

-- System Settings Policies
CREATE POLICY system_settings_access ON public.system_settings FOR ALL TO authenticated
  USING (
    public.medsentry_is_super_admin() OR
    (public.medsentry_current_role() = 'admin' AND (clinic_id IS NULL OR clinic_id = public.medsentry_current_clinic_id()))
  )
  WITH CHECK (
    public.medsentry_is_super_admin() OR
    (public.medsentry_current_role() = 'admin' AND clinic_id = public.medsentry_current_clinic_id())
  );

-- Notifications Policies
CREATE POLICY notifications_select ON public.notifications FOR SELECT TO authenticated
  USING (
    public.medsentry_is_super_admin() OR
    (
      (clinic_id IS NULL OR clinic_id = public.medsentry_current_clinic_id()) AND
      (
        target = 'all' OR
        (public.medsentry_current_role() = 'admin' AND target IN ('admin', 'staff')) OR
        (public.medsentry_current_role() = 'staff' AND target = 'staff')
      )
    )
  );

CREATE POLICY notifications_manage ON public.notifications FOR ALL TO authenticated
  USING (
    public.medsentry_is_super_admin() OR
    (public.medsentry_current_role() = 'admin' AND clinic_id = public.medsentry_current_clinic_id())
  )
  WITH CHECK (
    public.medsentry_is_super_admin() OR
    (public.medsentry_current_role() = 'admin' AND clinic_id = public.medsentry_current_clinic_id())
  );

-- Medical Snippets Policies
CREATE POLICY medical_snippets_select ON public.medical_snippets FOR SELECT TO authenticated
  USING (
    public.medsentry_is_super_admin() OR
    ((clinic_id IS NULL OR clinic_id = public.medsentry_current_clinic_id()) AND is_active)
  );

CREATE POLICY medical_snippets_manage ON public.medical_snippets FOR ALL TO authenticated
  USING (
    public.medsentry_is_super_admin() OR
    (public.medsentry_current_role() = 'admin' AND clinic_id = public.medsentry_current_clinic_id())
  )
  WITH CHECK (
    public.medsentry_is_super_admin() OR
    (public.medsentry_current_role() = 'admin' AND clinic_id = public.medsentry_current_clinic_id())
  );

-- -----------------------------------------------------------------------------
-- 17. SEED DATA: RHUs & SUPER ADMIN ONLY
-- -----------------------------------------------------------------------------
-- Initial RHUs
INSERT INTO public.clinics (id, name, code, address, contact_number, status)
VALUES
  ('11111111-1111-4111-8111-111111111111', 'RHU Parang', 'RHU-PARANG', 'Parang, Maguindanao del Norte', '09171110001', 'active'),
  ('22222222-2222-4222-8222-222222222222', 'RHU Puyat', 'RHU-PUYAT', 'Puyat, San Agustin, Surigao del Sur', '09172220002', 'active'),
  ('33333333-3333-4333-8333-333333333333', 'RHU Cantilan', 'RHU-CANTILAN', 'Cantilan, Surigao del Sur', '09173330003', 'active')
ON CONFLICT (code) DO NOTHING;

-- Super Admin User Provisioning
DO $$
DECLARE
  super_admin_id uuid := '00000000-0000-4000-8000-000000000001';
  encrypted_pw text;
BEGIN
  encrypted_pw := crypt('Password123!', gen_salt('bf', 10));

  -- Insert/update auth.users
  INSERT INTO auth.users (
    id,
    instance_id,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    role,
    aud,
    confirmation_token
  ) VALUES (
    super_admin_id,
    '00000000-0000-0000-0000-000000000000',
    'superadmin@gmail.com',
    encrypted_pw,
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"first_name":"System","last_name":"SuperAdmin","role":"super_admin"}'::jsonb,
    now(),
    now(),
    'authenticated',
    'authenticated',
    encode(gen_random_bytes(32), 'hex')
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    encrypted_password = encrypted_pw,
    email_confirmed_at = now(),
    updated_at = now();

  -- Insert/update auth.identities
  INSERT INTO auth.identities (
    id,
    user_id,
    identity_data,
    provider,
    provider_id,
    last_sign_in_at,
    created_at,
    updated_at
  ) VALUES (
    super_admin_id,
    super_admin_id,
    jsonb_build_object('sub', super_admin_id::text, 'email', 'superadmin@gmail.com'),
    'email',
    super_admin_id::text,
    now(),
    now(),
    now()
  )
  ON CONFLICT (provider, provider_id) DO UPDATE SET
    identity_data = EXCLUDED.identity_data,
    updated_at = now();

  -- Insert/update public.users profile
  INSERT INTO public.users (
    id,
    auth_user_id,
    clinic_id,
    email,
    first_name,
    last_name,
    role,
    contact_number,
    is_active
  ) VALUES (
    super_admin_id,
    super_admin_id,
    NULL,
    'superadmin@gmail.com',
    'System',
    'SuperAdmin',
    'super_admin',
    '09170000001',
    true
  )
  ON CONFLICT (auth_user_id) DO UPDATE SET
    email = EXCLUDED.email,
    clinic_id = NULL,
    role = 'super_admin',
    is_active = true,
    updated_at = now();
END;
$$;

