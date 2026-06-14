-- name: task_notes_get
select
  id,
  task_id,
  user_id,
  content,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at
from task_notes
where task_id = $1
  and id = $2;
