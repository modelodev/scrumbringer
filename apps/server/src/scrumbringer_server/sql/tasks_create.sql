-- name: create_task
-- Create a new task in a project, ensuring the task type belongs to the project.
with type_ok as (
  select id
  from task_types
  where id = $1
    and project_id = $2
), inserted as (
  insert into tasks (project_id, type_id, title, description, priority, created_by)
  select
    $2,
    type_ok.id,
    $3,
    nullif($4, ''),
    $5,
    $6
  from type_ok
  returning
    id,
    project_id,
    type_id,
    title,
    coalesce(description, '') as description,
    priority,
    status,
    created_by,
    coalesce(claimed_by, 0) as claimed_by,
    coalesce(to_char(claimed_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') as claimed_at,
    coalesce(to_char(completed_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') as completed_at,
    to_char(created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at,
    version
)
select
  inserted.*,
  tt.name as type_name,
  tt.icon as type_icon,
  (false) as is_ongoing,
  0 as ongoing_by_user_id
from inserted
join task_types tt on tt.id = inserted.type_id;
