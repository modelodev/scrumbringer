-- name: metrics_my
select
  coalesce(sum(case when event_type = 'task_claimed' then 1 else 0 end), 0) as claimed_count,
  coalesce(sum(case when event_type = 'task_released' then 1 else 0 end), 0) as released_count,
  coalesce(sum(case when event_type = 'task_completed' then 1 else 0 end), 0) as completed_count
from task_events
where actor_user_id = $1
  and created_at >= now() - ($2 || ' days')::interval;
