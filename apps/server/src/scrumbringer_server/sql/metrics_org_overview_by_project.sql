-- name: metrics_org_overview_by_project
with event_counts as (
  select
    e.project_id,
    coalesce(sum(case when e.event_type = 'task_claimed' then 1 else 0 end), 0) as claimed_count,
    coalesce(sum(case when e.event_type = 'task_released' then 1 else 0 end), 0) as released_count,
    coalesce(sum(case when e.event_type = 'task_completed' then 1 else 0 end), 0) as completed_count
  from task_events e
  where e.org_id = $1
    and e.created_at >= now() - ($2 || ' days')::interval
  group by e.project_id
), task_counts as (
  select
    t.project_id,
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
  group by t.project_id
), time_stats as (
  select
    t.project_id,
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
  group by t.project_id
)
select
  p.id as project_id,
  p.name as project_name,
  coalesce(ec.claimed_count, 0) as claimed_count,
  coalesce(ec.released_count, 0) as released_count,
  coalesce(ec.completed_count, 0) as completed_count,
  coalesce(tc.available_count, 0) as available_count,
  coalesce(tc.ongoing_count, 0) as ongoing_count,
  coalesce(tc.wip_count, 0) as wip_count,
  ts.avg_claim_to_complete_ms,
  ts.avg_time_in_claimed_ms,
  coalesce(ts.stale_claims_count, 0) as stale_claims_count
from projects p
left join event_counts ec on ec.project_id = p.id
left join task_counts tc on tc.project_id = p.id
left join time_stats ts on ts.project_id = p.id
where p.org_id = $1
order by p.name asc;
