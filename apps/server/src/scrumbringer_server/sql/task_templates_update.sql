-- name: update_task_template
WITH current AS (
  SELECT id, type_id
  FROM task_templates
  WHERE id = $1
    AND org_id = $3
), type_ok AS (
  SELECT
    CASE
      WHEN $6 is null THEN current.type_id
      ELSE (
        SELECT tt.id
        FROM task_types tt
        JOIN projects p ON p.id = tt.project_id
        WHERE tt.id = $6
          AND (
            CASE
              WHEN $2 <= 0 THEN p.org_id = $3
              ELSE tt.project_id = $2
            END
          )
      )
    END as type_id
  FROM current
), updated AS (
  UPDATE task_templates
  SET
    name = case when $4 is null then name else $4 end,
    description = case when $5 is null then description else nullif($5, '') end,
    type_id = type_ok.type_id,
    priority = case when $7 is null then priority else $7 end
  FROM type_ok
  WHERE task_templates.id = $1
    AND task_templates.org_id = $3
    AND type_ok.type_id is not null
  RETURNING
    task_templates.id,
    task_templates.org_id,
    task_templates.project_id,
    task_templates.name,
    coalesce(task_templates.description, '') as description,
    task_templates.type_id,
    task_templates.priority,
    task_templates.created_by,
    to_char(task_templates.created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at
)
SELECT
  updated.*,
  tt.name as type_name
FROM updated
JOIN task_types tt on tt.id = updated.type_id;
