-- name: delete_user_capabilities_for_user
delete from user_capabilities
where user_id = $1
returning user_id;
