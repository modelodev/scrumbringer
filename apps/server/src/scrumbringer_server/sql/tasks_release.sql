-- name: release_task
with updated as (
  update tasks
  set
    claimed_by = null,
    claimed_at = null,
    claimed_mode = null,
    execution_state = 'available',
    last_entered_pool_at = now(),
    version = version + 1
  where id = $1
    and execution_state = 'claimed'
    and claimed_by = $2
    and version = $3
  returning
    id,
    project_id,
    type_id,
    title,
    coalesce(description, '') as description,
    priority,
    execution_state as status,
    created_by,
    coalesce(claimed_by, 0) as claimed_by,
    coalesce(to_char(claimed_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') as claimed_at,
    coalesce(to_char(closed_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') as completed_at,
    to_char(created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at,
    coalesce(to_char(due_date, 'YYYY-MM-DD'), '') as due_date,
    version,
    coalesce(card_id, 0) as card_id,
    0 as parent_card_id,
    pool_lifetime_s,
    coalesce(to_char(last_entered_pool_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') as last_entered_pool_at,
    coalesce(created_from_rule_id, 0) as created_from_rule_id
)
select
  updated.*,
  coalesce(automation.id, 0) as automation_execution_id,
  coalesce(automation.template_id, 0) as automation_template_id,
  coalesce(automation.template_version, 0) as automation_template_version,
  coalesce(automation.workflow_id, 0) as automation_workflow_id,
  coalesce(automation.workflow_name, '') as automation_workflow_name,
  coalesce(automation.rule_name, '') as automation_rule_name,
  coalesce(automation.template_name, '') as automation_template_name,
  tt.name as type_name,
  tt.icon as type_icon,
  false as is_ongoing,
  0 as ongoing_by_user_id,
  coalesce(c.title, '') as card_title,
  coalesce(c.color, '') as card_color,
  deps.dependencies::text as dependencies,
  deps.blocked_count as blocked_count
from updated
join task_types tt on tt.id = updated.type_id
left join cards c on c.id = updated.card_id
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
  where re.created_task_id = updated.id
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
          'status', dt.execution_state,
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
  where d.task_id = updated.id
) deps on true;
