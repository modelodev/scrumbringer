-- name: create_card
INSERT INTO cards (project_id, title, description, created_by)
VALUES ($1, $2, $3, $4)
RETURNING
    id,
    project_id,
    title,
    coalesce(description, '') as description,
    created_by,
    to_char(created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at;
