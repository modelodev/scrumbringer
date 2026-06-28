-- AC20: Include author email and role for tooltip
with card_scope as (
  select id, project_id
  from cards
  where id = $1
), inserted_note as (
  insert into notes (project_id, user_id, content, url)
  select project_id, $2, $3, nullif($4, '')
  from card_scope
  returning id, project_id, user_id, content, url, pinned, created_at, updated_at
), inserted_relation as (
  insert into card_notes (note_id, card_id)
  select inserted_note.id, card_scope.id
  from inserted_note, card_scope
  returning note_id, card_id
)
select
  n.id,
  r.card_id,
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
left join cards c on c.id = r.card_id
left join project_members pm on pm.user_id = n.user_id and pm.project_id = c.project_id;
