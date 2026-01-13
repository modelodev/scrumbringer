-- name: create_task_type
insert into task_types (project_id, name, icon, capability_id)
values ($1, $2, $3, nullif($4, 0))
returning
  id,
  project_id,
  name,
  icon,
  coalesce(capability_id, 0) as capability_id;
