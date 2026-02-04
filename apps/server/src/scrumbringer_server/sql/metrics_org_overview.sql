-- name: metrics_org_overview
with event_counts as (
  select
    coalesce(sum(case when event_type = 'task_claimed' then 1 else 0 end), 0) as claimed_count,
    coalesce(sum(case when event_type = 'task_released' then 1 else 0 end), 0) as released_count,
    coalesce(sum(case when event_type = 'task_completed' then 1 else 0 end), 0) as completed_count
  from task_events
  where org_id = $1
    and created_at >= now() - ($2 || ' days')::interval
), task_counts as (
  select
    coalesce(sum(case when t.status = 'available' then 1 else 0 end), 0) as available_count,
    coalesce(sum(case when t.status = 'claimed' then 1 else 0 end), 0) as wip_count,
    coalesce(sum(case
      when t.status = 'claimed'
        and exists(
          select 1 from user_task_work_session ws
          where ws.task_id = t.id and ws.ended_at is null
        )
      then 1 else 0 end), 0) as ongoing_count
  from tasks t
  join projects p on p.id = t.project_id
  where p.org_id = $1
), time_stats as (
  select
    avg(extract(epoch from (t.completed_at - t.claimed_at)) * 1000)::bigint
      as avg_claim_to_complete_ms,
    avg(extract(epoch from (now() - t.claimed_at)) * 1000)::bigint
      as avg_time_in_claimed_ms,
    coalesce(sum(case
      when t.status = 'claimed' and t.claimed_at < now() - interval '48 hours'
      then 1 else 0 end), 0) as stale_claims_count
  from tasks t
  join projects p on p.id = t.project_id
  where p.org_id = $1
)
select
  event_counts.claimed_count,
  event_counts.released_count,
  event_counts.completed_count,
  task_counts.available_count,
  task_counts.ongoing_count,
  task_counts.wip_count,
  time_stats.avg_claim_to_complete_ms,
  time_stats.avg_time_in_claimed_ms,
  time_stats.stale_claims_count
from event_counts, task_counts, time_stats;
