-- migrate:up

ALTER TABLE public.rules
  ADD COLUMN IF NOT EXISTS trigger_kind TEXT;

UPDATE public.rules
SET trigger_kind = CASE
  WHEN resource_type = 'task' AND to_state = 'claimed' THEN 'task_claimed'
  WHEN resource_type = 'task' AND to_state = 'completed' THEN 'task_completed'
  WHEN resource_type = 'task' AND to_state = 'done' THEN 'task_completed'
  WHEN resource_type = 'task' AND to_state = 'available' THEN 'task_created'
  WHEN resource_type = 'card' AND to_state = 'en_curso' THEN 'card_activated'
  WHEN resource_type = 'card' AND to_state = 'cerrada' THEN 'card_closed'
  ELSE 'invalid_migrated_rule'
END
WHERE trigger_kind IS NULL OR trigger_kind = '';

UPDATE public.rules
SET active = false
WHERE resource_type = 'task'
  AND to_state = 'available';

UPDATE public.rules
SET active = false
WHERE trigger_kind = 'invalid_migrated_rule';

ALTER TABLE public.rules
  ALTER COLUMN trigger_kind SET NOT NULL;

ALTER TABLE public.rules
  ADD CONSTRAINT rules_trigger_kind_check
  CHECK (trigger_kind IN (
    'task_created',
    'task_claimed',
    'task_released',
    'task_completed',
    'card_activated',
    'card_closed',
    'invalid_migrated_rule'
  ));

CREATE INDEX IF NOT EXISTS idx_rules_trigger_kind
  ON public.rules(trigger_kind);

-- migrate:down

DROP INDEX IF EXISTS public.idx_rules_trigger_kind;

ALTER TABLE public.rules
  DROP CONSTRAINT IF EXISTS rules_trigger_kind_check;

ALTER TABLE public.rules
  DROP COLUMN IF EXISTS trigger_kind;
