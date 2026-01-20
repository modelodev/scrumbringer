-- name: create_card
INSERT INTO cards (project_id, title, description, color, created_by)
VALUES ($1, $2, $3, NULLIF($4, ''), $5)
RETURNING
    id,
    project_id,
    title,
    coalesce(description, '') as description,
    coalesce(color, '') as color,
    created_by,
    to_char(created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at;
