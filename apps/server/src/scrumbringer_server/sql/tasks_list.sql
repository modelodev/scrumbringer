-- name: list_tasks_for_project
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
  -- Story 5.4: AC4 - has_new_notes indicator
  case
    when (select max(n.created_at) from task_notes n where n.task_id = t.id) is null then false
    when (select v.last_viewed_at from user_task_views v where v.task_id = t.id and v.user_id = $6) is null then true
    when (select max(n.created_at) from task_notes n where n.task_id = t.id) > (select v.last_viewed_at from user_task_views v where v.task_id = t.id and v.user_id = $6) then true
    else false
  end as has_new_notes,
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
where t.project_id = $1
  and ($2 = '' or t.status = $2)
  and ($3 <= 0 or t.type_id = $3)
  and ($4 <= 0 or tt.capability_id = $4)
  and (
    $5 = ''
    or t.title ilike ('%' || $5 || '%')
    or t.description ilike ('%' || $5 || '%')
  )
  and (
    $7 = ''
    or ($7 = 'true' and deps.blocked_count > 0)
    or ($7 = 'false' and deps.blocked_count = 0)
  )
order by t.created_at desc;
