-- name: delete_task_type
-- Story 4.9 AC14: Delete task type (only if no tasks use it)
-- Returns empty if type has associated tasks (foreign key constraint)
delete from task_types
where id = $1
  and not exists (
    select 1 from tasks t where t.type_id = $1
  )
returning id;
