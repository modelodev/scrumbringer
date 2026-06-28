select org_id
from users
where id = $1
  and deleted_at is null;
