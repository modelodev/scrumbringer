-- name: insert_project_member
insert into project_members (project_id, user_id, role)
values ($1, $2, $3)
returning
  project_id,
  user_id,
  role,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at;
