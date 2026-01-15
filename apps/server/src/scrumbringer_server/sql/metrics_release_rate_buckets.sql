-- name: metrics_release_rate_buckets
with per_user as (
  select
    actor_user_id,
    coalesce(sum(case when event_type = 'task_claimed' then 1 else 0 end), 0) as claims,
    coalesce(sum(case when event_type = 'task_released' then 1 else 0 end), 0) as releases
  from task_events
  where org_id = $1
    and created_at >= now() - ($2 || ' days')::interval
  group by actor_user_id
), rates as (
  select
    actor_user_id,
    case
      when claims = 0 then null
      else releases::numeric / claims::numeric
    end as rate
  from per_user
)
select bucket, count::int as count
from (
  select
    case
      when rate is null then 'no-claims'
      when rate = 0 then '0%'
      when rate <= 0.15 then '0-15%'
      when rate <= 0.50 then '15-50%'
      else '>50%'
    end as bucket,
    case
      when rate is null then 5
      when rate = 0 then 1
      when rate <= 0.15 then 2
      when rate <= 0.50 then 3
      else 4
    end as sort_key,
    count(*) as count
  from rates
  group by bucket, sort_key
) b
order by sort_key;
