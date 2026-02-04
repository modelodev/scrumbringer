-- name: metrics_users_overview
with event_counts as (
  select
    e.actor_user_id as user_id,
    coalesce(sum(case when e.event_type = 'task_claimed' then 1 else 0 end), 0) as claimed_count,
    coalesce(sum(case when e.event_type = 'task_released' then 1 else 0 end), 0) as released_count,
    coalesce(sum(case when e.event_type = 'task_completed' then 1 else 0 end), 0) as completed_count,
    max(case when e.event_type = 'task_claimed' then e.created_at else null end) as last_claim_at
  from task_events e
  where e.org_id = $1
    and e.created_at >= now() - ($2 || ' days')::interval
  group by e.actor_user_id
), ongoing as (
  select
    ws.user_id,
    count(*)::int as ongoing_count
  from user_task_work_session ws
  join tasks t on t.id = ws.task_id
  join projects p on p.id = t.project_id
  where ws.ended_at is null
    and p.org_id = $1
  group by ws.user_id
)
select
  u.id as user_id,
  u.email,
  coalesce(ec.claimed_count, 0) as claimed_count,
  coalesce(ec.released_count, 0) as released_count,
  coalesce(ec.completed_count, 0) as completed_count,
  coalesce(o.ongoing_count, 0) as ongoing_count,
  coalesce(to_char(ec.last_claim_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') as last_claim_at
from users u
left join event_counts ec on ec.user_id = u.id
left join ongoing o on o.user_id = u.id
where u.org_id = $1
order by u.email asc;
