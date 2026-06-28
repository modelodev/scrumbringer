update org_invite_links
set invalidated_at = now()
where org_id = $1
  and email = $2
  and used_at is null
  and invalidated_at is null
returning
  email,
  token,
  case
    when used_at is not null then 'used'
    when invalidated_at is not null then 'invalidated'
    else 'active'
  end as state,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at,
  coalesce(to_char(used_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') as used_at,
  coalesce(to_char(invalidated_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') as invalidated_at;
