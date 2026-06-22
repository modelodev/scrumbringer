-- name: create_card
WITH input AS (
  SELECT
    $1::int AS project_id,
    $2::text AS title,
    $3::text AS description,
    NULLIF($4, '')::text AS color,
    $5::int AS created_by,
    CASE WHEN $6 <= 0 THEN NULL ELSE $6 END AS parent_card_id,
    NULLIF($7, '')::date AS due_date
)
INSERT INTO cards (
  project_id,
  title,
  description,
  color,
  created_by,
  parent_card_id,
  due_date
)
SELECT
  project_id,
  title,
  description,
  color,
  created_by,
  parent_card_id,
  due_date
FROM input
WHERE parent_card_id IS NULL
   OR NOT EXISTS (
     SELECT 1
     FROM tasks
     WHERE card_id = parent_card_id
   )
RETURNING
    id,
    project_id,
    title,
    coalesce(description, '') as description,
    coalesce(color, '') as color,
    coalesce(parent_card_id, 0) as parent_card_id,
    created_by,
    to_char(created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at,
    coalesce(to_char(due_date, 'YYYY-MM-DD'), '') as due_date;
