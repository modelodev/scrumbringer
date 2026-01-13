-- name: list_tasks_for_project
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
join task_types tt on tt.id = t.type_id
where t.project_id = $1
  and ($2 = '' or t.status = $2)
  and ($3 = 0 or t.type_id = $3)
  and ($4 = 0 or tt.capability_id = $4)
  and (
    $5 = ''
    or t.title ilike ('%' || $5 || '%')
    or t.description ilike ('%' || $5 || '%')
  )
order by t.created_at desc;
