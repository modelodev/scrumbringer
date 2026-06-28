WITH matched AS (
  SELECT id
  FROM task_templates
  WHERE id = $1
    AND org_id = $2
    AND archived_at IS NULL
), usage AS (
  SELECT
    EXISTS (
      SELECT 1
      FROM rule_templates rt
      JOIN matched m ON m.id = rt.template_id
    ) as has_rules,
    EXISTS (
      SELECT 1
      FROM rule_executions re
      JOIN matched m ON m.id = re.template_id
    ) as has_executions
), deleted AS (
  DELETE FROM task_templates
  WHERE id IN (SELECT id FROM matched)
    AND NOT (SELECT has_rules OR has_executions FROM usage)
  RETURNING id
), archived AS (
  UPDATE task_templates
  SET archived_at = now()
  WHERE id IN (SELECT id FROM matched)
    AND NOT (SELECT has_rules FROM usage)
    AND (SELECT has_executions FROM usage)
  RETURNING id
)
SELECT
  EXISTS (SELECT 1 FROM matched) as template_found,
  COALESCE((SELECT has_rules FROM usage), false) as has_rules,
  COALESCE((SELECT has_executions FROM usage), false) as has_executions,
  COALESCE((SELECT id FROM deleted), 0) as deleted_id,
  COALESCE((SELECT id FROM archived), 0) as archived_id;
