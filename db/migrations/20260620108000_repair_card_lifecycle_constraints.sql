-- migrate:up

UPDATE public.cards
SET execution_state = 'draft'
WHERE execution_state IS NULL
   OR execution_state NOT IN ('draft', 'active', 'closed');

UPDATE public.cards
SET closed_reason = NULL
WHERE closed_reason IS NOT NULL
  AND closed_reason NOT IN ('rollup', 'manually_closed');

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.cards'::regclass
      AND conname = 'cards_execution_state_check'
  ) THEN
    ALTER TABLE public.cards DROP CONSTRAINT cards_execution_state_check;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.cards'::regclass
      AND conname = 'cards_closed_reason_check'
  ) THEN
    ALTER TABLE public.cards DROP CONSTRAINT cards_closed_reason_check;
  END IF;
END $$;

ALTER TABLE public.cards
  ADD CONSTRAINT cards_execution_state_check
  CHECK (execution_state IN ('draft', 'active', 'closed'));

ALTER TABLE public.cards
  ADD CONSTRAINT cards_closed_reason_check
  CHECK (
    closed_reason IS NULL
    OR closed_reason IN ('rollup', 'manually_closed')
  );

-- migrate:down

ALTER TABLE public.cards
  DROP CONSTRAINT IF EXISTS cards_closed_reason_check;

ALTER TABLE public.cards
  DROP CONSTRAINT IF EXISTS cards_execution_state_check;
