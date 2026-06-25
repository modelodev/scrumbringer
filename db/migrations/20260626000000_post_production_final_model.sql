-- migrate:up


DO $$
BEGIN
  IF to_regclass('public.milestones') IS NULL THEN
    RAISE EXCEPTION 'hierarchy_migration_already_applied';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'cards'
      AND column_name = 'parent_card_id'
  ) THEN
    RAISE EXCEPTION 'hierarchy_migration_already_applied';
  END IF;
END $$;

ALTER TABLE cards
  ADD COLUMN parent_card_id BIGINT,
  ADD COLUMN execution_state TEXT NOT NULL DEFAULT 'draft',
  ADD COLUMN activated_at TIMESTAMPTZ,
  ADD COLUMN activated_by BIGINT REFERENCES users(id),
  ADD COLUMN activation_source TEXT,
  ADD COLUMN activation_source_card_id BIGINT,
  ADD COLUMN closed_at TIMESTAMPTZ,
  ADD COLUMN closed_by BIGINT REFERENCES users(id),
  ADD COLUMN closed_by_kind TEXT,
  ADD COLUMN closed_reason TEXT,
  ADD COLUMN due_date DATE;

ALTER TABLE tasks
  ADD COLUMN execution_state TEXT,
  ADD COLUMN claimed_mode TEXT,
  ADD COLUMN closed_at TIMESTAMPTZ,
  ADD COLUMN closed_by BIGINT REFERENCES users(id),
  ADD COLUMN closed_reason TEXT,
  ADD COLUMN due_date DATE,
  ADD COLUMN capability_id BIGINT REFERENCES capabilities(id);

CREATE TABLE project_settings (
  project_id BIGINT PRIMARY KEY REFERENCES projects(id) ON DELETE CASCADE,
  healthy_pool_limit INT NOT NULL DEFAULT 20 CHECK (healthy_pool_limit > 0),
  version INT NOT NULL DEFAULT 1
);

CREATE TABLE project_card_depth_names (
  project_id BIGINT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  depth INT NOT NULL CHECK (depth > 0),
  singular_name TEXT NOT NULL,
  plural_name TEXT NOT NULL,
  PRIMARY KEY (project_id, depth)
);

INSERT INTO project_settings (project_id)
SELECT id
FROM projects
ON CONFLICT (project_id) DO NOTHING;

INSERT INTO project_card_depth_names
  (project_id, depth, singular_name, plural_name)
SELECT id, 1, 'Initiative', 'Initiatives'
FROM projects
ON CONFLICT (project_id, depth) DO NOTHING;

INSERT INTO project_card_depth_names
  (project_id, depth, singular_name, plural_name)
SELECT id, 2, 'Feature', 'Features'
FROM projects
ON CONFLICT (project_id, depth) DO NOTHING;

CREATE TEMP TABLE _hierarchy_milestone_cards (
  milestone_id BIGINT PRIMARY KEY,
  card_id BIGINT NOT NULL
) ON COMMIT DROP;

CREATE TEMP TABLE _hierarchy_grouping_cards (
  milestone_id BIGINT PRIMARY KEY,
  card_id BIGINT NOT NULL
) ON COMMIT DROP;

DO $$
DECLARE
  milestone_row RECORD;
  inserted_card_id BIGINT;
