-- name: list_workflows_for_project
SELECT
  w.id,
  w.org_id,
  coalesce(w.project_id, 0) as project_id,
  w.name,
  coalesce(w.description, '') as description,
  w.active,
  w.created_by,
  to_char(w.created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at,
  coalesce(r.rule_count, 0) as rule_count
FROM workflows w
LEFT JOIN (
  SELECT workflow_id, count(*)::int as rule_count
  FROM rules
  GROUP BY workflow_id
) r ON r.workflow_id = w.id
WHERE w.project_id = $1
ORDER BY w.created_at DESC;
