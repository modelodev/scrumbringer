-- name: milestones_update
update milestones
set
  name = case when $2 = '__unset__' then name else $2 end,
  description = case
    when $3 = '__unset__' then description
    else nullif($3, '')
  end
where id = $1
returning
  id,
  project_id,
  name,
  coalesce(description, '') as description,
  state,
  position,
  created_by,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at,
  coalesce(to_char(activated_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') as activated_at,
  coalesce(to_char(completed_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') as completed_at;
