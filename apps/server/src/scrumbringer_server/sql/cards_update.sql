UPDATE cards
SET
  title = $2,
  description = $3,
  color = NULLIF($4, ''),
  parent_card_id = case
    when $5 < 0 then parent_card_id
    when $5 = 0 then null
    else $5
  end,
  due_date = NULLIF($6, '')::date
WHERE id = $1
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
