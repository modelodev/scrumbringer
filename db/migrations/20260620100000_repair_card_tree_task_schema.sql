-- migrate:up

DO $$
BEGIN
  IF to_regclass('public.audit_events') IS NULL
    AND to_regclass('public.task_events') IS NOT NULL
  THEN
    ALTER TABLE public.task_events RENAME TO audit_events;
  END IF;
END $$;

DO $$
BEGIN
  IF to_regclass('public.audit_events_id_seq') IS NULL
    AND to_regclass('public.task_events_id_seq') IS NOT NULL
  THEN
    ALTER SEQUENCE public.task_events_id_seq RENAME TO audit_events_id_seq;
  END IF;
END $$;

CREATE SEQUENCE IF NOT EXISTS public.audit_events_id_seq;

CREATE TABLE IF NOT EXISTS public.audit_events (
  id BIGINT PRIMARY KEY DEFAULT nextval('public.audit_events_id_seq'::regclass),
  org_id BIGINT NOT NULL REFERENCES public.organizations(id),
  project_id BIGINT NOT NULL REFERENCES public.projects(id),
  task_id BIGINT NOT NULL REFERENCES public.tasks(id),
  actor_user_id BIGINT NOT NULL REFERENCES public.users(id),
  event_type TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT audit_events_event_type_check CHECK (
    event_type IN (
      'task_created',
      'task_claimed',
      'task_released',
      'task_completed'
    )
  )
);

ALTER TABLE public.audit_events
  ADD COLUMN IF NOT EXISTS org_id BIGINT,
  ADD COLUMN IF NOT EXISTS project_id BIGINT,
  ADD COLUMN IF NOT EXISTS task_id BIGINT,
  ADD COLUMN IF NOT EXISTS actor_user_id BIGINT,
  ADD COLUMN IF NOT EXISTS event_type TEXT,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

UPDATE public.audit_events
SET created_at = NOW()
WHERE created_at IS NULL;

ALTER TABLE public.audit_events
  ALTER COLUMN id SET DEFAULT nextval('public.audit_events_id_seq'::regclass),
  ALTER COLUMN created_at SET DEFAULT NOW();

