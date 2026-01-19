-- name: rules_get_templates_for_execution
-- Get templates attached to a rule for execution, ordered by execution_order.
select
  t.id,
  t.org_id,
  coalesce(t.project_id, 0) as project_id,
  t.name,
  coalesce(t.description, '') as description,
  t.type_id,
  t.priority,
  t.created_by,
  to_char(t.created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at,
  rt.execution_order
from rule_templates rt
join task_templates t on t.id = rt.template_id
where rt.rule_id = $1
order by rt.execution_order, t.id;
