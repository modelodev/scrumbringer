-- migrate:up

ALTER TABLE public.rule_executions
  DROP CONSTRAINT IF EXISTS rule_executions_rule_id_fkey,
  ADD CONSTRAINT rule_executions_rule_id_fkey
    FOREIGN KEY (rule_id)
    REFERENCES public.rules(id)
    ON DELETE RESTRICT;

ALTER TABLE public.tasks
  DROP CONSTRAINT IF EXISTS tasks_created_from_rule_id_fkey,
  ADD CONSTRAINT tasks_created_from_rule_id_fkey
    FOREIGN KEY (created_from_rule_id)
    REFERENCES public.rules(id)
    ON DELETE RESTRICT;

-- migrate:down

ALTER TABLE public.tasks
  DROP CONSTRAINT IF EXISTS tasks_created_from_rule_id_fkey,
  ADD CONSTRAINT tasks_created_from_rule_id_fkey
    FOREIGN KEY (created_from_rule_id)
    REFERENCES public.rules(id)
    ON DELETE SET NULL;

ALTER TABLE public.rule_executions
  DROP CONSTRAINT IF EXISTS rule_executions_rule_id_fkey,
  ADD CONSTRAINT rule_executions_rule_id_fkey
    FOREIGN KEY (rule_id)
    REFERENCES public.rules(id)
    ON DELETE CASCADE;
