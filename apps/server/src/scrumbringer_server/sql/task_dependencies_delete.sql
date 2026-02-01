-- name: delete_task_dependency
delete from task_dependencies
where task_id = $1
  and depends_on_task_id = $2
returning
  task_id,
  depends_on_task_id;
