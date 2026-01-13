-- name: is_project_member
select exists(
  select 1
  from project_members
  where project_id = $1
    and user_id = $2
) as is_member;
