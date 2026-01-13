-- migrate:up
CREATE TABLE tasks (
  id BIGSERIAL PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  priority INT NOT NULL DEFAULT 3 CHECK (priority BETWEEN 1 AND 5),
  status TEXT NOT NULL DEFAULT 'available'
    CHECK (status IN ('available', 'claimed', 'completed')),
  type_id BIGINT NOT NULL REFERENCES task_types(id),
  project_id BIGINT NOT NULL REFERENCES projects(id),
  created_by BIGINT NOT NULL REFERENCES users(id),
  claimed_by BIGINT REFERENCES users(id),
  claimed_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  version INT NOT NULL DEFAULT 1
);

CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_project ON tasks(project_id);
CREATE INDEX idx_tasks_claimed_by ON tasks(claimed_by);

-- migrate:down
DROP INDEX idx_tasks_claimed_by;
DROP INDEX idx_tasks_project;
DROP INDEX idx_tasks_status;

DROP TABLE tasks;
