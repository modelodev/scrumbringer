-- migrate:up

UPDATE public.rules
SET
  active = false,
  trigger_kind = CASE
    WHEN resource_type = 'card' THEN 'card_closed'
    ELSE 'task_completed'
  END,
  to_state = CASE
    WHEN resource_type = 'card' THEN 'cerrada'
    ELSE 'completed'
  END
WHERE trigger_kind = 'invalid_migrated_rule';

ALTER TABLE public.rules
  DROP CONSTRAINT IF EXISTS rules_trigger_kind_check;

ALTER TABLE public.rules
  ADD CONSTRAINT rules_trigger_kind_check
  CHECK (trigger_kind IN (
    'task_created',
    'task_claimed',
    'task_released',
    'task_completed',
    'card_activated',
    'card_closed'
  ));

-- migrate:down

ALTER TABLE public.rules
  DROP CONSTRAINT IF EXISTS rules_trigger_kind_check;

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
