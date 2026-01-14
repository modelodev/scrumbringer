-- name: upsert_org_invite_link
-- Invalidate any active invite link for email and create a new one.
with invalidated as (
  update org_invite_links
  set invalidated_at = now()
  where org_id = $1
    and email = $2
    and used_at is null
    and invalidated_at is null
  returning 1
),
inserted as (
  insert into org_invite_links (org_id, email, token, created_by)
  values ($1, $2, $3, $4)
  returning email, token, created_at, used_at, invalidated_at
)
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
from inserted
where (select count(*) from invalidated) >= 0;
