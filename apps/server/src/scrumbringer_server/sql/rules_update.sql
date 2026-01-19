-- name: update_rule
UPDATE rules
SET
  name = case when $2 = '__unset__' then name else $2 end,
  goal = case when $3 = '__unset__' then goal else nullif($3, '') end,
  resource_type = case when $4 = '__unset__' then resource_type else $4 end,
  task_type_id = case
    when $5 = -1 then task_type_id
    when $5 <= 0 then null
    else $5
  end,
  to_state = case when $6 = '__unset__' then to_state else $6 end,
  active = case when $7 = -1 then active else ($7 = 1) end
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
