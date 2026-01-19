-- name: create_workflow
INSERT INTO workflows (org_id, project_id, name, description, active, created_by)
VALUES (
  $1,
  CASE WHEN $2 <= 0 THEN null ELSE $2 END,
  $3,
  nullif($4, ''),
  $5,
  $6
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
