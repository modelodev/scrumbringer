-- name: capability_is_in_org
select exists(
  select 1
  from capabilities
  where id = $1
    and org_id = $2
) as ok;
