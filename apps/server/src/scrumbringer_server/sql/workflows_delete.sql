-- name: delete_workflow
WITH matched AS (
  SELECT id
  FROM workflows
  WHERE id = $1
    AND org_id = $2
    AND (
      CASE
        WHEN $3 <= 0 THEN project_id is null
        ELSE project_id = $3
      END
    )
), usage AS (
  SELECT EXISTS (
    SELECT 1
    FROM rule_executions re
    JOIN rules r ON r.id = re.rule_id
    JOIN matched m ON m.id = r.workflow_id
  ) AS has_executions
), paused_workflow AS (
  UPDATE workflows
  SET active = false
  WHERE id IN (SELECT id FROM matched)
    AND (SELECT has_executions FROM usage)
  RETURNING id
), paused_rules AS (
  UPDATE rules
  SET active = false
  WHERE workflow_id IN (SELECT id FROM matched)
    AND (SELECT has_executions FROM usage)
  RETURNING id
), deleted AS (
  DELETE FROM workflows
  WHERE id IN (SELECT id FROM matched)
    AND NOT (SELECT has_executions FROM usage)
  RETURNING id
)
SELECT
  EXISTS (SELECT 1 FROM matched) AS workflow_found,
  (SELECT has_executions FROM usage) AS has_executions,
  COALESCE((SELECT id FROM paused_workflow LIMIT 1), 0) AS paused_id,
  COALESCE((SELECT id FROM deleted LIMIT 1), 0) AS deleted_id;
