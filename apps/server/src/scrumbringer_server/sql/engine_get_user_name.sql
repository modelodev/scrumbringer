-- name: engine_get_user_name
-- Get user email for variable substitution.
select email as display_name from users where id = $1;
