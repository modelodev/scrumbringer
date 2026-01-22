-- name: delete_all_capability_members
delete from project_member_capabilities
where project_id = $1 and capability_id = $2;
