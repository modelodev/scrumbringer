-- name: claim_task
update tasks
set
  claimed_by = $2,
  claimed_at = now(),
  status = 'claimed',
  version = version + 1
where id = $1
  and status = 'available'
  and version = $3
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
  version;
