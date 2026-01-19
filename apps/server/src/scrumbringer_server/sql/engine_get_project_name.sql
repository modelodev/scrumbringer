-- name: engine_get_project_name
-- Get project name for variable substitution.
select name from projects where id = $1;
