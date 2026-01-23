-- name: list_task_templates_for_project
-- Story 4.9 AC20: Include rules_count for each template
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
  coalesce(rule_counts.count, 0) as rules_count
FROM task_templates t
JOIN task_types tt on tt.id = t.type_id
LEFT JOIN (
  SELECT template_id, count(*) as count
  FROM rule_templates
  GROUP BY template_id
) rule_counts ON rule_counts.template_id = t.id
WHERE t.project_id = $1
ORDER BY t.created_at DESC;
