-- migrate:up
-- Ensure workflow names are unique within org and scope (org vs project)

WITH ranked AS (
  SELECT
    id,
    row_number() OVER (PARTITION BY org_id, project_id, name ORDER BY id) AS rn
  FROM workflows
)
DELETE FROM workflows
WHERE id IN (SELECT id FROM ranked WHERE rn > 1);

CREATE UNIQUE INDEX idx_workflows_org_scope_name
ON workflows (org_id, name)
WHERE project_id IS NULL;

CREATE UNIQUE INDEX idx_workflows_project_scope_name
ON workflows (org_id, project_id, name)
WHERE project_id IS NOT NULL;

-- migrate:down

DROP INDEX IF EXISTS idx_workflows_project_scope_name;
DROP INDEX IF EXISTS idx_workflows_org_scope_name;
