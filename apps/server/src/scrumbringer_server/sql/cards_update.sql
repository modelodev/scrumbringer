-- name: update_card
UPDATE cards
SET
  title = $2,
  description = $3,
  color = NULLIF($4, ''),
  milestone_id = case
    when $5 < 0 then milestone_id
    when $5 = 0 then null
    else $5
  end
WHERE id = $1
RETURNING
    id,
    project_id,
    title,
    coalesce(description, '') as description,
    coalesce(color, '') as color,
    coalesce(milestone_id, 0) as milestone_id,
    created_by,
    to_char(created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at;
