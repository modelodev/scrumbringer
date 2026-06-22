-- migrate:up

--------------------------------------------------------------------------------
-- Canonical task state: execution_state is persisted, status is derived only.
--------------------------------------------------------------------------------

DROP INDEX IF EXISTS public.idx_tasks_card_status;
DROP INDEX IF EXISTS public.idx_tasks_status;

ALTER TABLE public.tasks
  DROP CONSTRAINT IF EXISTS tasks_status_check;

ALTER TABLE public.tasks
  DROP COLUMN IF EXISTS status;

--------------------------------------------------------------------------------
-- Validate final cross-project card/task FKs.
--------------------------------------------------------------------------------

DO $$
BEGIN
  ALTER TABLE public.cards
    DROP CONSTRAINT IF EXISTS cards_parent_card_id_fkey;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.cards'::regclass
      AND conname = 'cards_parent_card_fk'
  ) THEN
    ALTER TABLE public.cards
      ADD CONSTRAINT cards_parent_card_fk
        FOREIGN KEY (project_id, parent_card_id)
        REFERENCES public.cards(project_id, id)
        NOT VALID;
  END IF;
END;
$$;

ALTER TABLE public.cards
  VALIDATE CONSTRAINT cards_parent_card_fk;

ALTER TABLE public.tasks
  VALIDATE CONSTRAINT tasks_project_card_fk;

--------------------------------------------------------------------------------
-- Composite keys used by same-project foreign keys.
--------------------------------------------------------------------------------

ALTER TABLE public.capabilities
  ADD CONSTRAINT capabilities_project_id_id_unique UNIQUE (project_id, id);

ALTER TABLE public.task_types
  ADD CONSTRAINT task_types_project_id_id_unique UNIQUE (project_id, id);

ALTER TABLE public.tasks
  ADD CONSTRAINT tasks_project_id_id_unique UNIQUE (project_id, id);

ALTER TABLE public.workflows
  ADD CONSTRAINT workflows_project_id_id_unique UNIQUE (project_id, id);

ALTER TABLE public.tasks
  DROP CONSTRAINT IF EXISTS tasks_type_id_fkey,
  ADD CONSTRAINT tasks_project_type_fk
    FOREIGN KEY (project_id, type_id)
    REFERENCES public.task_types(project_id, id);

ALTER TABLE public.tasks
  DROP CONSTRAINT IF EXISTS tasks_capability_id_fkey,
  ADD CONSTRAINT tasks_project_capability_fk
    FOREIGN KEY (project_id, capability_id)
    REFERENCES public.capabilities(project_id, id);

ALTER TABLE public.task_types
  DROP CONSTRAINT IF EXISTS task_types_capability_id_fkey,
  ADD CONSTRAINT task_types_project_capability_fk
    FOREIGN KEY (project_id, capability_id)
    REFERENCES public.capabilities(project_id, id);

ALTER TABLE public.task_templates
  DROP CONSTRAINT IF EXISTS task_templates_type_id_fkey,
  ADD CONSTRAINT task_templates_project_type_fk
    FOREIGN KEY (project_id, type_id)
    REFERENCES public.task_types(project_id, id);

--------------------------------------------------------------------------------
-- Rules depend on workflow.project_id, so enforce task_type project via trigger.
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.rules_workflow_task_type_project_fk()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  workflow_project_id BIGINT;
BEGIN
  IF NEW.task_type_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT project_id
  INTO workflow_project_id
  FROM public.workflows
  WHERE id = NEW.workflow_id;

  IF workflow_project_id IS NULL THEN
    RAISE EXCEPTION 'workflow % does not exist', NEW.workflow_id
      USING ERRCODE = '23503';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.task_types
    WHERE id = NEW.task_type_id
      AND project_id = workflow_project_id
  ) THEN
    RAISE EXCEPTION 'task type % does not belong to workflow project %',
      NEW.task_type_id, workflow_project_id
      USING ERRCODE = '23503';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_rules_workflow_task_type_project_fk
BEFORE INSERT OR UPDATE OF workflow_id, task_type_id ON public.rules
FOR EACH ROW
EXECUTE FUNCTION public.rules_workflow_task_type_project_fk();

