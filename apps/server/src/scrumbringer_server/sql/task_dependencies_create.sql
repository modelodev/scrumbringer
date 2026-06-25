-- name: create_task_dependency
with inserted as (
  insert into task_dependencies (task_id, depends_on_task_id, created_by)
  values ($1, $2, $3)
  returning depends_on_task_id
)
select
  i.depends_on_task_id as task_id,
  t.title,
  t.execution_state as status,
  (
    t.execution_state = 'claimed'
    and exists(
      select 1
      from user_task_work_session ws
      where ws.task_id = t.id and ws.ended_at is null
    )
  ) as is_ongoing,
  coalesce(t.claimed_by, 0) as claimed_by_user_id,
  coalesce(to_char(t.claimed_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') as claimed_at,
  coalesce(to_char(t.closed_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') as closed_at,
  coalesce(u.email, '') as claimed_by
from inserted i
join tasks t on t.id = i.depends_on_task_id
left join users u on u.id = t.claimed_by;
