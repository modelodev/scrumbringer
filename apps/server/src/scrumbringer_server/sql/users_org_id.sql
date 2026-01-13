-- name: user_org_id
select org_id
from users
where id = $1;
