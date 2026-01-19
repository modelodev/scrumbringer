-- name: create_task_template
WITH type_ok AS (
  SELECT tt.id
  FROM task_types tt
  JOIN projects p ON p.id = tt.project_id
  WHERE tt.id = $3
    AND (
      CASE
        WHEN $2 <= 0 THEN p.org_id = $1
        ELSE tt.project_id = $2
      END
    )
), inserted AS (
  INSERT INTO task_templates (org_id, project_id, name, description, type_id, priority, created_by)
  SELECT
    $1,
    CASE WHEN $2 <= 0 THEN null ELSE $2 END,
    $4,
    nullif($5, ''),
    type_ok.id,
    $6,
    $7
  FROM type_ok
  RETURNING
    id,
    org_id,
    project_id,
    name,
    coalesce(description, '') as description,
    type_id,
    priority,
    created_by,
    to_char(created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at
)
SELECT
  inserted.*,
  tt.name as type_name
FROM inserted
JOIN task_types tt on tt.id = inserted.type_id;
