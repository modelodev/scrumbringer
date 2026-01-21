-- migrate:up
-- Story 4.1: Make workflows project-only (no org-scoped workflows)

-- Delete dependent data for org-scoped workflows
DELETE FROM rule_executions
WHERE rule_id IN (
  SELECT r.id FROM rules r
  JOIN workflows w ON r.workflow_id = w.id
  WHERE w.project_id IS NULL
);

DELETE FROM rule_templates
WHERE rule_id IN (
  SELECT r.id FROM rules r
  JOIN workflows w ON r.workflow_id = w.id
  WHERE w.project_id IS NULL
);

DELETE FROM rules
WHERE workflow_id IN (
  SELECT id FROM workflows WHERE project_id IS NULL
);

DELETE FROM workflows WHERE project_id IS NULL;

-- Remove org-scope unique index
DROP INDEX IF EXISTS idx_workflows_org_scope_name;

-- Make project_id NOT NULL
ALTER TABLE workflows ALTER COLUMN project_id SET NOT NULL;

-- Simplify unique constraint to project scope only
DROP INDEX IF EXISTS idx_workflows_project_scope_name;
ALTER TABLE workflows DROP CONSTRAINT IF EXISTS workflows_org_id_project_id_name_key;
ALTER TABLE workflows ADD CONSTRAINT workflows_project_id_name_key UNIQUE(project_id, name);

-- migrate:down
-- WARNING: Cannot restore deleted org-scoped workflows

ALTER TABLE workflows DROP CONSTRAINT workflows_project_id_name_key;
ALTER TABLE workflows ALTER COLUMN project_id DROP NOT NULL;

CREATE UNIQUE INDEX idx_workflows_org_scope_name
ON workflows (org_id, name)
WHERE project_id IS NULL;

CREATE UNIQUE INDEX idx_workflows_project_scope_name
ON workflows (org_id, project_id, name)
WHERE project_id IS NOT NULL;
