-- Replace the document review states with a simple active/archived lifecycle.
ALTER TABLE public.documents
  DROP CONSTRAINT IF EXISTS documents_status_check;

UPDATE public.documents
SET status = 'active'
WHERE status IN ('pending', 'verified');

ALTER TABLE public.documents
  ALTER COLUMN status SET DEFAULT 'active',
  ADD CONSTRAINT documents_status_check
    CHECK (status IN ('active', 'archived'));
