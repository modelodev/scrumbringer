-- name: list_capabilities_for_project
select
  id,
  project_id,
  name,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at
from capabilities
where project_id = $1
order by name asc;
