-- name: rule_executions_list
-- Get paginated list of executions for a rule (drill-down).
select
    re.id,
    re.origin_type,
    re.origin_id,
    re.outcome,
    coalesce(re.suppression_reason, '') as suppression_reason,
    coalesce(re.user_id, 0) as user_id,
    coalesce(u.email, '') as user_email,
    to_char(re.created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at
from rule_executions re
left join users u on u.id = re.user_id
where re.rule_id = $1
    and re.created_at >= $2::timestamp
    and re.created_at <= $3::timestamp
order by re.created_at desc
limit $4 offset $5;
