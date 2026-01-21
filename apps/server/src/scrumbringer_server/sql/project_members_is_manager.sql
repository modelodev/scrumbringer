-- name: is_project_manager
select exists(
  select 1
  from project_members
  where project_id = $1
    and user_id = $2
    and role = 'manager'
) as is_manager;