BEGIN
  FOR milestone_row IN
    SELECT *
    FROM milestones
    ORDER BY project_id, position, id
  LOOP
    INSERT INTO cards (
      project_id,
      parent_card_id,
      title,
      description,
      color,
      created_by,
      created_at,
      execution_state,
      activated_at,
      activated_by,
      activation_source,
      closed_at,
      closed_by_kind,
      closed_reason
    )
    VALUES (
      milestone_row.project_id,
      NULL,
      milestone_row.name,
      COALESCE(milestone_row.description, ''),
      NULL,
      milestone_row.created_by,
      milestone_row.created_at,
      CASE milestone_row.state
        WHEN 'ready' THEN 'draft'
        WHEN 'active' THEN 'active'
        WHEN 'completed' THEN 'closed'
        ELSE 'draft'
      END,
      CASE
        WHEN milestone_row.state IN ('active', 'completed') THEN
          COALESCE(milestone_row.activated_at, milestone_row.created_at)
        ELSE NULL
      END,
      CASE
        WHEN milestone_row.state IN ('active', 'completed') THEN
          milestone_row.created_by
        ELSE NULL
      END,
      CASE
        WHEN milestone_row.state IN ('active', 'completed') THEN
          'direct_activation'
        ELSE NULL
      END,
      CASE
        WHEN milestone_row.state = 'completed' THEN
          COALESCE(milestone_row.completed_at, NOW())
        ELSE NULL
      END,
      CASE
        WHEN milestone_row.state = 'completed' THEN 'system'
        ELSE NULL
      END,
      CASE
        WHEN milestone_row.state = 'completed' THEN 'rollup'
        ELSE NULL
      END
    )
    RETURNING id INTO inserted_card_id;

    INSERT INTO _hierarchy_milestone_cards (milestone_id, card_id)
    VALUES (milestone_row.id, inserted_card_id);
  END LOOP;
END $$;

UPDATE cards c
SET
  parent_card_id = map.card_id,
  execution_state = 'draft'
FROM _hierarchy_milestone_cards map
WHERE c.milestone_id = map.milestone_id;

DO $$
DECLARE
  milestone_row RECORD;
  inserted_card_id BIGINT;
BEGIN
  FOR milestone_row IN
    SELECT m.*
    FROM milestones m
    WHERE EXISTS (
      SELECT 1
      FROM cards c
      WHERE c.milestone_id = m.id
    )
    AND EXISTS (
      SELECT 1
      FROM tasks t
      WHERE t.milestone_id = m.id
        AND t.card_id IS NULL
    )
    ORDER BY m.project_id, m.position, m.id
  LOOP
    INSERT INTO cards (
      project_id,
      parent_card_id,
      title,
      description,
      created_by,
      created_at,
      execution_state
    )
    VALUES (
      milestone_row.project_id,
      (
        SELECT card_id
        FROM _hierarchy_milestone_cards
        WHERE milestone_id = milestone_row.id
      ),
      'Trabajo directo',
      '',
      milestone_row.created_by,
      NOW(),
      'draft'
    )
    RETURNING id INTO inserted_card_id;

    INSERT INTO _hierarchy_grouping_cards (milestone_id, card_id)
    VALUES (milestone_row.id, inserted_card_id);
  END LOOP;
END $$;

UPDATE tasks t
SET card_id = COALESCE(grouping.card_id, root_card.card_id)
FROM _hierarchy_milestone_cards root_card
LEFT JOIN _hierarchy_grouping_cards grouping
  ON grouping.milestone_id = root_card.milestone_id
WHERE t.card_id IS NULL
  AND t.milestone_id = root_card.milestone_id;

UPDATE tasks
SET
  execution_state = CASE status
    WHEN 'available' THEN 'available'
    WHEN 'claimed' THEN 'claimed'
    WHEN 'completed' THEN 'closed'
    ELSE 'available'
  END,
  claimed_mode = CASE
    WHEN status = 'claimed' THEN 'taken'
    ELSE NULL
  END,
  closed_at = CASE
    WHEN status = 'completed' THEN COALESCE(completed_at, NOW())
    ELSE NULL
  END,
  closed_by = CASE
    WHEN status = 'completed' THEN COALESCE(claimed_by, created_by)
    ELSE NULL
  END,
  closed_reason = CASE
    WHEN status = 'completed' THEN 'done'
    ELSE NULL
  END;

ALTER TABLE tasks
  ALTER COLUMN execution_state SET NOT NULL;

