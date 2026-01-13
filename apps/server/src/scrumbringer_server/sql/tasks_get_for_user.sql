-- name: get_task_for_user
select
  t.id,
  t.project_id,
  t.type_id,
  t.title,
  coalesce(t.description, '') as description,
  t.priority,
  t.status,
  t.created_by,
  coalesce(t.claimed_by, 0) as claimed_by,
  coalesce(to_char(t.claimed_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') as claimed_at,
  coalesce(to_char(t.completed_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') as completed_at,
  to_char(t.created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at,
  t.version
from tasks t
where t.id = $1
  and exists(
    select 1
    from project_members pm
    where pm.project_id = t.project_id
      and pm.user_id = $2
  );
