-- name: list_org_users
select
  id,
  email,
  org_role,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at
from users
where org_id = $1
  and deleted_at is null
  and ($2 = '' or email ilike ('%' || $2 || '%'))
order by email asc;