SELECT setval(
  'cards_id_seq',
  GREATEST((SELECT COALESCE(MAX(id), 1) FROM cards), 1),
  TRUE
);

DROP INDEX IF EXISTS idx_cards_milestone;
DROP INDEX IF EXISTS idx_cards_project_milestone;
DROP INDEX IF EXISTS idx_milestones_one_active;
DROP INDEX IF EXISTS idx_milestones_project;
DROP INDEX IF EXISTS idx_milestones_project_state_position;
DROP INDEX IF EXISTS idx_tasks_milestone;
DROP INDEX IF EXISTS idx_tasks_project_milestone_status;
DROP INDEX IF EXISTS idx_tasks_card_status;
DROP INDEX IF EXISTS idx_tasks_status;

ALTER TABLE tasks DROP CONSTRAINT IF EXISTS tasks_project_milestone_fk;
ALTER TABLE tasks DROP CONSTRAINT IF EXISTS task_milestone_exclusive;
ALTER TABLE tasks DROP CONSTRAINT IF EXISTS tasks_status_check;

ALTER TABLE cards DROP CONSTRAINT IF EXISTS cards_project_milestone_fk;

ALTER TABLE milestones DROP CONSTRAINT IF EXISTS milestones_project_id_id_unique;

ALTER TABLE cards
  DROP COLUMN milestone_id;

ALTER TABLE tasks
  DROP COLUMN milestone_id,
  DROP COLUMN status,
  DROP COLUMN completed_at;

DROP TABLE milestones;

CREATE INDEX idx_cards_parent_card ON cards(parent_card_id);
CREATE INDEX idx_cards_project_parent ON cards(project_id, parent_card_id);
CREATE INDEX idx_cards_project_execution_state ON cards(project_id, execution_state);
CREATE INDEX idx_tasks_project_execution_state ON tasks(project_id, execution_state);
CREATE INDEX idx_tasks_card_execution_state ON tasks(card_id, execution_state);

ALTER TABLE cards
  ADD CONSTRAINT cards_execution_state_check
  CHECK (execution_state IN ('draft', 'active', 'closed'));

ALTER TABLE cards
  ADD CONSTRAINT cards_activation_source_check
  CHECK (
    activation_source IS NULL
    OR activation_source IN ('direct_activation', 'activated_by_ancestor')
  );

ALTER TABLE cards
  ADD CONSTRAINT cards_closed_reason_check
  CHECK (
    closed_reason IS NULL
    OR closed_reason IN ('rollup', 'manually_closed')
  );

ALTER TABLE cards
  ADD CONSTRAINT cards_closed_by_kind_check
  CHECK (
    closed_by_kind IS NULL
    OR closed_by_kind IN ('user', 'system')
  );

ALTER TABLE tasks
  ADD CONSTRAINT tasks_execution_state_check
  CHECK (execution_state IN ('available', 'claimed', 'closed'));

ALTER TABLE tasks
  ADD CONSTRAINT tasks_claimed_mode_check
  CHECK (
    claimed_mode IS NULL
    OR claimed_mode IN ('taken', 'ongoing')
  );

ALTER TABLE tasks
  ADD CONSTRAINT tasks_closed_reason_check
  CHECK (
    closed_reason IS NULL
    OR closed_reason IN ('done', 'manually_closed', 'closed_by_ancestor')
  );

ALTER TABLE cards
  ADD CONSTRAINT cards_parent_card_fk
  FOREIGN KEY (project_id, parent_card_id)
  REFERENCES cards(project_id, id) NOT VALID;



ALTER TABLE tasks
  ADD COLUMN IF NOT EXISTS due_date DATE;
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
      'task_closed'
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
          'task_closed'
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



ALTER TABLE public.cards
  ADD COLUMN IF NOT EXISTS activation_source_card_id BIGINT;



ALTER TABLE public.cards
  ALTER COLUMN execution_state SET DEFAULT 'draft';

UPDATE public.cards
SET execution_state = 'draft'
WHERE execution_state IS NULL;