ALTER SEQUENCE public.audit_events_id_seq OWNED BY public.audit_events.id;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.audit_events'::regclass
      AND conname = 'task_events_pkey'
  )
    AND NOT EXISTS (
      SELECT 1
      FROM pg_constraint
      WHERE conrelid = 'public.audit_events'::regclass
        AND conname = 'audit_events_pkey'
    )
  THEN
    ALTER TABLE public.audit_events
      RENAME CONSTRAINT task_events_pkey TO audit_events_pkey;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.audit_events'::regclass
      AND conname = 'task_events_event_type_check'
  )
    AND NOT EXISTS (
      SELECT 1
      FROM pg_constraint
      WHERE conrelid = 'public.audit_events'::regclass
        AND conname = 'audit_events_event_type_check'
    )
  THEN
    ALTER TABLE public.audit_events
      RENAME CONSTRAINT task_events_event_type_check TO audit_events_event_type_check;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.audit_events'::regclass
      AND conname = 'task_events_org_id_fkey'
  )
    AND NOT EXISTS (
      SELECT 1
      FROM pg_constraint
      WHERE conrelid = 'public.audit_events'::regclass
        AND conname = 'audit_events_org_id_fkey'
    )
  THEN
    ALTER TABLE public.audit_events
      RENAME CONSTRAINT task_events_org_id_fkey TO audit_events_org_id_fkey;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.audit_events'::regclass
      AND conname = 'task_events_project_id_fkey'
  )
    AND NOT EXISTS (
      SELECT 1
      FROM pg_constraint
      WHERE conrelid = 'public.audit_events'::regclass
        AND conname = 'audit_events_project_id_fkey'
    )
  THEN
    ALTER TABLE public.audit_events
      RENAME CONSTRAINT task_events_project_id_fkey TO audit_events_project_id_fkey;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.audit_events'::regclass
      AND conname = 'task_events_task_id_fkey'
  )
    AND NOT EXISTS (
      SELECT 1
      FROM pg_constraint
      WHERE conrelid = 'public.audit_events'::regclass
        AND conname = 'audit_events_task_id_fkey'
    )
  THEN
    ALTER TABLE public.audit_events
      RENAME CONSTRAINT task_events_task_id_fkey TO audit_events_task_id_fkey;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.audit_events'::regclass
      AND conname = 'task_events_actor_user_id_fkey'
  )
    AND NOT EXISTS (
      SELECT 1
      FROM pg_constraint
      WHERE conrelid = 'public.audit_events'::regclass
        AND conname = 'audit_events_actor_user_id_fkey'
    )
  THEN
    ALTER TABLE public.audit_events
      RENAME CONSTRAINT task_events_actor_user_id_fkey TO audit_events_actor_user_id_fkey;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.audit_events'::regclass
      AND conname = 'audit_events_pkey'
  ) THEN
    ALTER TABLE public.audit_events
      ADD CONSTRAINT audit_events_pkey PRIMARY KEY (id);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.audit_events'::regclass
      AND conname = 'audit_events_event_type_check'
  ) THEN
    ALTER TABLE public.audit_events
      ADD CONSTRAINT audit_events_event_type_check CHECK (
        event_type IN (
          'task_created',
          'task_claimed',
          'task_released',
          'task_completed'
        )
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.audit_events'::regclass
      AND conname = 'audit_events_org_id_fkey'
  ) THEN
    ALTER TABLE public.audit_events
      ADD CONSTRAINT audit_events_org_id_fkey
      FOREIGN KEY (org_id) REFERENCES public.organizations(id);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.audit_events'::regclass
      AND conname = 'audit_events_project_id_fkey'
  ) THEN
    ALTER TABLE public.audit_events
      ADD CONSTRAINT audit_events_project_id_fkey
      FOREIGN KEY (project_id) REFERENCES public.projects(id);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.audit_events'::regclass
      AND conname = 'audit_events_task_id_fkey'
  ) THEN
    ALTER TABLE public.audit_events
      ADD CONSTRAINT audit_events_task_id_fkey
      FOREIGN KEY (task_id) REFERENCES public.tasks(id);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.audit_events'::regclass
      AND conname = 'audit_events_actor_user_id_fkey'
  ) THEN
    ALTER TABLE public.audit_events
      ADD CONSTRAINT audit_events_actor_user_id_fkey
      FOREIGN KEY (actor_user_id) REFERENCES public.users(id);
  END IF;
END $$;

DO $$
BEGIN
  IF to_regclass('public.idx_audit_events_org_created_at') IS NULL
    AND to_regclass('public.idx_task_events_org_created_at') IS NOT NULL
  THEN
    ALTER INDEX public.idx_task_events_org_created_at
      RENAME TO idx_audit_events_org_created_at;
  END IF;

  IF to_regclass('public.idx_audit_events_project_created_at') IS NULL
    AND to_regclass('public.idx_task_events_project_created_at') IS NOT NULL
  THEN
    ALTER INDEX public.idx_task_events_project_created_at
      RENAME TO idx_audit_events_project_created_at;
  END IF;

  IF to_regclass('public.idx_audit_events_actor_created_at') IS NULL
    AND to_regclass('public.idx_task_events_actor_created_at') IS NOT NULL
  THEN
    ALTER INDEX public.idx_task_events_actor_created_at
      RENAME TO idx_audit_events_actor_created_at;
  END IF;

  IF to_regclass('public.idx_audit_events_task_created_at') IS NULL
    AND to_regclass('public.idx_task_events_task_created_at') IS NOT NULL
  THEN
    ALTER INDEX public.idx_task_events_task_created_at
      RENAME TO idx_audit_events_task_created_at;
  END IF;
END $$;

DO $$
BEGIN
  IF to_regclass('public.task_events') IS NOT NULL THEN
    EXECUTE $sql$
      INSERT INTO public.audit_events (
        id,
        org_id,
        project_id,
        task_id,
        actor_user_id,
        event_type,
        created_at
      )
      SELECT
        id,
        org_id,
        project_id,
        task_id,
        actor_user_id,
        event_type,
        created_at
      FROM public.task_events
      ON CONFLICT (id) DO NOTHING
    $sql$;

    EXECUTE 'DROP TABLE public.task_events';
  END IF;
END $$;

DROP SEQUENCE IF EXISTS public.task_events_id_seq;

