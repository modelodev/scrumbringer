-- name: task_notes_delete
delete from task_notes
where task_id = $1
  and id = $2
returning id;