ALTER TABLE public.cards
  ALTER COLUMN execution_state SET NOT NULL;



INSERT INTO public.project_card_depth_names
  (project_id, depth, singular_name, plural_name)
SELECT
  p.id,
  names.depth,
  names.singular_name,
  names.plural_name
FROM public.projects p
CROSS JOIN (
  VALUES
    (1, 'Initiative', 'Initiatives'),
    (2, 'Feature', 'Features'),
    (3, 'Task group', 'Task groups')
) AS names(depth, singular_name, plural_name)
WHERE NOT EXISTS (
  SELECT 1
  FROM public.project_card_depth_names existing
  WHERE existing.project_id = p.id
    AND existing.depth = names.depth
)
ON CONFLICT (project_id, depth) DO NOTHING;



INSERT INTO public.task_types (project_id, name, icon)
SELECT
  project.id,
  task_type.name,
  task_type.icon
FROM public.projects project
CROSS JOIN (
  VALUES
    ('General', 'check-square')
) AS task_type(name, icon)
ON CONFLICT (name, project_id) DO NOTHING;



UPDATE public.tasks
SET status = CASE
  WHEN execution_state = 'closed' THEN 'completed'
  ELSE execution_state
END
WHERE status IS DISTINCT FROM CASE
  WHEN execution_state = 'closed' THEN 'completed'
  ELSE execution_state
END;



ALTER TABLE public.audit_events
  ADD COLUMN IF NOT EXISTS card_id BIGINT,
  ADD COLUMN IF NOT EXISTS payload_json JSONB NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE public.audit_events
  ALTER COLUMN task_id DROP NOT NULL;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.audit_events'::regclass
      AND conname = 'audit_events_event_type_check'
  ) THEN
    ALTER TABLE public.audit_events
      DROP CONSTRAINT audit_events_event_type_check;
  END IF;
END $$;

ALTER TABLE public.audit_events
  ADD CONSTRAINT audit_events_event_type_check CHECK (
    event_type IN (
      'task_created',
      'task_claimed',
      'task_released',
      'task_closed',
      'task_done',
      'card_activated',
      'card_closed'
    )
  );

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.audit_events'::regclass
      AND conname = 'audit_events_card_id_fkey'
  ) THEN
    ALTER TABLE public.audit_events
      ADD CONSTRAINT audit_events_card_id_fkey
      FOREIGN KEY (card_id) REFERENCES public.cards(id);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_audit_events_card_created_at
  ON public.audit_events(card_id, created_at);



UPDATE public.project_card_depth_names
SET singular_name = 'Initiative',
    plural_name = 'Initiatives'
WHERE depth = 1
  AND (
    (singular_name = 'Card' AND plural_name = 'Cards')
    OR (
      singular_name = 'Hito'
      AND plural_name = 'Hitos'
      AND EXISTS (
        SELECT 1
        FROM public.project_card_depth_names sibling
        WHERE sibling.project_id = project_card_depth_names.project_id
          AND sibling.depth = 2
          AND sibling.singular_name = 'Card'
          AND sibling.plural_name = 'Cards'
      )
    )
  );

UPDATE public.project_card_depth_names
SET singular_name = 'Feature',
    plural_name = 'Features'
WHERE depth = 2
  AND (
    (singular_name = 'Card' AND plural_name = 'Cards')
    OR (singular_name = 'Initiative' AND plural_name = 'Initiatives')
  );

INSERT INTO public.project_card_depth_names
  (project_id, depth, singular_name, plural_name)
SELECT
  project.id,
  names.depth,
  names.singular_name,
  names.plural_name
FROM public.projects project
CROSS JOIN (
  VALUES
    (1, 'Initiative', 'Initiatives'),
    (2, 'Feature', 'Features'),
    (3, 'Task group', 'Task groups')
) AS names(depth, singular_name, plural_name)
ON CONFLICT (project_id, depth) DO NOTHING;



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