CREATE INDEX IF NOT EXISTS idx_audit_events_org_created_at
  ON public.audit_events(org_id, created_at);
CREATE INDEX IF NOT EXISTS idx_audit_events_project_created_at
  ON public.audit_events(project_id, created_at);
CREATE INDEX IF NOT EXISTS idx_audit_events_actor_created_at
  ON public.audit_events(actor_user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_audit_events_task_created_at
  ON public.audit_events(task_id, created_at);

DO $$
DECLARE
  max_id BIGINT;
BEGIN
  SELECT COALESCE(MAX(id), 0)
  INTO max_id
  FROM public.audit_events;

  PERFORM setval(
    'public.audit_events_id_seq'::regclass,
    GREATEST(max_id, 1),
    max_id > 0
  );
END $$;

ALTER TABLE public.cards
  ADD COLUMN IF NOT EXISTS parent_card_id BIGINT,
  ADD COLUMN IF NOT EXISTS execution_state TEXT,
  ADD COLUMN IF NOT EXISTS activated_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS activated_by BIGINT,
  ADD COLUMN IF NOT EXISTS activation_source TEXT,
  ADD COLUMN IF NOT EXISTS activation_source_card_id BIGINT,
  ADD COLUMN IF NOT EXISTS closed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS closed_by BIGINT,
  ADD COLUMN IF NOT EXISTS closed_by_kind TEXT,
  ADD COLUMN IF NOT EXISTS closed_reason TEXT,
  ADD COLUMN IF NOT EXISTS due_date DATE,
  ADD COLUMN IF NOT EXISTS color TEXT;

UPDATE public.cards
SET execution_state = 'draft'
WHERE execution_state IS NULL;

ALTER TABLE public.cards
  ALTER COLUMN execution_state SET DEFAULT 'draft',
  ALTER COLUMN execution_state SET NOT NULL;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.cards'::regclass
      AND conname = 'cards_execution_state_check'
      AND pg_get_constraintdef(oid) NOT LIKE '%draft%'
  ) THEN
    ALTER TABLE public.cards DROP CONSTRAINT cards_execution_state_check;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.cards'::regclass
      AND conname = 'cards_activation_source_check'
      AND pg_get_constraintdef(oid) NOT LIKE '%activated_by_ancestor%'
  ) THEN
    ALTER TABLE public.cards DROP CONSTRAINT cards_activation_source_check;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.cards'::regclass
      AND conname = 'cards_closed_reason_check'
      AND (
        pg_get_constraintdef(oid) NOT LIKE '%rollup%'
        OR pg_get_constraintdef(oid) NOT LIKE '%manually_closed%'
      )
  ) THEN
    ALTER TABLE public.cards DROP CONSTRAINT cards_closed_reason_check;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.cards'::regclass
      AND conname = 'cards_closed_by_kind_check'
      AND (
        pg_get_constraintdef(oid) NOT LIKE '%user%'
        OR pg_get_constraintdef(oid) NOT LIKE '%system%'
      )
  ) THEN
    ALTER TABLE public.cards DROP CONSTRAINT cards_closed_by_kind_check;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.cards'::regclass
      AND conname = 'cards_project_id_id_unique'
  ) THEN
    ALTER TABLE public.cards
      ADD CONSTRAINT cards_project_id_id_unique UNIQUE (project_id, id);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.cards'::regclass
      AND conname = 'cards_parent_card_fk'
  ) THEN
    ALTER TABLE public.cards
      ADD CONSTRAINT cards_parent_card_fk
      FOREIGN KEY (project_id, parent_card_id)
      REFERENCES public.cards(project_id, id) NOT VALID;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.cards'::regclass
      AND conname = 'cards_execution_state_check'
  ) THEN
    ALTER TABLE public.cards
      ADD CONSTRAINT cards_execution_state_check
      CHECK (execution_state IN ('draft', 'active', 'closed'));
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.cards'::regclass
      AND conname = 'cards_activation_source_check'
  ) THEN
    ALTER TABLE public.cards
      ADD CONSTRAINT cards_activation_source_check
      CHECK (
        activation_source IS NULL
        OR activation_source IN ('direct_activation', 'activated_by_ancestor')
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.cards'::regclass
      AND conname = 'cards_closed_reason_check'
  ) THEN
    ALTER TABLE public.cards
      ADD CONSTRAINT cards_closed_reason_check
      CHECK (
        closed_reason IS NULL
        OR closed_reason IN ('rollup', 'manually_closed')
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.cards'::regclass
      AND conname = 'cards_closed_by_kind_check'
  ) THEN
    ALTER TABLE public.cards
      ADD CONSTRAINT cards_closed_by_kind_check
      CHECK (
        closed_by_kind IS NULL
        OR closed_by_kind IN ('user', 'system')
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.cards'::regclass
      AND conname = 'cards_activated_by_fkey'
  ) THEN
    ALTER TABLE public.cards
      ADD CONSTRAINT cards_activated_by_fkey
      FOREIGN KEY (activated_by) REFERENCES public.users(id);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.cards'::regclass
      AND conname = 'cards_closed_by_fkey'
  ) THEN
    ALTER TABLE public.cards
      ADD CONSTRAINT cards_closed_by_fkey
      FOREIGN KEY (closed_by) REFERENCES public.users(id);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_cards_parent_card
  ON public.cards(parent_card_id);
