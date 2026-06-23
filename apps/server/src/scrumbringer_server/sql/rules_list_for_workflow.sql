-- name: list_rules_for_workflow
SELECT
  r.id,
  r.workflow_id,
  r.name,
  coalesce(r.goal, '') as goal,
  r.resource_type,
  r.trigger_kind,
  coalesce(r.task_type_id, 0) as task_type_id,
  coalesce(r.card_depth, 0) as card_depth,
  r.to_state,
  r.active,
  to_char(r.created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at
FROM rules r
WHERE r.workflow_id = $1
ORDER BY r.created_at ASC;
