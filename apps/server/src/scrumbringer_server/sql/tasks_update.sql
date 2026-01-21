-- name: update_task_claimed_by_user
with updated as (
  update tasks
  set
    title = case when $3 = '__unset__' then title else $3 end,
    description = case when $4 = '__unset__' then description else nullif($4, '') end,
    priority = case when $5 = -1 then priority else $5 end,
    type_id = case when $6 = -1 then type_id else $6 end,
    version = version + 1
  where id = $1
    and claimed_by = $2
    and status = 'claimed'
    and version = $7
  returning
    id,
    project_id,
    type_id,
    title,
    coalesce(description, '') as description,
    priority,
    status,
    created_by,
    coalesce(claimed_by, 0) as claimed_by,
    coalesce(to_char(claimed_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') as claimed_at,
    coalesce(to_char(completed_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') as completed_at,
    to_char(created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at,
    version,
    coalesce(card_id, 0) as card_id
)
select
  updated.*,
  tt.name as type_name,
  tt.icon as type_icon,
  false as is_ongoing,
  0 as ongoing_by_user_id,
  coalesce(c.title, '') as card_title,
  coalesce(c.color, '') as card_color
from updated
join task_types tt on tt.id = updated.type_id
left join cards c on c.id = updated.card_id;
