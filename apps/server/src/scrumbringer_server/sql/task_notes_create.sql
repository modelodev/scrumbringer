-- name: task_notes_create
with task_ref as (
  select id, project_id
  from tasks
  where id = $1
), inserted_note as (
  insert into notes (project_id, user_id, content)
  select project_id, $2, $3
  from task_ref
  returning id, user_id, content, created_at
), inserted_link as (
  insert into task_notes (note_id, task_id)
  select inserted_note.id, task_ref.id
  from inserted_note
  cross join task_ref
  returning note_id, task_id
)
select
  n.id,
  l.task_id,
  n.user_id,
  n.content,
  to_char(n.created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at
from inserted_note n
join inserted_link l on l.note_id = n.id;
