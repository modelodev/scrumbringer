-- name: metrics_time_to_first_claim_p50_ms
with first_claim as (
  select
    actor_user_id,
    min(created_at) as first_claim_at
  from task_events
  where org_id = $1
    and event_type = 'task_claimed'
    and created_at >= now() - ($2 || ' days')::interval
  group by actor_user_id
), deltas as (
  select
    extract(epoch from (fc.first_claim_at - u.created_at)) * 1000 as delta_ms
  from first_claim fc
  join users u on u.id = fc.actor_user_id
  where (fc.first_claim_at - u.created_at) >= interval '0 seconds'
)
select
  coalesce(
    percentile_disc(0.5) within group (order by delta_ms)::bigint,
    0
  ) as p50_ms,
  count(*)::int as sample_size
from deltas;
