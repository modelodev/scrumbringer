-- name: delete_task
with eligible as (
  select t.id
  from tasks t
  where t.id = $1
    and t.execution_state = 'available'
    and t.claimed_by is null
    and t.claimed_at is null
    and t.closed_at is null
    and t.closed_by is null
    and t.closed_reason is null
    and not exists (
      select 1
      from audit_events e
      where e.task_id = t.id
        and e.event_type <> 'task_created'
    )
    and not exists (
      select 1
      from task_notes n
      where n.task_id = t.id
    )
    and not exists (
      select 1
      from task_dependencies d
      where d.task_id = t.id
        or d.depends_on_task_id = t.id
    )
    and not exists (
      select 1
      from user_task_work_session s
      where s.task_id = t.id
    )
    and not exists (
      select 1
      from user_task_work_total total
      where total.task_id = t.id
    )
), deleted_positions as (
  delete from task_positions
  where task_id in (select id from eligible)
), deleted_creation_events as (
  delete from audit_events
  where task_id in (select id from eligible)
    and event_type = 'task_created'
)
delete from tasks
where id in (select id from eligible)
returning id;
