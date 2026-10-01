CREATE OR REPLACE FUNCTION public.medsentry_create_profile_for_auth_user()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF NEW.email IS NULL THEN RETURN NEW; END IF;
  
  IF EXISTS (SELECT 1 FROM public.users WHERE auth_user_id = NEW.id OR lower(email) = lower(NEW.email)) THEN
    UPDATE public.users
    SET auth_user_id = NEW.id,
        updated_at = now()
    WHERE auth_user_id = NEW.id OR lower(email) = lower(NEW.email);
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
  );
  RETURN NEW;
END;
$$;
