-- name: delete_project_member_capability
delete from project_member_capabilities
where project_id = $1 and user_id = $2 and capability_id = $3
returning project_id;
