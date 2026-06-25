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
  case
    when t.execution_state = 'closed' then 'completed'
    else t.execution_state
  end as status,
  (
    t.execution_state = 'claimed'
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
  coalesce(to_char(t.closed_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') as completed_at,
  to_char(t.created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at,
  coalesce(to_char(t.due_date, 'YYYY-MM-DD'), '') as due_date,
  t.version,
  coalesce(t.card_id, 0) as card_id,
  0 as parent_card_id,
  coalesce(c.title, '') as card_title,
  coalesce(c.color, '') as card_color,
  t.pool_lifetime_s,
  coalesce(to_char(t.last_entered_pool_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') as last_entered_pool_at,
  coalesce(t.created_from_rule_id, 0) as created_from_rule_id,
  coalesce(automation.id, 0) as automation_execution_id,
  coalesce(automation.template_id, 0) as automation_template_id,
  coalesce(automation.template_version, 0) as automation_template_version,
  coalesce(automation.workflow_id, 0) as automation_workflow_id,
  coalesce(automation.workflow_name, '') as automation_workflow_name,
  coalesce(automation.rule_name, '') as automation_rule_name,
  coalesce(automation.template_name, '') as automation_template_name,
  -- Story 5.4: AC4 - has_new_notes indicator
  case
    when (
      select max(n.created_at)
      from task_notes tn
      join notes n on n.id = tn.note_id
      where tn.task_id = t.id
    ) is null then false
    when (select v.last_viewed_at from user_task_views v where v.task_id = t.id and v.user_id = $6) is null then true
    when (
      select max(n.created_at)
      from task_notes tn
      join notes n on n.id = tn.note_id
      where tn.task_id = t.id
    ) > (select v.last_viewed_at from user_task_views v where v.task_id = t.id and v.user_id = $6) then true
    else false
  end as has_new_notes,
  deps.dependencies::text as dependencies,
  deps.blocked_count as blocked_count
from tasks t
join task_types tt on tt.id = t.type_id
left join cards c on c.id = t.card_id
left join lateral (
  select
    re.id,
    re.template_id,
    re.template_version,
    r.workflow_id,
    w.name as workflow_name,
    r.name as rule_name,
    template.name as template_name
  from rule_executions re
  join rules r on r.id = re.rule_id
  join workflows w on w.id = r.workflow_id
  left join task_templates template on template.id = re.template_id
  where re.created_task_id = t.id
    and re.outcome = 'applied'
  order by re.created_at desc, re.id desc
  limit 1
) automation on true
left join lateral (
  select
    coalesce(
      json_agg(
        json_build_object(
          'task_id', d.depends_on_task_id,
          'title', dt.title,
          'status', case
            when dt.execution_state = 'closed' then 'completed'
            else dt.execution_state
          end,
          'claimed_by_user_id', dt.claimed_by,
          'claimed_at', to_char(dt.claimed_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
          'completed_at', to_char(dt.closed_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
          'is_ongoing', (
            dt.execution_state = 'claimed'
            and exists(
              select 1
              from user_task_work_session ws
              where ws.task_id = dt.id and ws.ended_at is null
            )
          ),
          'claimed_by', u.email
        )
        order by dt.created_at desc
      ) filter (where dt.id is not null),
      '[]'
    ) as dependencies,
    coalesce(count(*) filter (where dt.execution_state != 'closed'), 0) as blocked_count
  from task_dependencies d
  join tasks dt on dt.id = d.depends_on_task_id
  left join users u on u.id = dt.claimed_by
  where d.task_id = t.id
) deps on true
where t.project_id = $1
  and (t.card_id is null or c.execution_state = 'active')
  and (
    $2 = ''
    or t.execution_state = $2
  )
  and ($3 <= 0 or t.type_id = $3)
  and ($4 <= 0 or tt.capability_id = $4)
  and (
    exists(
      select 1
      from project_members pm
      where pm.project_id = t.project_id
        and pm.user_id = $6
        and pm.role = 'manager'
    )
    or tt.capability_id is null
    or exists(
      select 1
      from project_member_capabilities pmc
      where pmc.project_id = t.project_id
        and pmc.user_id = $6
        and pmc.capability_id = tt.capability_id
    )
  )
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
