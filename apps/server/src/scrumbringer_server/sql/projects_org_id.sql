-- name: project_org_id
select org_id
from projects
where id = $1;
