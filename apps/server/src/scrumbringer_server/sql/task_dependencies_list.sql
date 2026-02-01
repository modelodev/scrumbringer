-- name: list_task_dependencies
select
  td.depends_on_task_id as task_id,
  t.title,
  t.status,
  coalesce(u.email, '') as claimed_by
from task_dependencies td
join tasks t on t.id = td.depends_on_task_id
left join users u on u.id = t.claimed_by
where td.task_id = $1
order by t.created_at desc;
