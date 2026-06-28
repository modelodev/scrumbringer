select
  pm.project_id,
  pm.user_id,
  u.email,
  pm.role,
  to_char(pm.created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as member_created_at,
  coalesce(t.id, 0) as task_id,
  coalesce(t.version, 0) as task_version,
  coalesce(t.claimed_by, 0) as task_owner_user_id,
  coalesce(t.title, '') as task_title,
  coalesce(tt.name, '') as task_type_name,
  coalesce(cap.name, '') as capability_name,
  coalesce(t.card_id, 0) as card_id,
  coalesce(c.title, '') as card_title,
  coalesce(c.execution_state, '') as card_state,
  coalesce(active_ws.user_id, 0) as ongoing_by_user_id,
  coalesce(deps.blocked_count, 0) as blocked_count
from project_members pm
join users u on u.id = pm.user_id
left join tasks t
  on t.project_id = pm.project_id
  and t.claimed_by = pm.user_id
  and t.execution_state = 'claimed'
left join task_types tt on tt.id = t.type_id
left join capabilities cap on cap.id = tt.capability_id
left join cards c on c.id = t.card_id
left join lateral (
  select ws.user_id
  from user_task_work_session ws
  where ws.task_id = t.id
    and ws.ended_at is null
  order by ws.started_at desc
  limit 1
) active_ws on true
left join lateral (
  select coalesce(count(*) filter (where dt.execution_state != 'closed'), 0) as blocked_count
  from task_dependencies d
  join tasks dt on dt.id = d.depends_on_task_id
  where d.task_id = t.id
) deps on true
where pm.project_id = $1
order by
  u.email asc,
  coalesce(t.created_at, pm.created_at) desc,
  coalesce(t.id, 0) desc;
