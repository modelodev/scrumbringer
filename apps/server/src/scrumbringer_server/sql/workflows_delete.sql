-- name: delete_workflow
DELETE FROM workflows
WHERE id = $1
  AND org_id = $2
  AND (
    CASE
      WHEN $3 <= 0 THEN project_id is null
      ELSE project_id = $3
    END
  )
RETURNING id;
