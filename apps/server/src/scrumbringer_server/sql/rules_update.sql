-- name: update_rule
UPDATE rules
SET
  name = $2,
  goal = nullif($3, ''),
  resource_type = $4,
  task_type_id = case when $5 <= 0 then null else $5 end,
  to_state = $6,
  active = ($7 = 1)
WHERE id = $1
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
