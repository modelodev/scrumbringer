-- name: rule_executions_list_for_project
-- List business executions visible in a project.
select
    re.id,
    w.id as workflow_id,
    w.name as workflow_name,
    r.id as rule_id,
    r.name as rule_name,
    coalesce(re.task_id, 0) as task_id,
    coalesce(origin_task.title, '') as task_title,
    coalesce(re.card_id, 0) as card_id,
    coalesce(origin_card.title, '') as card_title,
    re.outcome,
    coalesce(re.suppression_reason, '') as suppression_reason,
    coalesce(re.user_id, 0) as user_id,
    coalesce(u.email, '') as user_email,
    coalesce(re.template_id, 0) as template_id,
    coalesce(template.name, '') as template_name,
    coalesce(re.template_version, 0) as template_version,
    coalesce(re.created_task_id, 0) as created_task_id,
    coalesce(created_task.title, '') as created_task_title,
    to_char(re.created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at
from rule_executions re
join rules r on r.id = re.rule_id
join workflows w on w.id = r.workflow_id
left join users u on u.id = re.user_id
left join task_templates template on template.id = re.template_id
left join tasks origin_task on origin_task.id = re.task_id
left join cards origin_card on origin_card.id = re.card_id
left join tasks created_task on created_task.id = re.created_task_id
where re.outcome = 'applied'
    and (
        w.project_id = $1
        or origin_task.project_id = $1
        or origin_card.project_id = $1
        or created_task.project_id = $1
    )
    and (re.created_at at time zone 'utc') >= ($2::timestamp)::date
    and (re.created_at at time zone 'utc') < (($3::timestamp)::date + interval '1 day')
order by re.created_at desc
limit $4 offset $5;
