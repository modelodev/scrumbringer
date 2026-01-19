-- name: list_rule_templates_for_rule
SELECT
  t.id,
  t.org_id,
  coalesce(t.project_id, 0) as project_id,
  t.name,
  coalesce(t.description, '') as description,
  t.type_id,
  tt.name as type_name,
  t.priority,
  t.created_by,
  to_char(t.created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at,
  rt.execution_order
FROM rule_templates rt
JOIN task_templates t ON t.id = rt.template_id
JOIN task_types tt ON tt.id = t.type_id
WHERE rt.rule_id = $1
ORDER BY rt.execution_order ASC, t.created_at ASC;
