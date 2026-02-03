-- name: card_notes_create
-- AC20: Include author email and role for tooltip
with inserted as (
  insert into card_notes (card_id, user_id, content)
  values ($1, $2, $3)
  returning id, card_id, user_id, content, created_at
)
select
  i.id,
  i.card_id,
  i.user_id,
  i.content,
  to_char(i.created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at,
  u.email as author_email,
  coalesce(pm.role, '') as author_project_role,
  u.org_role as author_org_role
from inserted i
join users u on u.id = i.user_id
left join cards c on c.id = i.card_id
left join project_members pm on pm.user_id = i.user_id and pm.project_id = c.project_id;
