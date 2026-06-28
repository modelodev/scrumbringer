-- Get project name for variable substitution.
select name from projects where id = $1;