CREATE INDEX IF NOT EXISTS idx_cards_project_parent
  ON public.cards(project_id, parent_card_id);
CREATE INDEX IF NOT EXISTS idx_cards_project_execution_state
  ON public.cards(project_id, execution_state);

ALTER TABLE public.tasks
  ADD COLUMN IF NOT EXISTS execution_state TEXT,
  ADD COLUMN IF NOT EXISTS status TEXT,
  ADD COLUMN IF NOT EXISTS card_id BIGINT,
  ADD COLUMN IF NOT EXISTS claimed_mode TEXT,
  ADD COLUMN IF NOT EXISTS closed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS closed_by BIGINT,
  ADD COLUMN IF NOT EXISTS closed_reason TEXT,
  ADD COLUMN IF NOT EXISTS due_date DATE,
  ADD COLUMN IF NOT EXISTS capability_id BIGINT,
  ADD COLUMN IF NOT EXISTS pool_lifetime_s BIGINT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_entered_pool_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS created_from_rule_id BIGINT;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'tasks'
      AND column_name = 'status'
  ) THEN
    EXECUTE $sql$
      UPDATE public.tasks
      SET execution_state = CASE status
        WHEN 'available' THEN 'available'
        WHEN 'claimed' THEN 'claimed'
        WHEN 'completed' THEN 'closed'
        ELSE 'available'
      END
      WHERE execution_state IS NULL
    $sql$;
  ELSE
    UPDATE public.tasks
    SET execution_state = 'available'
    WHERE execution_state IS NULL;
  END IF;
END $$;

UPDATE public.tasks
SET status = CASE
  WHEN execution_state = 'closed' THEN 'completed'
  ELSE execution_state
END
WHERE status IS NULL
  OR status IS DISTINCT FROM CASE
    WHEN execution_state = 'closed' THEN 'completed'
    ELSE execution_state
  END;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'tasks'
      AND column_name = 'status'
  ) THEN
    EXECUTE $sql$
      UPDATE public.tasks
      SET claimed_mode = 'taken'
      WHERE execution_state = 'claimed'
        AND claimed_mode IS NULL
    $sql$;
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'tasks'
      AND column_name = 'completed_at'
  ) THEN
    EXECUTE $sql$
      UPDATE public.tasks
      SET closed_at = COALESCE(completed_at, NOW())
      WHERE execution_state = 'closed'
        AND closed_at IS NULL
    $sql$;
  ELSE
    UPDATE public.tasks
    SET closed_at = NOW()
    WHERE execution_state = 'closed'
      AND closed_at IS NULL;
  END IF;
END $$;

UPDATE public.tasks
SET closed_by = COALESCE(claimed_by, created_by)
WHERE execution_state = 'closed'
  AND closed_by IS NULL;

UPDATE public.tasks
SET closed_reason = 'done'
WHERE execution_state = 'closed'
  AND closed_reason IS NULL;

UPDATE public.tasks
SET last_entered_pool_at = CASE
  WHEN execution_state = 'available' THEN created_at
  ELSE NULL
END
WHERE last_entered_pool_at IS NULL;

UPDATE public.tasks task
SET capability_id = task_type.capability_id
FROM public.task_types task_type
WHERE task.type_id = task_type.id
  AND task.capability_id IS NULL
  AND task_type.capability_id IS NOT NULL;

