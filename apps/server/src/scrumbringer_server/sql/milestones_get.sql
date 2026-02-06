-- name: get_milestone
select
  m.id,
  m.project_id,
  m.name,
  coalesce(m.description, '') as description,
  m.state,
  m.position,
  m.created_by,
  to_char(m.created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at,
  coalesce(to_char(m.activated_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') as activated_at,
  coalesce(to_char(m.completed_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') as completed_at
from milestones m
where m.id = $1;
