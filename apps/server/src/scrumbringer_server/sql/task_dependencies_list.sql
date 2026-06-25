-- name: list_task_dependencies
select
  td.depends_on_task_id as task_id,
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
  coalesce(to_char(t.closed_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') as completed_at,
  coalesce(u.email, '') as claimed_by
from task_dependencies td
join tasks t on t.id = td.depends_on_task_id
left join users u on u.id = t.claimed_by
where td.task_id = $1
order by t.created_at desc;
