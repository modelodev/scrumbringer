-- Get paginated list of executions for a rule (drill-down).
select
    re.id,
    coalesce(re.task_id, 0) as task_id,
    coalesce(re.card_id, 0) as card_id,
    re.outcome,
    coalesce(re.suppression_reason, '') as suppression_reason,
    coalesce(re.user_id, 0) as user_id,
    coalesce(u.email, '') as user_email,
    coalesce(re.template_id, 0) as template_id,
    coalesce(re.template_version, 0) as template_version,
    coalesce(re.created_task_id, 0) as created_task_id,
    to_char(re.created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at
from rule_executions re
left join users u on u.id = re.user_id
where re.rule_id = $1
    and re.outcome = 'applied'
    and (re.created_at at time zone 'utc') >= ($2::timestamp)::date
    and (re.created_at at time zone 'utc') < (($3::timestamp)::date + interval '1 day')
order by re.created_at desc
limit $4 offset $5;
