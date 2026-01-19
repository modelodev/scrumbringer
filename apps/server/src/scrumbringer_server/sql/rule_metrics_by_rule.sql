-- name: rule_metrics_by_rule
-- Get detailed metrics for a single rule with suppression breakdown.
select
    r.id as rule_id,
    r.name as rule_name,
    count(re.id)::int as evaluated_count,
    count(re.id) filter (where re.outcome = 'applied')::int as applied_count,
    count(re.id) filter (where re.outcome = 'suppressed')::int as suppressed_count,
    count(re.id) filter (where re.suppression_reason = 'idempotent')::int as suppressed_idempotent,
    count(re.id) filter (where re.suppression_reason = 'not_user_triggered')::int as suppressed_not_user,
    count(re.id) filter (where re.suppression_reason = 'not_matching')::int as suppressed_not_matching,
    count(re.id) filter (where re.suppression_reason = 'inactive')::int as suppressed_inactive
from rules r
left join rule_executions re on re.rule_id = r.id
    and re.created_at >= $2::timestamp
    and re.created_at <= $3::timestamp
where r.id = $1
group by r.id;
