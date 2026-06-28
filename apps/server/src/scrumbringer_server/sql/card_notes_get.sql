-- AC20: Include author email and role for tooltip
select
  n.id,
  cn.card_id,
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
from card_notes cn
join notes n on n.id = cn.note_id
join users u on u.id = n.user_id
left join cards c on c.id = cn.card_id
left join project_members pm on pm.user_id = n.user_id and pm.project_id = c.project_id
where cn.card_id = $1
  and n.id = $2;
