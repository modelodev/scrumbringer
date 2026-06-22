-- migrate:up

ALTER TABLE public.cards
  ALTER COLUMN execution_state SET DEFAULT 'draft';

UPDATE public.cards
SET execution_state = 'draft'
WHERE execution_state IS NULL;

ALTER TABLE public.cards
  ALTER COLUMN execution_state SET NOT NULL;

-- migrate:down

DO $$
BEGIN
  RAISE EXCEPTION 'repair_card_execution_state_default_is_irreversible';
END $$;
