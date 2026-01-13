-- migrate:up
CREATE TABLE task_types (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  icon TEXT NOT NULL,
  capability_id BIGINT REFERENCES capabilities(id),
  project_id BIGINT NOT NULL REFERENCES projects(id),
  UNIQUE(name, project_id)
);

CREATE INDEX idx_task_types_project ON task_types(project_id);
CREATE INDEX idx_task_types_capability ON task_types(capability_id);

-- migrate:down
DROP INDEX idx_task_types_capability;
DROP INDEX idx_task_types_project;

DROP TABLE task_types;
