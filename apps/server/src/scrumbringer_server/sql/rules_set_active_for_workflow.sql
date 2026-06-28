UPDATE rules
SET active = $2
WHERE workflow_id = $1
RETURNING id;
