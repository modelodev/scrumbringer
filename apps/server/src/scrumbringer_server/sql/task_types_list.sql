-- name: list_task_types_for_project
select
  id,
  project_id,
  name,
  icon,
  coalesce(capability_id, 0) as capability_id
from task_types
where project_id = $1
order by name asc;
