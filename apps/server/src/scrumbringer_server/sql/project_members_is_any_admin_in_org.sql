-- name: is_any_project_admin_in_org
select exists(
  select 1
  from project_members pm
  join projects p on p.id = pm.project_id
  where pm.user_id = $1
    and pm.role = 'admin'
    and p.org_id = $2
) as is_admin;