CREATE OR REPLACE FUNCTION public.enforce_card_child_kind_invariant()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_TABLE_NAME = 'cards' AND NEW.parent_card_id IS NOT NULL THEN
    IF EXISTS (
      SELECT 1
      FROM public.tasks
      WHERE card_id = NEW.parent_card_id
    ) THEN
      RAISE EXCEPTION 'parent card % already contains tasks', NEW.parent_card_id
        USING ERRCODE = '23514';
    END IF;
  END IF;

  IF TG_TABLE_NAME = 'tasks' AND NEW.card_id IS NOT NULL THEN
    IF EXISTS (
      SELECT 1
      FROM public.cards
      WHERE parent_card_id = NEW.card_id
    ) THEN
      RAISE EXCEPTION 'card % already contains child cards', NEW.card_id
        USING ERRCODE = '23514';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_cards_child_kind_invariant
BEFORE INSERT OR UPDATE OF parent_card_id ON public.cards
FOR EACH ROW
EXECUTE FUNCTION public.enforce_card_child_kind_invariant();

CREATE TRIGGER trg_tasks_child_kind_invariant
BEFORE INSERT OR UPDATE OF card_id ON public.tasks
FOR EACH ROW
EXECUTE FUNCTION public.enforce_card_child_kind_invariant();



