-- name: list_org_invite_links
select
  email,
  token,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at,
  coalesce(to_char(used_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') as used_at,
  coalesce(to_char(invalidated_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') as invalidated_at,
  case
    when used_at is not null then 'used'
    when invalidated_at is not null then 'invalidated'
    else 'active'
  end as state
from org_invite_links
where org_id = $1
order by email asc;
