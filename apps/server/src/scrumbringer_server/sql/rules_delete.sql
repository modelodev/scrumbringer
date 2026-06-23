-- name: delete_rule
WITH matched AS (
  SELECT id
  FROM rules
  WHERE id = $1
), usage AS (
  SELECT EXISTS (
    SELECT 1
    FROM rule_executions re
    JOIN matched m ON m.id = re.rule_id
  ) OR EXISTS (
    SELECT 1
    FROM tasks t
    JOIN matched m ON m.id = t.created_from_rule_id
  ) AS has_history
), paused AS (
  UPDATE rules
  SET active = false
  WHERE id IN (SELECT id FROM matched)
    AND (SELECT has_history FROM usage)
  RETURNING id
), deleted AS (
  DELETE FROM rules
  WHERE id IN (SELECT id FROM matched)
    AND NOT (SELECT has_history FROM usage)
  RETURNING id
)
SELECT
  EXISTS (SELECT 1 FROM matched) AS rule_found,
  (SELECT has_history FROM usage) AS has_history,
  COALESCE((SELECT id FROM paused LIMIT 1), 0) AS paused_id,
  COALESCE((SELECT id FROM deleted LIMIT 1), 0) AS deleted_id;
