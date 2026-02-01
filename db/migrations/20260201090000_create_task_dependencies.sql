-- migrate:up
CREATE TABLE task_dependencies (
  id BIGSERIAL PRIMARY KEY,
  task_id BIGINT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  depends_on_task_id BIGINT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by BIGINT NOT NULL REFERENCES users(id),
  UNIQUE(task_id, depends_on_task_id),
  CHECK(task_id != depends_on_task_id)
);

CREATE INDEX idx_task_dependencies_task_id ON task_dependencies(task_id);
CREATE INDEX idx_task_dependencies_depends_on_task_id
  ON task_dependencies(depends_on_task_id);

-- migrate:down
DROP INDEX idx_task_dependencies_depends_on_task_id;
DROP INDEX idx_task_dependencies_task_id;

DROP TABLE task_dependencies;