--------------------------------------------------------------------------------
-- Cards form a tree, not a graph.
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.prevent_card_cycle()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.parent_card_id IS NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.parent_card_id = NEW.id THEN
    RAISE EXCEPTION 'card % cannot be parent of itself', NEW.id
      USING ERRCODE = '23514';
  END IF;

  IF EXISTS (
    WITH RECURSIVE descendants(id) AS (
      SELECT id
      FROM public.cards
      WHERE parent_card_id = NEW.id
      UNION ALL
      SELECT child.id
      FROM public.cards child
      JOIN descendants d ON child.parent_card_id = d.id
    )
    SELECT 1
    FROM descendants
    WHERE id = NEW.parent_card_id
  ) THEN
    RAISE EXCEPTION 'card % cannot be moved below its descendant %',
      NEW.id, NEW.parent_card_id
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_cards_prevent_cycle
BEFORE INSERT OR UPDATE OF parent_card_id ON public.cards
FOR EACH ROW
EXECUTE FUNCTION public.prevent_card_cycle();

--------------------------------------------------------------------------------
-- Task dependencies are acyclic and same-project.
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.prevent_task_dependency_cycle()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  source_project_id BIGINT;
  dependency_project_id BIGINT;
BEGIN
  SELECT project_id
  INTO source_project_id
  FROM public.tasks
  WHERE id = NEW.task_id;

  SELECT project_id
  INTO dependency_project_id
  FROM public.tasks
  WHERE id = NEW.depends_on_task_id;

  IF source_project_id IS NULL OR dependency_project_id IS NULL THEN
    RAISE EXCEPTION 'dependency task does not exist'
      USING ERRCODE = '23503';
  END IF;

  IF source_project_id <> dependency_project_id THEN
    RAISE EXCEPTION 'task dependency must stay inside project %',
      source_project_id
      USING ERRCODE = '23503';
  END IF;

  IF EXISTS (
    WITH RECURSIVE dependency_chain(task_id) AS (
      SELECT depends_on_task_id
      FROM public.task_dependencies
      WHERE task_id = NEW.depends_on_task_id
      UNION ALL
      SELECT td.depends_on_task_id
      FROM public.task_dependencies td
      JOIN dependency_chain dc ON td.task_id = dc.task_id
    )
    SELECT 1
    FROM dependency_chain
    WHERE task_id = NEW.task_id
  ) THEN
    RAISE EXCEPTION 'task dependency cycle detected for task %', NEW.task_id
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_task_dependencies_prevent_cycle
BEFORE INSERT OR UPDATE OF task_id, depends_on_task_id ON public.task_dependencies
FOR EACH ROW
EXECUTE FUNCTION public.prevent_task_dependency_cycle();

--------------------------------------------------------------------------------
-- API tokens cannot point across organization boundaries.
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.enforce_api_token_org_scope()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.project_id IS NOT NULL AND NOT EXISTS (
    SELECT 1
    FROM public.projects
    WHERE id = NEW.project_id
      AND org_id = NEW.org_id
  ) THEN
    RAISE EXCEPTION 'api token project % does not belong to org %',
      NEW.project_id, NEW.org_id
      USING ERRCODE = '23503';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.users
    WHERE id = NEW.integration_user_id
      AND org_id = NEW.org_id
  ) THEN
    RAISE EXCEPTION 'api token integration user % does not belong to org %',
      NEW.integration_user_id, NEW.org_id
      USING ERRCODE = '23503';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.users
    WHERE id = NEW.created_by
      AND org_id = NEW.org_id
  ) THEN
    RAISE EXCEPTION 'api token creator % does not belong to org %',
      NEW.created_by, NEW.org_id
      USING ERRCODE = '23503';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_api_tokens_org_scope
BEFORE INSERT OR UPDATE OF org_id, project_id, integration_user_id, created_by
ON public.api_tokens
FOR EACH ROW
EXECUTE FUNCTION public.enforce_api_token_org_scope();

--------------------------------------------------------------------------------
-- Canonical audit event taxonomy and target integrity.
--------------------------------------------------------------------------------

ALTER TABLE public.audit_events
  DROP CONSTRAINT IF EXISTS audit_events_event_type_check;

UPDATE public.audit_events
SET
  event_type = 'task_closed',
  payload_json = payload_json || jsonb_build_object('closed_reason', 'done')
WHERE event_type IN ('task_completed', 'task_done');

ALTER TABLE public.audit_events
  ADD CONSTRAINT audit_events_event_type_check CHECK (
    event_type IN (
      'task_created',
      'task_claimed',
      'task_released',
      'task_closed',
      'card_activated',
      'card_closed',
      'card_moved',
      'task_dependency_added',
      'task_dependency_removed'
    )
  ),
  ADD CONSTRAINT audit_events_target_check CHECK (
    (
      event_type IN (
        'task_created',
        'task_claimed',
        'task_released',
        'task_closed',
        'task_dependency_added',
        'task_dependency_removed'
      )
      AND task_id IS NOT NULL
      AND card_id IS NULL
    )
    OR (
      event_type IN ('card_activated', 'card_closed', 'card_moved')
      AND card_id IS NOT NULL
      AND task_id IS NULL
    )
  );

