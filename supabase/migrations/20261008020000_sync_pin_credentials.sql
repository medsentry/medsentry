BEGIN;

CREATE TABLE public.user_pin_credentials (
  user_id uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  pin_hash text NOT NULL,
  failed_attempts integer NOT NULL DEFAULT 0
    CHECK (failed_attempts BETWEEN 0 AND 5),
  locked_until timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.user_pin_credentials ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.user_pin_credentials FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.medsentry_set_user_pin(
  target_user_id uuid,
  requested_pin text,
  requested_enabled boolean
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  actor_id uuid;
  actor_role text;
BEGIN
  actor_id := public.medsentry_current_user_id();
  actor_role := public.medsentry_current_role();

  IF actor_id IS NULL OR actor_role IS NULL THEN
    RAISE EXCEPTION 'active user session required' USING ERRCODE = '42501';
  END IF;
  IF actor_id <> target_user_id AND actor_role <> 'super_admin' THEN
    RAISE EXCEPTION 'cannot change another user PIN' USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = target_user_id AND is_active
  ) THEN
    RAISE EXCEPTION 'active user profile not found' USING ERRCODE = 'P0002';
  END IF;

  IF requested_enabled THEN
    IF requested_pin IS NULL OR requested_pin !~ '^[0-9]{4}$' THEN
      RAISE EXCEPTION 'PIN must be exactly 4 digits' USING ERRCODE = '22023';
    END IF;

    INSERT INTO public.user_pin_credentials (user_id, pin_hash)
    VALUES (target_user_id, extensions.crypt(requested_pin, extensions.gen_salt('bf', 12)))
    ON CONFLICT (user_id) DO UPDATE
    SET pin_hash = EXCLUDED.pin_hash,
        failed_attempts = 0,
        locked_until = NULL,
        updated_at = now();
  ELSE
    DELETE FROM public.user_pin_credentials
    WHERE user_id = target_user_id;
  END IF;

  UPDATE public.users
  SET pin_enabled = requested_enabled,
      updated_at = now()
  WHERE id = target_user_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.medsentry_verify_user_pin(
  target_user_id uuid,
  requested_pin text
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  actor_id uuid;
  actor_role text;
  stored_hash text;
  failed_count integer;
  lock_expiry timestamptz;
BEGIN
  actor_id := public.medsentry_current_user_id();
  actor_role := public.medsentry_current_role();

  IF actor_id IS NULL OR actor_role IS NULL THEN
    RAISE EXCEPTION 'active user session required' USING ERRCODE = '42501';
  END IF;
  IF actor_id <> target_user_id AND actor_role <> 'super_admin' THEN
    RAISE EXCEPTION 'cannot verify another user PIN' USING ERRCODE = '42501';
  END IF;
  IF requested_pin IS NULL OR requested_pin !~ '^[0-9]{4}$' THEN
    RETURN 'invalid';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = target_user_id AND is_active AND pin_enabled
  ) THEN
    RETURN 'disabled';
  END IF;

  SELECT pin_hash, failed_attempts, locked_until
  INTO stored_hash, failed_count, lock_expiry
  FROM public.user_pin_credentials
  WHERE user_id = target_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN 'not_configured';
  END IF;
  IF lock_expiry IS NOT NULL AND lock_expiry > now() THEN
    RETURN 'locked';
  END IF;

  IF extensions.crypt(requested_pin, stored_hash) = stored_hash THEN
    UPDATE public.user_pin_credentials
    SET failed_attempts = 0, locked_until = NULL, updated_at = now()
    WHERE user_id = target_user_id;
    RETURN 'verified';
  END IF;

  failed_count := failed_count + 1;
  UPDATE public.user_pin_credentials
  SET failed_attempts = CASE WHEN failed_count >= 5 THEN 0 ELSE failed_count END,
      locked_until = CASE
        WHEN failed_count >= 5 THEN now() + interval '5 minutes'
        ELSE NULL
      END,
      updated_at = now()
  WHERE user_id = target_user_id;

  RETURN 'invalid';
END;
$$;

REVOKE ALL ON FUNCTION public.medsentry_set_user_pin(uuid, text, boolean)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.medsentry_set_user_pin(uuid, text, boolean)
  TO authenticated;

REVOKE ALL ON FUNCTION public.medsentry_verify_user_pin(uuid, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.medsentry_verify_user_pin(uuid, text)
  TO authenticated;

COMMIT;
