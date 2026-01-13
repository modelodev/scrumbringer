-- name: list_projects_for_user
select
  p.id,
  p.org_id,
  p.name,
  to_char(p.created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at,
  pm.role as my_role
from projects p
join project_members pm on pm.project_id = p.id
where pm.user_id = $1
order by p.name asc;
