-- Create a project and add the creator as a manager member.
with new_project as (
  insert into projects (org_id, name)
  values ($1, $2)
  returning id, org_id, name, created_at
), membership as (
  insert into project_members (project_id, user_id, role)
  select new_project.id, $3, 'manager'
  from new_project
), depth_names as (
  insert into project_card_depth_names
    (project_id, depth, singular_name, plural_name)
  select
    new_project.id,
    names.depth,
    names.singular_name,
    names.plural_name
  from new_project
  cross join (
    values
      (1, 'Initiative', 'Initiatives'),
      (2, 'Feature', 'Features'),
      (3, 'Task group', 'Task groups')
  ) as names(depth, singular_name, plural_name)
  on conflict (project_id, depth) do nothing
), settings as (
  insert into project_settings (project_id, healthy_pool_limit)
  select new_project.id, 20
  from new_project
  on conflict (project_id) do nothing
), default_task_types as (
  insert into task_types (project_id, name, icon)
  select
    new_project.id,
    task_type.name,
    task_type.icon
  from new_project
  cross join (
    values
      ('General', 'check-square')
  ) as task_type(name, icon)
  on conflict (name, project_id) do nothing
)
select
  new_project.id,
  new_project.org_id,
  new_project.name,
  to_char(new_project.created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at,
  'manager' as my_role
from new_project;