UPDATE public.tasks
SET pool_lifetime_s = 0
WHERE pool_lifetime_s IS NULL;

ALTER TABLE public.tasks
  ALTER COLUMN execution_state SET NOT NULL,
  ALTER COLUMN status SET DEFAULT 'available',
  ALTER COLUMN status SET NOT NULL,
  ALTER COLUMN pool_lifetime_s SET DEFAULT 0,
  ALTER COLUMN pool_lifetime_s SET NOT NULL;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.tasks'::regclass
      AND conname = 'tasks_execution_state_check'
      AND pg_get_constraintdef(oid) NOT LIKE '%available%'
  ) THEN
    ALTER TABLE public.tasks DROP CONSTRAINT tasks_execution_state_check;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.tasks'::regclass
      AND conname = 'tasks_status_check'
      AND pg_get_constraintdef(oid) NOT LIKE '%completed%'
  ) THEN
    ALTER TABLE public.tasks DROP CONSTRAINT tasks_status_check;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.tasks'::regclass
      AND conname = 'tasks_claimed_mode_check'
      AND (
        pg_get_constraintdef(oid) NOT LIKE '%taken%'
        OR pg_get_constraintdef(oid) NOT LIKE '%ongoing%'
      )
  ) THEN
    ALTER TABLE public.tasks DROP CONSTRAINT tasks_claimed_mode_check;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.tasks'::regclass
      AND conname = 'tasks_closed_reason_check'
      AND (
        pg_get_constraintdef(oid) NOT LIKE '%done%'
        OR pg_get_constraintdef(oid) NOT LIKE '%manually_closed%'
        OR pg_get_constraintdef(oid) NOT LIKE '%closed_by_ancestor%'
      )
  ) THEN
    ALTER TABLE public.tasks DROP CONSTRAINT tasks_closed_reason_check;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.tasks'::regclass
      AND conname = 'tasks_pool_lifetime_non_negative'
      AND pg_get_constraintdef(oid) NOT LIKE '%pool_lifetime_s >= 0%'
  ) THEN
    ALTER TABLE public.tasks DROP CONSTRAINT tasks_pool_lifetime_non_negative;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.tasks'::regclass
      AND conname = 'tasks_execution_state_check'
  ) THEN
    ALTER TABLE public.tasks
      ADD CONSTRAINT tasks_execution_state_check
      CHECK (execution_state IN ('available', 'claimed', 'closed'));
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.tasks'::regclass
      AND conname = 'tasks_status_check'
  ) THEN
    ALTER TABLE public.tasks
      ADD CONSTRAINT tasks_status_check
      CHECK (status IN ('available', 'claimed', 'completed'));
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.tasks'::regclass
      AND conname = 'tasks_claimed_mode_check'
  ) THEN
    ALTER TABLE public.tasks
      ADD CONSTRAINT tasks_claimed_mode_check
      CHECK (
        claimed_mode IS NULL
        OR claimed_mode IN ('taken', 'ongoing')
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.tasks'::regclass
      AND conname = 'tasks_closed_reason_check'
  ) THEN
    ALTER TABLE public.tasks
      ADD CONSTRAINT tasks_closed_reason_check
      CHECK (
        closed_reason IS NULL
        OR closed_reason IN ('done', 'manually_closed', 'closed_by_ancestor')
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.tasks'::regclass
      AND conname = 'tasks_closed_by_fkey'
  ) THEN
    ALTER TABLE public.tasks
      ADD CONSTRAINT tasks_closed_by_fkey
      FOREIGN KEY (closed_by) REFERENCES public.users(id);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.tasks'::regclass
      AND conname = 'tasks_capability_id_fkey'
  ) THEN
    ALTER TABLE public.tasks
      ADD CONSTRAINT tasks_capability_id_fkey
      FOREIGN KEY (capability_id) REFERENCES public.capabilities(id);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.tasks'::regclass
      AND conname = 'tasks_project_card_fk'
  ) THEN
    ALTER TABLE public.tasks
      ADD CONSTRAINT tasks_project_card_fk
      FOREIGN KEY (project_id, card_id) REFERENCES public.cards(project_id, id)
      NOT VALID;
  END IF;

  IF to_regclass('public.rules') IS NOT NULL
    AND NOT EXISTS (
      SELECT 1
      FROM pg_constraint
      WHERE conrelid = 'public.tasks'::regclass
        AND conname = 'tasks_created_from_rule_id_fkey'
    )
  THEN
    ALTER TABLE public.tasks
      ADD CONSTRAINT tasks_created_from_rule_id_fkey
      FOREIGN KEY (created_from_rule_id) REFERENCES public.rules(id)
      ON DELETE SET NULL;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.tasks'::regclass
      AND conname = 'tasks_pool_lifetime_non_negative'
  ) THEN
    ALTER TABLE public.tasks
      ADD CONSTRAINT tasks_pool_lifetime_non_negative
      CHECK (pool_lifetime_s >= 0);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_tasks_project_execution_state
  ON public.tasks(project_id, execution_state);
