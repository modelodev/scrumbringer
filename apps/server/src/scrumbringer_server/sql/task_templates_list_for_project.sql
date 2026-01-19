-- name: list_task_templates_for_project
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
  to_char(t.created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at
FROM task_templates t
JOIN task_types tt on tt.id = t.type_id
WHERE t.project_id = $1
ORDER BY t.created_at DESC;