CREATE OR REPLACE FUNCTION public.enforce_card_child_kind_invariant()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_TABLE_NAME = 'cards' THEN
    IF NEW.parent_card_id IS NOT NULL THEN
      IF EXISTS (
        SELECT 1
        FROM public.tasks
        WHERE card_id = NEW.parent_card_id
      ) THEN
        RAISE EXCEPTION 'parent card % already contains tasks', NEW.parent_card_id
          USING ERRCODE = '23514';
      END IF;
    END IF;
  END IF;

  IF TG_TABLE_NAME = 'tasks' THEN
    IF NEW.card_id IS NOT NULL THEN
      IF EXISTS (
        SELECT 1
        FROM public.cards
        WHERE parent_card_id = NEW.card_id
      ) THEN
        RAISE EXCEPTION 'card % already contains child cards', NEW.card_id
          USING ERRCODE = '23514';
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;



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
WHERE event_type IN ('task_closed', 'task_done');

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
      'task_dependency_removed',
      'note_created',
      'note_pinned',
      'note_unpinned',
      'due_date_changed'
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
        'task_dependency_removed',
        'note_created',
        'note_pinned',
        'note_unpinned',
        'due_date_changed'
      )
      AND task_id IS NOT NULL
      AND card_id IS NULL
    )
    OR (
      event_type IN (
        'card_activated',
        'card_closed',
        'card_moved',
        'note_created',
        'note_pinned',
        'note_unpinned',
        'due_date_changed'
      )
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



ALTER TABLE card_notes RENAME TO card_notes_legacy;
ALTER INDEX IF EXISTS idx_card_notes_card RENAME TO idx_card_notes_legacy_card;

ALTER TABLE task_notes RENAME TO task_notes_legacy;
ALTER INDEX IF EXISTS idx_task_notes_task RENAME TO idx_task_notes_legacy_task;

CREATE TABLE notes (
  id BIGSERIAL PRIMARY KEY,
  project_id BIGINT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  user_id BIGINT NOT NULL REFERENCES users(id),
  content TEXT NOT NULL,
  url TEXT,
  pinned BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE card_notes (
  note_id BIGINT NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
  card_id BIGINT NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
  PRIMARY KEY (note_id, card_id)
);

CREATE TABLE task_notes (
  note_id BIGINT NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
  task_id BIGINT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  PRIMARY KEY (note_id, task_id)
);

CREATE INDEX idx_notes_project ON notes(project_id);
CREATE INDEX idx_notes_user ON notes(user_id);
CREATE INDEX idx_notes_pinned ON notes(project_id, pinned);
CREATE INDEX idx_card_notes_card ON card_notes(card_id);
CREATE INDEX idx_task_notes_task ON task_notes(task_id);

DO $$
DECLARE
  legacy_card_note RECORD;
  inserted_note_id BIGINT;
BEGIN
  FOR legacy_card_note IN
    SELECT cn.*, c.project_id
    FROM card_notes_legacy cn
    JOIN cards c ON c.id = cn.card_id
    ORDER BY cn.id
  LOOP
    INSERT INTO notes (
      project_id,
      user_id,
      content,
      url,
      pinned,
      created_at,
      updated_at
    )
    VALUES (
      legacy_card_note.project_id,
      legacy_card_note.user_id,
      legacy_card_note.content,
      NULL,
      FALSE,
      legacy_card_note.created_at,
      legacy_card_note.created_at
    )
    RETURNING id INTO inserted_note_id;

    INSERT INTO card_notes (note_id, card_id)
    VALUES (inserted_note_id, legacy_card_note.card_id);
  END LOOP;
END;
$$;

DO $$
DECLARE
  legacy_task_note RECORD;
  inserted_note_id BIGINT;
BEGIN
  FOR legacy_task_note IN
    SELECT tn.*, t.project_id
    FROM task_notes_legacy tn
    JOIN tasks t ON t.id = tn.task_id
    ORDER BY tn.id
  LOOP
    INSERT INTO notes (
      project_id,
      user_id,
      content,
      url,
      pinned,
      created_at,
      updated_at
    )
    VALUES (
      legacy_task_note.project_id,
      legacy_task_note.user_id,
      legacy_task_note.content,
      NULL,
      FALSE,
      legacy_task_note.created_at,
      legacy_task_note.created_at
    )
    RETURNING id INTO inserted_note_id;

    INSERT INTO task_notes (note_id, task_id)
    VALUES (inserted_note_id, legacy_task_note.task_id);
  END LOOP;
END;
$$;

DROP TABLE card_notes_legacy;
DROP TABLE task_notes_legacy;



ALTER TABLE public.audit_events
  DROP CONSTRAINT IF EXISTS audit_events_event_type_check,
  DROP CONSTRAINT IF EXISTS audit_events_target_check;

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
      'task_dependency_removed',
      'note_created',
      'note_pinned',
      'note_unpinned'
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
        'task_dependency_removed',
        'note_created',
        'note_pinned',
        'note_unpinned'
      )
      AND task_id IS NOT NULL
      AND card_id IS NULL
    )
    OR (
      event_type IN (
        'card_activated',
        'card_closed',
        'card_moved',
        'note_created',
        'note_pinned',
        'note_unpinned'
      )
      AND card_id IS NOT NULL
      AND task_id IS NULL
    )
  );



ALTER TABLE public.audit_events
  DROP CONSTRAINT IF EXISTS audit_events_event_type_check,
  DROP CONSTRAINT IF EXISTS audit_events_target_check;

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
      'task_dependency_removed',
      'note_created',
      'note_pinned',
      'note_unpinned',
      'due_date_changed'
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
        'task_dependency_removed',
        'note_created',
        'note_pinned',
        'note_unpinned',
        'due_date_changed'
      )
      AND task_id IS NOT NULL
      AND card_id IS NULL
    )
    OR (
      event_type IN (
        'card_activated',
        'card_closed',
        'card_moved',
        'note_created',
        'note_pinned',
        'note_unpinned',
        'due_date_changed'
      )
      AND card_id IS NOT NULL
      AND task_id IS NULL
    )
  );



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



ALTER TABLE public.rules
  ADD COLUMN IF NOT EXISTS trigger_kind TEXT;

