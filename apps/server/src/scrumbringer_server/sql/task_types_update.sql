-- name: update_task_type
-- Story 4.9 AC13: Update task type name, icon, or capability
update task_types
set
  name = $2,
  icon = $3,
  capability_id = case when $4 = 0 then null else $4 end
where id = $1
returning
  id,
  project_id,
  name,
  icon,
  coalesce(capability_id, 0) as capability_id;