ALTER TABLE public.audit_events
  DROP CONSTRAINT IF EXISTS audit_events_task_id_fkey,
  ADD CONSTRAINT audit_events_task_project_fk
    FOREIGN KEY (project_id, task_id)
    REFERENCES public.tasks(project_id, id);

ALTER TABLE public.audit_events
  DROP CONSTRAINT IF EXISTS audit_events_card_id_fkey,
  ADD CONSTRAINT audit_events_card_project_fk
    FOREIGN KEY (project_id, card_id)
    REFERENCES public.cards(project_id, id);

CREATE OR REPLACE FUNCTION public.enforce_audit_event_org_project()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.task_id IS NOT NULL AND NOT EXISTS (
    SELECT 1
    FROM public.tasks task
    JOIN public.projects project ON project.id = task.project_id
    WHERE task.id = NEW.task_id
      AND task.project_id = NEW.project_id
      AND project.org_id = NEW.org_id
  ) THEN
    RAISE EXCEPTION 'audit task target does not match event org/project'
      USING ERRCODE = '23503';
  END IF;

  IF NEW.card_id IS NOT NULL AND NOT EXISTS (
    SELECT 1
    FROM public.cards card
    JOIN public.projects project ON project.id = card.project_id
    WHERE card.id = NEW.card_id
      AND card.project_id = NEW.project_id
      AND project.org_id = NEW.org_id
  ) THEN
    RAISE EXCEPTION 'audit card target does not match event org/project'
      USING ERRCODE = '23503';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_audit_events_org_project
BEFORE INSERT OR UPDATE OF org_id, project_id, task_id, card_id ON public.audit_events
FOR EACH ROW
EXECUTE FUNCTION public.enforce_audit_event_org_project();

--------------------------------------------------------------------------------
-- Rule execution origin is explicit and FK-backed.
--------------------------------------------------------------------------------

ALTER TABLE public.rule_executions
  ADD COLUMN task_id BIGINT,
  ADD COLUMN card_id BIGINT;

UPDATE public.rule_executions
SET task_id = origin_id
WHERE origin_type = 'task';

UPDATE public.rule_executions
SET card_id = origin_id
WHERE origin_type = 'card';

DELETE FROM public.rule_executions re
WHERE (re.task_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.tasks WHERE id = re.task_id
  ))
   OR (re.card_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.cards WHERE id = re.card_id
  ));

DROP INDEX IF EXISTS public.idx_rule_executions_origin;

ALTER TABLE public.rule_executions
  DROP CONSTRAINT IF EXISTS rule_executions_rule_id_origin_type_origin_id_key,
  DROP CONSTRAINT IF EXISTS rule_executions_origin_type_check,
  DROP COLUMN origin_type,
  DROP COLUMN origin_id,
  ADD CONSTRAINT rule_executions_target_check CHECK (
    (task_id IS NOT NULL AND card_id IS NULL)
    OR (task_id IS NULL AND card_id IS NOT NULL)
  ),
  ADD CONSTRAINT rule_executions_task_id_fkey
    FOREIGN KEY (task_id)
    REFERENCES public.tasks(id)
    ON DELETE CASCADE,
  ADD CONSTRAINT rule_executions_card_id_fkey
    FOREIGN KEY (card_id)
    REFERENCES public.cards(id)
    ON DELETE CASCADE;

CREATE UNIQUE INDEX rule_executions_rule_id_task_id_key
  ON public.rule_executions(rule_id, task_id)
  WHERE task_id IS NOT NULL;

CREATE UNIQUE INDEX rule_executions_rule_id_card_id_key
  ON public.rule_executions(rule_id, card_id)
  WHERE card_id IS NOT NULL;

CREATE INDEX idx_rule_executions_task
  ON public.rule_executions(task_id)
  WHERE task_id IS NOT NULL;

CREATE INDEX idx_rule_executions_card
  ON public.rule_executions(card_id)
  WHERE card_id IS NOT NULL;

--------------------------------------------------------------------------------
-- Project settings version is a real write version.
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.project_settings_increment_version()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.version = OLD.version + 1;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_project_settings_increment_version
BEFORE UPDATE ON public.project_settings
FOR EACH ROW
EXECUTE FUNCTION public.project_settings_increment_version();

-- migrate:down

DO $$
BEGIN
  RAISE EXCEPTION 'canonical_data_model_final_is_irreversible';
END $$;