UPDATE public.rules
SET trigger_kind = CASE
  WHEN resource_type = 'task' AND to_state = 'claimed' THEN 'task_claimed'
  WHEN resource_type = 'task' AND to_state = 'closed' THEN 'task_closed'
  WHEN resource_type = 'task' AND to_state = 'completed' THEN 'task_closed'
  WHEN resource_type = 'task' AND to_state = 'done' THEN 'task_closed'
  WHEN resource_type = 'task' AND to_state = 'available' THEN 'task_created'
  WHEN resource_type = 'card' AND to_state = 'en_curso' THEN 'card_activated'
  WHEN resource_type = 'card' AND to_state = 'cerrada' THEN 'card_closed'
  ELSE 'task_closed'
END
WHERE trigger_kind IS NULL OR trigger_kind = '';

UPDATE public.rules
SET to_state = 'closed'
WHERE resource_type = 'task'
  AND to_state IN ('completed', 'done');

UPDATE public.rules
SET active = false
WHERE resource_type = 'task'
  AND to_state = 'available';

UPDATE public.rules
SET active = false
WHERE resource_type NOT IN ('task', 'card')
  OR (
    resource_type = 'task'
    AND to_state NOT IN ('claimed', 'closed', 'done', 'available')
  )
  OR (
    resource_type = 'card'
    AND to_state NOT IN ('en_curso', 'cerrada')
  );

ALTER TABLE public.rules
  ALTER COLUMN trigger_kind SET NOT NULL;

ALTER TABLE public.rules
  ADD CONSTRAINT rules_trigger_kind_check
  CHECK (trigger_kind IN (
    'task_created',
    'task_claimed',
    'task_released',
    'task_closed',
    'card_activated',
    'card_closed'
  ));

CREATE INDEX IF NOT EXISTS idx_rules_trigger_kind
  ON public.rules(trigger_kind);



ALTER TABLE public.rules
  ADD COLUMN IF NOT EXISTS card_depth INT;

ALTER TABLE public.rules
  ADD CONSTRAINT rules_card_depth_check
  CHECK (card_depth IS NULL OR card_depth > 0);

CREATE INDEX IF NOT EXISTS idx_rules_card_depth
  ON public.rules(card_depth)
  WHERE card_depth IS NOT NULL;



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



CREATE TABLE automation_config_events (
  id BIGSERIAL PRIMARY KEY,
  org_id BIGINT NOT NULL REFERENCES organizations(id),
  project_id BIGINT NOT NULL REFERENCES projects(id),
  actor_user_id BIGINT NOT NULL REFERENCES users(id),
  entity_type TEXT NOT NULL CHECK (
    entity_type IN ('engine', 'rule', 'template')
  ),
  entity_id BIGINT NOT NULL,
  change_type TEXT NOT NULL CHECK (
    change_type IN (
      'created',
      'updated',
      'paused',
      'reactivated',
      'deleted',
      'archived'
    )
  ),
  payload_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_automation_config_events_project_created_at
  ON automation_config_events(project_id, created_at);

CREATE INDEX idx_automation_config_events_entity_created_at
  ON automation_config_events(entity_type, entity_id, created_at);

CREATE INDEX idx_automation_config_events_actor_created_at
  ON automation_config_events(actor_user_id, created_at);



WITH ranked_rule_templates AS (
  SELECT
    rule_id,
    template_id,
    row_number() OVER (
      PARTITION BY rule_id
      ORDER BY execution_order ASC, template_id ASC
    ) AS selected_rank
  FROM public.rule_templates
)
DELETE FROM public.rule_templates rt
USING ranked_rule_templates ranked
WHERE rt.rule_id = ranked.rule_id
  AND rt.template_id = ranked.template_id
  AND ranked.selected_rank > 1;

CREATE UNIQUE INDEX IF NOT EXISTS rule_templates_single_template_per_rule_key
  ON public.rule_templates(rule_id);



ALTER TABLE task_templates
ADD COLUMN archived_at TIMESTAMPTZ;

CREATE INDEX idx_task_templates_active_project
  ON task_templates(project_id, created_at DESC)
  WHERE archived_at IS NULL;
