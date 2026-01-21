-- name: rule_metrics_by_workflow
-- Get aggregated metrics for all rules in a workflow.
select
    r.id as rule_id,
    r.name as rule_name,
    r.active,
    count(re.id)::int as evaluated_count,
    count(re.id) filter (where re.outcome = 'applied')::int as applied_count,
    count(re.id) filter (where re.outcome = 'suppressed')::int as suppressed_count
from rules r
left join rule_executions re on re.rule_id = r.id
    and re.created_at >= ($2::timestamp)::date
    and re.created_at < (($3::timestamp)::date + interval '1 day')
where r.workflow_id = $1
group by r.id
order by r.name;
