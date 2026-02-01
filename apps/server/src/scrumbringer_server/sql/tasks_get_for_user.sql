-- name: get_task_for_user
select
  t.id,
  t.project_id,
  t.type_id,
  tt.name as type_name,
  tt.icon as type_icon,
  t.title,
  coalesce(t.description, '') as description,
  t.priority,
  t.status,
  (
    t.status = 'claimed'
    and exists(
      select 1
      from user_task_work_session ws
      where ws.task_id = t.id and ws.ended_at is null
    )
  ) as is_ongoing,
  coalesce((
    select ws.user_id
    from user_task_work_session ws
    where ws.task_id = t.id and ws.ended_at is null
    order by ws.started_at desc
    limit 1
  ), 0) as ongoing_by_user_id,
  t.created_by,
  coalesce(t.claimed_by, 0) as claimed_by,
  coalesce(to_char(t.claimed_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') as claimed_at,
  coalesce(to_char(t.completed_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') as completed_at,
  to_char(t.created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at,
  t.version,
  coalesce(t.card_id, 0) as card_id,
  coalesce(c.title, '') as card_title,
  coalesce(c.color, '') as card_color,
  deps.dependencies as dependencies,
  deps.blocked_count as blocked_count
from tasks t
join task_types tt on tt.id = t.type_id
left join cards c on c.id = t.card_id
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
  where d.task_id = t.id
) deps on true
where t.id = $1
  and exists(
    select 1
    from project_members pm
    where pm.project_id = t.project_id
      and pm.user_id = $2
  );
