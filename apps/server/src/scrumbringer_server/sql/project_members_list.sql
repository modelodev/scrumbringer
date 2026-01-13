-- name: list_project_members
select
  project_id,
  user_id,
  role,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at
from project_members
where project_id = $1
order by user_id asc;
