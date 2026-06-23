-- name: rule_executions_count_for_project
-- Count business executions visible in a project.
select count(*)::int as total
from rule_executions re
join rules r on r.id = re.rule_id
join workflows w on w.id = r.workflow_id
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
    and (re.created_at at time zone 'utc') < (($3::timestamp)::date + interval '1 day');
