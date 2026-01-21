-- migrate:up
-- Story 4.1: Make task_templates project-only (no org-scoped templates)

-- Delete dependent rule_templates for org-scoped templates
DELETE FROM rule_templates
WHERE template_id IN (
  SELECT id FROM task_templates WHERE project_id IS NULL
);

-- Delete org-scoped templates
DELETE FROM task_templates WHERE project_id IS NULL;

-- Make project_id NOT NULL
ALTER TABLE task_templates ALTER COLUMN project_id SET NOT NULL;

-- migrate:down
-- WARNING: Cannot restore deleted org-scoped templates

ALTER TABLE task_templates ALTER COLUMN project_id DROP NOT NULL;
