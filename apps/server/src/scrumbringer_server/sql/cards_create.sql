-- name: create_card
INSERT INTO cards (project_id, title, description, color, created_by, milestone_id)
VALUES (
  $1,
  $2,
  $3,
  NULLIF($4, ''),
  $5,
  case when $6 <= 0 then null else $6 end
)
RETURNING
    id,
    project_id,
    title,
    coalesce(description, '') as description,
    coalesce(color, '') as color,
    coalesce(milestone_id, 0) as milestone_id,
    created_by,
    to_char(created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at;
