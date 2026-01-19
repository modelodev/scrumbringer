-- name: create_rule
INSERT INTO rules (
  workflow_id,
  name,
  goal,
  resource_type,
  task_type_id,
  to_state,
  active
)
VALUES (
  $1,
  $2,
  nullif($3, ''),
  $4,
  CASE WHEN $5 <= 0 THEN null ELSE $5 END,
  $6,
  $7
)
RETURNING
  id,
  workflow_id,
  name,
  coalesce(goal, '') as goal,
  resource_type,
  coalesce(task_type_id, 0) as task_type_id,
  to_state,
  active,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at;
