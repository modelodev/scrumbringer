delete from project_member_capabilities
where project_id = $1 and user_id = $2
returning project_id;
