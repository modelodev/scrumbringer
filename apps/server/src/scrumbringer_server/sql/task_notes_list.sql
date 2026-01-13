-- name: task_notes_list
select
  n.id,
  n.task_id,
  n.user_id,
  n.content,
  to_char(n.created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at
from task_notes n
where n.task_id = $1
order by n.created_at asc, n.id asc;
