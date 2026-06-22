-- name: card_notes_create
-- AC20: Include author email and role for tooltip
with card_ref as (
  select id, project_id
  from cards
  where id = $1
), inserted_note as (
  insert into notes (project_id, user_id, content)
  select project_id, $2, $3
  from card_ref
  returning id, user_id, content, created_at
), inserted_link as (
  insert into card_notes (note_id, card_id)
  select inserted_note.id, card_ref.id
  from inserted_note
  cross join card_ref
  returning note_id, card_id
)
select
  n.id,
  l.card_id,
  n.user_id,
  n.content,
  to_char(n.created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at,
  u.email as author_email,
  coalesce(pm.role, '') as author_project_role,
  u.org_role as author_org_role
from inserted_note n
join inserted_link l on l.note_id = n.id
join users u on u.id = n.user_id
left join cards c on c.id = l.card_id
left join project_members pm on pm.user_id = n.user_id and pm.project_id = c.project_id;
