-- name: task_notes_create
with task_scope as (
  select id, project_id
  from tasks
  where id = $1
), inserted_note as (
  insert into notes (project_id, user_id, content, url)
  select project_id, $2, $3, nullif($4, '')
  from task_scope
  returning id, project_id, user_id, content, url, pinned, created_at, updated_at
), inserted_relation as (
  insert into task_notes (note_id, task_id)
  select inserted_note.id, task_scope.id
  from inserted_note, task_scope
  returning note_id, task_id
)
select
  n.id,
  r.task_id,
  n.project_id,
  n.user_id,
  n.content,
  coalesce(n.url, '') as url,
  n.pinned,
  to_char(n.created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at,
  to_char(n.updated_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as updated_at,
  u.email as author_email,
  coalesce(pm.role, '') as author_project_role,
  u.org_role as author_org_role
from inserted_note n
join inserted_relation r on r.note_id = n.id
join users u on u.id = n.user_id
left join tasks t on t.id = r.task_id
left join project_members pm on pm.user_id = n.user_id and pm.project_id = t.project_id;
