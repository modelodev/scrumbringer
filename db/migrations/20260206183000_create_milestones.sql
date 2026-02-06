-- migrate:up

CREATE TABLE milestones (
  id BIGSERIAL PRIMARY KEY,
  project_id BIGINT NOT NULL REFERENCES projects(id),
  name TEXT NOT NULL,
  description TEXT,
  state TEXT NOT NULL DEFAULT 'ready' CHECK (state IN ('ready', 'active', 'completed')),
  position INT NOT NULL DEFAULT 0,
  created_by BIGINT NOT NULL REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  activated_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  CONSTRAINT milestones_state_activation_consistency
    CHECK (
      (state = 'ready' AND activated_at IS NULL AND completed_at IS NULL)
      OR (state = 'active' AND activated_at IS NOT NULL AND completed_at IS NULL)
      OR (state = 'completed' AND activated_at IS NOT NULL AND completed_at IS NOT NULL)
    )
);

CREATE INDEX idx_milestones_project ON milestones(project_id);
CREATE INDEX idx_milestones_project_state_position ON milestones(project_id, state, position);
CREATE UNIQUE INDEX idx_milestones_one_active ON milestones(project_id) WHERE state = 'active';

ALTER TABLE milestones
  ADD CONSTRAINT milestones_project_id_id_unique UNIQUE (project_id, id);

ALTER TABLE cards
  ADD COLUMN milestone_id BIGINT;

CREATE INDEX idx_cards_milestone ON cards(milestone_id);
CREATE INDEX idx_cards_project_milestone ON cards(project_id, milestone_id);

ALTER TABLE cards
  ADD CONSTRAINT cards_project_id_id_unique UNIQUE (project_id, id);

ALTER TABLE cards
  ADD CONSTRAINT cards_project_milestone_fk
  FOREIGN KEY (project_id, milestone_id) REFERENCES milestones(project_id, id) NOT VALID;

ALTER TABLE tasks
  ADD COLUMN milestone_id BIGINT,
  ADD COLUMN pool_lifetime_s BIGINT NOT NULL DEFAULT 0,
  ADD COLUMN last_entered_pool_at TIMESTAMPTZ,
  ADD COLUMN created_from_rule_id BIGINT REFERENCES rules(id) ON DELETE SET NULL;

CREATE INDEX idx_tasks_milestone ON tasks(milestone_id);
CREATE INDEX idx_tasks_project_milestone_status ON tasks(project_id, milestone_id, status);
CREATE INDEX idx_tasks_card_status ON tasks(card_id, status);
CREATE INDEX idx_tasks_created_from_rule ON tasks(created_from_rule_id);

ALTER TABLE tasks
  ADD CONSTRAINT task_milestone_exclusive CHECK (card_id IS NULL OR milestone_id IS NULL);

ALTER TABLE tasks
  ADD CONSTRAINT tasks_pool_lifetime_non_negative CHECK (pool_lifetime_s >= 0);

ALTER TABLE tasks
  ADD CONSTRAINT tasks_project_card_fk
  FOREIGN KEY (project_id, card_id) REFERENCES cards(project_id, id) NOT VALID;

ALTER TABLE tasks
  ADD CONSTRAINT tasks_project_milestone_fk
  FOREIGN KEY (project_id, milestone_id) REFERENCES milestones(project_id, id) NOT VALID;

UPDATE tasks
SET last_entered_pool_at = CASE WHEN status = 'available' THEN created_at ELSE NULL END;

-- migrate:down

ALTER TABLE tasks DROP CONSTRAINT tasks_project_milestone_fk;
ALTER TABLE tasks DROP CONSTRAINT tasks_project_card_fk;
ALTER TABLE tasks DROP CONSTRAINT tasks_pool_lifetime_non_negative;
ALTER TABLE tasks DROP CONSTRAINT task_milestone_exclusive;

DROP INDEX idx_tasks_created_from_rule;
DROP INDEX idx_tasks_card_status;
DROP INDEX idx_tasks_project_milestone_status;
DROP INDEX idx_tasks_milestone;

ALTER TABLE tasks
  DROP COLUMN created_from_rule_id,
  DROP COLUMN last_entered_pool_at,
  DROP COLUMN pool_lifetime_s,
  DROP COLUMN milestone_id;

ALTER TABLE cards DROP CONSTRAINT cards_project_milestone_fk;
ALTER TABLE cards DROP CONSTRAINT cards_project_id_id_unique;

DROP INDEX idx_cards_project_milestone;
DROP INDEX idx_cards_milestone;

ALTER TABLE cards DROP COLUMN milestone_id;

ALTER TABLE milestones DROP CONSTRAINT milestones_project_id_id_unique;

DROP INDEX idx_milestones_one_active;
DROP INDEX idx_milestones_project_state_position;
DROP INDEX idx_milestones_project;

DROP TABLE milestones;
