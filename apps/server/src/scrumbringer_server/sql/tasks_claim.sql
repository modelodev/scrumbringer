-- name: claim_task
with updated as (
  update tasks
  set
    claimed_by = $2,
    claimed_at = now(),
    status = 'claimed',
    pool_lifetime_s = pool_lifetime_s + case
      when last_entered_pool_at is null then 0
      else greatest(0, extract(epoch from (now() - last_entered_pool_at))::bigint)
    end,
    last_entered_pool_at = null,
    version = version + 1
  where id = $1
    and status = 'available'
    and version = $3
  returning
    id,
    project_id,
    type_id,
    title,
    coalesce(description, '') as description,
    priority,
    status,
    created_by,
    coalesce(claimed_by, 0) as claimed_by,
    coalesce(to_char(claimed_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') as claimed_at,
    coalesce(to_char(completed_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') as completed_at,
    to_char(created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at,
    version,
    coalesce(card_id, 0) as card_id,
    coalesce(milestone_id, 0) as milestone_id,
    pool_lifetime_s,
    coalesce(to_char(last_entered_pool_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') as last_entered_pool_at,
    coalesce(created_from_rule_id, 0) as created_from_rule_id
)
select
  updated.*,
  tt.name as type_name,
  tt.icon as type_icon,
  false as is_ongoing,
  0 as ongoing_by_user_id,
  coalesce(c.title, '') as card_title,
  coalesce(c.color, '') as card_color,
  deps.dependencies as dependencies,
  deps.blocked_count as blocked_count
from updated
join task_types tt on tt.id = updated.type_id
left join cards c on c.id = updated.card_id
left join lateral (
  select
    coalesce(
      json_agg(
        json_build_object(
          'task_id', d.depends_on_task_id,
          'title', dt.title,
          'status', dt.status,
          'claimed_by', u.email
        )
        order by dt.created_at desc
      ) filter (where dt.id is not null),
      '[]'
    ) as dependencies,
    coalesce(count(*) filter (where dt.status != 'completed'), 0) as blocked_count
  from task_dependencies d
  join tasks dt on dt.id = d.depends_on_task_id
  left join users u on u.id = dt.claimed_by
  where d.task_id = updated.id
) deps on true;
