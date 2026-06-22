-- name: task_notes_set_pinned
with updated as (
  update notes n
  set pinned = $3,
      updated_at = now()
  from task_notes tn
  where tn.note_id = n.id
    and tn.task_id = $1
    and n.id = $2
  returning n.id, tn.task_id, n.project_id, n.user_id, n.content, n.url, n.pinned, n.created_at, n.updated_at
)
select
  updated.id,
  updated.task_id,
  updated.project_id,
  updated.user_id,
  updated.content,
  coalesce(updated.url, '') as url,
  updated.pinned,
  to_char(updated.created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at,
  to_char(updated.updated_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as updated_at,
  u.email as author_email,
  coalesce(pm.role, '') as author_project_role,
  u.org_role as author_org_role
from updated
join users u on u.id = updated.user_id
left join project_members pm on pm.user_id = updated.user_id and pm.project_id = updated.project_id;
