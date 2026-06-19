-- migrate:up

DO $$
BEGIN
  IF to_regclass('public.milestones') IS NULL THEN
    RAISE EXCEPTION 'card_tree_migration_already_applied';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'cards'
      AND column_name = 'parent_card_id'
  ) THEN
    RAISE EXCEPTION 'card_tree_migration_already_applied';
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

CREATE TABLE card_tree_migration_report (
  id BIGSERIAL PRIMARY KEY,
  severity TEXT NOT NULL CHECK (severity IN ('info', 'warning')),
  legacy_kind TEXT NOT NULL,
  legacy_id BIGINT NOT NULL,
  message TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO project_settings (project_id)
SELECT id
FROM projects
ON CONFLICT (project_id) DO NOTHING;

INSERT INTO project_card_depth_names
  (project_id, depth, singular_name, plural_name)
SELECT id, 1, 'Hito', 'Hitos'
FROM projects
ON CONFLICT (project_id, depth) DO NOTHING;

INSERT INTO project_card_depth_names
  (project_id, depth, singular_name, plural_name)
SELECT id, 2, 'Card', 'Cards'
FROM projects
ON CONFLICT (project_id, depth) DO NOTHING;

INSERT INTO card_tree_migration_report
  (severity, legacy_kind, legacy_id, message)
SELECT
  'warning',
  'milestone',
  id,
  'completed milestone missing activated_at or completed_at'
FROM milestones
WHERE state = 'completed'
  AND (activated_at IS NULL OR completed_at IS NULL);

CREATE TEMP TABLE _card_tree_milestone_cards (
  milestone_id BIGINT PRIMARY KEY,
  card_id BIGINT NOT NULL
) ON COMMIT DROP;

CREATE TEMP TABLE _card_tree_grouping_cards (
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

    INSERT INTO _card_tree_milestone_cards (milestone_id, card_id)
    VALUES (milestone_row.id, inserted_card_id);
  END LOOP;
END $$;

UPDATE cards c
SET
  parent_card_id = map.card_id,
  execution_state = 'draft'
FROM _card_tree_milestone_cards map
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
        FROM _card_tree_milestone_cards
        WHERE milestone_id = milestone_row.id
      ),
      'Trabajo directo',
      '',
      milestone_row.created_by,
      NOW(),
      'draft'
    )
    RETURNING id INTO inserted_card_id;

    INSERT INTO _card_tree_grouping_cards (milestone_id, card_id)
    VALUES (milestone_row.id, inserted_card_id);

    INSERT INTO card_tree_migration_report
      (severity, legacy_kind, legacy_id, message)
    VALUES (
      'info',
      'milestone',
      milestone_row.id,
      'created grouping card Trabajo directo for direct milestone tasks'
    );
  END LOOP;
END $$;

UPDATE tasks t
SET card_id = COALESCE(grouping.card_id, root_card.card_id)
FROM _card_tree_milestone_cards root_card
LEFT JOIN _card_tree_grouping_cards grouping
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

-- migrate:down

DO $$
BEGIN
  RAISE EXCEPTION 'card_tree_task_leaves_migration_is_irreversible';
END $$;
