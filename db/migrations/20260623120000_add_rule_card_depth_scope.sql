-- migrate:up

ALTER TABLE public.rules
  ADD COLUMN IF NOT EXISTS card_depth INT;

ALTER TABLE public.rules
  ADD CONSTRAINT rules_card_depth_check
  CHECK (card_depth IS NULL OR card_depth > 0);

CREATE INDEX IF NOT EXISTS idx_rules_card_depth
  ON public.rules(card_depth)
  WHERE card_depth IS NOT NULL;

-- migrate:down

DROP INDEX IF EXISTS public.idx_rules_card_depth;

ALTER TABLE public.rules
  DROP CONSTRAINT IF EXISTS rules_card_depth_check;

ALTER TABLE public.rules
  DROP COLUMN IF EXISTS card_depth;
