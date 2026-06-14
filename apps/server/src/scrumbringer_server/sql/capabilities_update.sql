-- name: update_capability
update capabilities
set name = $3
where project_id = $1
  and id = $2
returning
  id,
  project_id,
  name,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at;