CREATE INDEX IF NOT EXISTS idx_tasks_card_execution_state
  ON public.tasks(card_id, execution_state);
CREATE INDEX IF NOT EXISTS idx_tasks_status
  ON public.tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_card_status
  ON public.tasks(card_id, status);
CREATE INDEX IF NOT EXISTS idx_tasks_created_from_rule
  ON public.tasks(created_from_rule_id);

CREATE TABLE IF NOT EXISTS public.project_settings (
  project_id BIGINT PRIMARY KEY REFERENCES public.projects(id) ON DELETE CASCADE,
  healthy_pool_limit INT NOT NULL DEFAULT 20,
  version INT NOT NULL DEFAULT 1,
  CONSTRAINT project_settings_healthy_pool_limit_check
    CHECK (healthy_pool_limit > 0)
);

ALTER TABLE public.project_settings
  ADD COLUMN IF NOT EXISTS healthy_pool_limit INT NOT NULL DEFAULT 20,
  ADD COLUMN IF NOT EXISTS version INT NOT NULL DEFAULT 1;

UPDATE public.project_settings
SET healthy_pool_limit = 20
WHERE healthy_pool_limit IS NULL
   OR healthy_pool_limit <= 0;

UPDATE public.project_settings
SET version = 1
WHERE version IS NULL;

ALTER TABLE public.project_settings
  ALTER COLUMN healthy_pool_limit SET DEFAULT 20,
  ALTER COLUMN healthy_pool_limit SET NOT NULL,
  ALTER COLUMN version SET DEFAULT 1,
  ALTER COLUMN version SET NOT NULL;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.project_settings'::regclass
      AND conname = 'project_settings_healthy_pool_limit_check'
      AND pg_get_constraintdef(oid) NOT LIKE '%healthy_pool_limit > 0%'
  ) THEN
    ALTER TABLE public.project_settings
      DROP CONSTRAINT project_settings_healthy_pool_limit_check;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.project_settings'::regclass
      AND conname = 'project_settings_project_id_fkey'
  ) THEN
    ALTER TABLE public.project_settings
      ADD CONSTRAINT project_settings_project_id_fkey
      FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.project_settings'::regclass
      AND conname = 'project_settings_healthy_pool_limit_check'
  ) THEN
    ALTER TABLE public.project_settings
      ADD CONSTRAINT project_settings_healthy_pool_limit_check
      CHECK (healthy_pool_limit > 0);
  END IF;
END $$;

INSERT INTO public.project_settings (project_id)
SELECT id
FROM public.projects
ON CONFLICT (project_id) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.project_card_depth_names (
  project_id BIGINT NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  depth INT NOT NULL CHECK (depth > 0),
  singular_name TEXT NOT NULL,
  plural_name TEXT NOT NULL,
  PRIMARY KEY (project_id, depth)
);

INSERT INTO public.project_card_depth_names
  (project_id, depth, singular_name, plural_name)
SELECT id, 1, 'Initiative', 'Initiatives'
FROM public.projects
ON CONFLICT (project_id, depth) DO NOTHING;

INSERT INTO public.project_card_depth_names
  (project_id, depth, singular_name, plural_name)
SELECT id, 2, 'Feature', 'Features'
FROM public.projects
ON CONFLICT (project_id, depth) DO NOTHING;

-- migrate:down

DO $$
BEGIN
  RAISE EXCEPTION 'repair_card_tree_task_schema_is_irreversible';
END $$;
