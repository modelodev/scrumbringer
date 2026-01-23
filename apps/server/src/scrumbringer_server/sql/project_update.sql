-- name: project_update
update projects
set name = $2
where id = $1
returning
  id,
  org_id,
  name,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at;
