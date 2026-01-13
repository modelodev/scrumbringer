-- name: task_notes_create
insert into task_notes (task_id, user_id, content)
values ($1, $2, $3)
returning
  id,
  task_id,
  user_id,
  content,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at;
