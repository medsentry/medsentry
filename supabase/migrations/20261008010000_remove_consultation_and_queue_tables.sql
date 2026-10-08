BEGIN;

UPDATE public.documents
SET consultation_id = NULL
WHERE consultation_id IS NOT NULL;

DELETE FROM public.audit_logs
WHERE entity_type IN (
  'queue_items',
  'consultation',
  'consultations',
  'prescriptions',
  'lab_orders'
);

DELETE FROM public.sync_tombstones
WHERE entity_type IN (
  'queue_items',
  'consultation',
  'consultations',
  'prescriptions',
  'lab_orders'
);

DROP TABLE IF EXISTS public.prescriptions CASCADE;
DROP TABLE IF EXISTS public.lab_orders CASCADE;
DROP TABLE IF EXISTS public.consultations CASCADE;
DROP TABLE IF EXISTS public.queue_items CASCADE;

ALTER TABLE public.documents
  DROP COLUMN IF EXISTS consultation_id;

COMMIT;
