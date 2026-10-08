BEGIN;

-- Retain patient documents, but detach them from consultation records so the
-- patient document archive survives the SOAP data purge.
UPDATE public.documents
SET consultation_id = NULL
WHERE consultation_id IS NOT NULL;

DELETE FROM public.prescriptions;
DELETE FROM public.lab_orders;
DELETE FROM public.consultations;
DELETE FROM public.queue_items;

-- These audit rows can contain the clinical details being removed above.
-- Documents and their audit history are intentionally preserved.
DELETE FROM public.audit_logs
WHERE entity_type IN (
  'queue_items',
  'consultations',
  'prescriptions',
  'lab_orders'
);

DELETE FROM public.sync_tombstones
WHERE entity_type = 'queue_items';

DROP TABLE IF EXISTS public.queue_items CASCADE;

COMMIT;