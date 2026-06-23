-- name: list_task_templates_for_project
-- Story 4.9 AC20: Include template usage counters
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
  t.version,
  to_char(t.created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at,
  coalesce(rule_counts.count, 0) as rules_count,
  coalesce(execution_stats.created_tasks_count, 0) as created_tasks_count,
  coalesce(execution_stats.last_execution_at, '') as last_execution_at
FROM task_templates t
JOIN task_types tt on tt.id = t.type_id
LEFT JOIN (
  SELECT template_id, count(*) as count
  FROM rule_templates
  GROUP BY template_id
) rule_counts ON rule_counts.template_id = t.id
LEFT JOIN (
  SELECT
    template_id,
    count(created_task_id) FILTER (
      WHERE outcome = 'applied'
        AND created_task_id IS NOT NULL
    ) as created_tasks_count,
    to_char(
      (max(created_at) FILTER (WHERE outcome = 'applied')) at time zone 'utc',
      'YYYY-MM-DD"T"HH24:MI:SS"Z"'
    ) as last_execution_at
  FROM rule_executions
  WHERE template_id IS NOT NULL
  GROUP BY template_id
) execution_stats ON execution_stats.template_id = t.id
WHERE t.project_id = $1
ORDER BY t.created_at DESC;
