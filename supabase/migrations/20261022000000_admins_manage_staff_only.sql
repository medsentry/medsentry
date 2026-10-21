-- An RHU Admin could edit, demote or deactivate another Admin of the same
-- clinic, which let one admin lock a peer out. Only a Super Admin manages
-- Admin accounts; an RHU Admin manages Staff and their own profile.
-- (Password resets and deletion are enforced the same way in the
-- provision-user Edge Function.)
CREATE OR REPLACE FUNCTION public.medsentry_update_user_account(
  target_user_id uuid,
  requested_role text,
  requested_active boolean,
  requested_first_name text,
  requested_last_name text,
  requested_license_number text,
  requested_specialization text,
  requested_contact_number text
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
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

  -- Permission checks: super_admin can edit any; admin can edit staff within
  -- their clinic and their own profile
  IF actor_role = 'admin' THEN
    IF target_clinic_id IS DISTINCT FROM actor_clinic_id THEN
      RAISE EXCEPTION 'cannot manage users from other clinics' USING ERRCODE = '42501';
    END IF;
    IF requested_role = 'super_admin' THEN
      RAISE EXCEPTION 'admin cannot promote to super_admin' USING ERRCODE = '42501';
    END IF;
    IF actor_id <> target_user_id AND existing_role <> 'staff' THEN
      RAISE EXCEPTION 'only a super administrator can manage administrator accounts' USING ERRCODE = '42501';
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
