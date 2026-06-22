-- migrate:up

ALTER TABLE public.rule_executions
  ADD COLUMN IF NOT EXISTS event_key TEXT;

ALTER TABLE public.task_templates
  ADD COLUMN IF NOT EXISTS version INTEGER NOT NULL DEFAULT 1;

ALTER TABLE public.rule_executions
  ADD COLUMN IF NOT EXISTS template_id BIGINT,
  ADD COLUMN IF NOT EXISTS template_version INTEGER,
  ADD COLUMN IF NOT EXISTS created_task_id BIGINT;

UPDATE public.rule_executions
SET event_key = CASE
  WHEN task_id IS NOT NULL THEN 'legacy_task:' || task_id::text
  WHEN card_id IS NOT NULL THEN 'legacy_card:' || card_id::text
  ELSE 'legacy_execution:' || id::text
END
WHERE event_key IS NULL OR event_key = '';

ALTER TABLE public.rule_executions
  ALTER COLUMN event_key SET NOT NULL;

DROP INDEX IF EXISTS public.rule_executions_rule_id_task_id_key;
DROP INDEX IF EXISTS public.rule_executions_rule_id_card_id_key;

CREATE UNIQUE INDEX IF NOT EXISTS rule_executions_rule_id_event_key_key
  ON public.rule_executions(rule_id, event_key);

ALTER TABLE public.rule_executions
  ADD CONSTRAINT rule_executions_template_id_fkey
  FOREIGN KEY (template_id) REFERENCES public.task_templates(id);

ALTER TABLE public.rule_executions
  ADD CONSTRAINT rule_executions_created_task_id_fkey
  FOREIGN KEY (created_task_id) REFERENCES public.tasks(id) ON DELETE SET NULL;

-- migrate:down

ALTER TABLE public.rule_executions
  DROP CONSTRAINT IF EXISTS rule_executions_created_task_id_fkey;

ALTER TABLE public.rule_executions
  DROP CONSTRAINT IF EXISTS rule_executions_template_id_fkey;

DROP INDEX IF EXISTS public.rule_executions_rule_id_event_key_key;

CREATE UNIQUE INDEX IF NOT EXISTS rule_executions_rule_id_task_id_key
  ON public.rule_executions(rule_id, task_id)
  WHERE task_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS rule_executions_rule_id_card_id_key
  ON public.rule_executions(rule_id, card_id)
  WHERE card_id IS NOT NULL;

ALTER TABLE public.rule_executions
  DROP COLUMN IF EXISTS event_key;

ALTER TABLE public.rule_executions
  DROP COLUMN IF EXISTS created_task_id,
  DROP COLUMN IF EXISTS template_version,
  DROP COLUMN IF EXISTS template_id;

ALTER TABLE public.task_templates
  DROP COLUMN IF EXISTS version;
