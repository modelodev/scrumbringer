-- name: update_rule
UPDATE rules
SET
  name = $2,
  goal = nullif($3, ''),
  resource_type = $4,
  trigger_kind = $5,
  task_type_id = case when $6 <= 0 then null else $6 end,
  card_depth = case when $7 <= 0 then null else $7 end,
  to_state = $8,
  active = ($9 = 1)
WHERE id = $1
RETURNING
  id,
  workflow_id,
  name,
  coalesce(goal, '') as goal,
  resource_type,
  trigger_kind,
  coalesce(task_type_id, 0) as task_type_id,
  coalesce(card_depth, 0) as card_depth,
  to_state,
  active,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at;
