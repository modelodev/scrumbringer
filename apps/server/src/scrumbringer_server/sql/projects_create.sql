-- name: create_project
-- Create a project and add the creator as an admin member.
with new_project as (
  insert into projects (org_id, name)
  values ($1, $2)
  returning id, org_id, name, created_at
), membership as (
  insert into project_members (project_id, user_id, role)
  select new_project.id, $3, 'admin'
  from new_project
)
select
  new_project.id,
  new_project.org_id,
  new_project.name,
  to_char(new_project.created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at,
  'admin' as my_role
from new_project;
