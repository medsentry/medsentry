-- The sign-in page, the startup loader and the browser tab show the logo
-- before anyone has signed in, when system_settings is unreadable. Expose only
-- the super admin's app name and logo; every other setting stays private.
CREATE OR REPLACE FUNCTION public.medsentry_public_branding()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT jsonb_build_object(
    'app_name', s.value ->> 'app_name',
    'logo_data_uri', s.value ->> 'logo_data_uri',
    'updated_at', s.updated_at
  )
  FROM public.system_settings s
  WHERE s.clinic_id IS NULL AND s.key = 'clinic'
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.medsentry_public_branding() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.medsentry_public_branding() TO anon, authenticated;
