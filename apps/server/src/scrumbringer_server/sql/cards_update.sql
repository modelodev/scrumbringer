-- name: update_card
UPDATE cards
SET title = $2, description = $3
WHERE id = $1
RETURNING
    id,
    project_id,
    title,
    coalesce(description, '') as description,
    created_by,
    to_char(created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at;
