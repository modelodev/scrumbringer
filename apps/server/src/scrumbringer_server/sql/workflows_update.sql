-- name: update_workflow
UPDATE workflows
SET
  name = case when $4 is null then name else $4 end,
  description = case when $5 is null then description else nullif($5, '') end
WHERE id = $1
  AND org_id = $2
  AND (
    CASE
      WHEN $3 <= 0 THEN project_id is null
      ELSE project_id = $3
    END
  )
RETURNING
  id,
  org_id,
  project_id,
  name,
  coalesce(description, '') as description,
  active,
  created_by,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at;
