-- name: insert_project_member_capability
insert into project_member_capabilities (project_id, user_id, capability_id)
values ($1, $2, $3)
returning project_id, user_id, capability_id;
