-- name: release_task
with updated as (
  update tasks
  set
    claimed_by = null,
    claimed_at = null,
    status = 'available',
    version = version + 1
  where id = $1
    and status = 'claimed'
    and claimed_by = $2
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
    coalesce(card_id, 0) as card_id
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
