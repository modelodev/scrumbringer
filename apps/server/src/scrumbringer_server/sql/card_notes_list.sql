-- name: card_notes_list
-- AC20: Include author email and role for tooltip
select
  n.id,
  n.card_id,
  n.user_id,
  n.content,
  to_char(n.created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at,
  u.email as author_email,
  coalesce(pm.role, '') as author_project_role,
  u.org_role as author_org_role
from card_notes n
join users u on u.id = n.user_id
left join cards c on c.id = n.card_id
left join project_members pm on pm.user_id = n.user_id and pm.project_id = c.project_id
where n.card_id = $1
order by n.created_at asc, n.id asc;
