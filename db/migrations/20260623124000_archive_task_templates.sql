-- migrate:up

ALTER TABLE task_templates
ADD COLUMN archived_at TIMESTAMPTZ;

CREATE INDEX idx_task_templates_active_project
  ON task_templates(project_id, created_at DESC)
  WHERE archived_at IS NULL;

-- migrate:down

DROP INDEX IF EXISTS idx_task_templates_active_project;

ALTER TABLE task_templates
DROP COLUMN archived_at;
