-- name: is_project_admin
select exists(
  select 1
  from project_members
  where project_id = $1
    and user_id = $2
    and role = 'admin'
) as is_admin;
