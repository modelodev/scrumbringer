-- name: rule_executions_mark_created_task
-- Attach the task created by a reserved rule execution.
update rule_executions
set created_task_id = $2
where id = $1
returning id;
