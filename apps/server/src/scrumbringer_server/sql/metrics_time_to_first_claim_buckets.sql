-- name: metrics_time_to_first_claim_buckets
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
    u.id as user_id,
    extract(epoch from (fc.first_claim_at - u.created_at)) * 1000 as delta_ms
  from first_claim fc
  join users u on u.id = fc.actor_user_id
),
buckets as (
  select
    case
      when delta_ms <= 3600000 then '0-1h'
      when delta_ms <= 14400000 then '1-4h'
      when delta_ms <= 86400000 then '4-24h'
      else '>24h'
    end as bucket,
    case
      when delta_ms <= 3600000 then 1
      when delta_ms <= 14400000 then 2
      when delta_ms <= 86400000 then 3
      else 4
    end as sort_key
  from deltas
)
select bucket, count(*)::int as count
from buckets
group by bucket, sort_key
order by sort_key;
