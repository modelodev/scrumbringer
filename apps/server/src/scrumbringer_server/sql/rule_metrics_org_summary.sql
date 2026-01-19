-- name: rule_metrics_org_summary
-- Get org-wide rule metrics summary.
select
    w.id as workflow_id,
    w.name as workflow_name,
    coalesce(w.project_id, 0) as project_id,
    count(distinct r.id)::int as rule_count,
    count(re.id)::int as evaluated_count,
    count(re.id) filter (where re.outcome = 'applied')::int as applied_count,
    count(re.id) filter (where re.outcome = 'suppressed')::int as suppressed_count
from workflows w
left join rules r on r.workflow_id = w.id
left join rule_executions re on re.rule_id = r.id
    and re.created_at >= $2::timestamp
    and re.created_at <= $3::timestamp
where w.org_id = $1
group by w.id
order by w.name;
