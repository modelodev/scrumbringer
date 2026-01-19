-- name: delete_rule
DELETE FROM rules
WHERE id = $1
RETURNING id;
