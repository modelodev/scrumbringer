-- name: capability_is_in_project
select exists(
  select 1
  from capabilities
  where id = $1
    and project_id = $2
) as ok;
