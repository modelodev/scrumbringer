-- name: delete_capability
delete from capabilities
where id = $1 and project_id = $2
returning id;
