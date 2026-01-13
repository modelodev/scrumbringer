-- name: insert_user_capability
insert into user_capabilities (user_id, capability_id)
values ($1, $2)
returning user_id, capability_id;
