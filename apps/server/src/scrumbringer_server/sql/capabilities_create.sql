-- name: create_capability
insert into capabilities (project_id, name)
values ($1, $2)
returning
  id,
  project_id,
  name,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at;
