-- name: delete_task_template
DELETE FROM task_templates
WHERE id = $1
  AND org_id = $2
RETURNING id;
