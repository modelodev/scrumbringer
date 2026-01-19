-- name: get_rule
SELECT
  r.id,
  r.workflow_id,
  r.name,
  coalesce(r.goal, '') as goal,
  r.resource_type,
  coalesce(r.task_type_id, 0) as task_type_id,
  r.to_state,
  r.active,
  to_char(r.created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at
FROM rules r
WHERE r.id = $1;
