-- Broadcast RHU facility changes to signed-in MedSentry clients.
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.clinics;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END;
$$;
