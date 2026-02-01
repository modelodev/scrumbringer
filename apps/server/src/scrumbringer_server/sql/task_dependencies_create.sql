-- name: create_task_dependency
with inserted as (
  insert into task_dependencies (task_id, depends_on_task_id, created_by)
  values ($1, $2, $3)
  returning depends_on_task_id
)
select
  i.depends_on_task_id as task_id,
  t.title,
  t.status,
  coalesce(u.email, '') as claimed_by
from inserted i
join tasks t on t.id = i.depends_on_task_id
left join users u on u.id = t.claimed_by;
