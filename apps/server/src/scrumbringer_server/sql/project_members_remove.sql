-- name: remove_project_member
with
  target as (
    select role
    from project_members
    where project_id = $1
      and user_id = $2
  ), admin_count as (
    select count(*)::int as count
    from project_members
    where project_id = $1
      and role = 'admin'
  ), deleted as (
    delete from project_members
    where project_id = $1
      and user_id = $2
      and not (
        (select role from target) = 'admin'
        and (select count from admin_count) = 1
      )
    returning 1 as ok
  )
select
  coalesce((select role from target), '') as target_role,
  (select count from admin_count) as admin_count,
  exists(select 1 from deleted) as removed;
