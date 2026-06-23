-- name: create_rule
INSERT INTO rules (
  workflow_id,
  name,
  goal,
  resource_type,
  trigger_kind,
  task_type_id,
  card_depth,
  to_state,
  active
)
VALUES (
  $1,
  $2,
  nullif($3, ''),
  $4,
  $5,
  CASE WHEN $6 <= 0 THEN null ELSE $6 END,
  CASE WHEN $7 <= 0 THEN null ELSE $7 END,
  $8,
  $9
)
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
