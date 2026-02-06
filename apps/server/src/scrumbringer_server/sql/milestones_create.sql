-- name: create_milestone
insert into milestones (project_id, name, description, position, created_by)
values (
  $1,
  $2,
  nullif($3, ''),
  coalesce((select max(position) + 1 from milestones where project_id = $1), 0),
  $4
)
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
