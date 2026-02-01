-- name: list_project_members
select
  project_members.project_id,
  project_members.user_id,
  project_members.role,
  to_char(project_members.created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at,
  coalesce(count(tasks.id), 0) as claimed_count
from project_members
left join tasks
  on tasks.project_id = project_members.project_id
  and tasks.claimed_by = project_members.user_id
  and tasks.status = 'claimed'
where project_members.project_id = $1
group by
  project_members.project_id,
  project_members.user_id,
  project_members.role,
  project_members.created_at
order by project_members.user_id asc;
