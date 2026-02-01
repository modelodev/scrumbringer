-- name: release_all_tasks_for_user
with updated as (
  update tasks
  set
    claimed_by = null,
    claimed_at = null,
    status = 'available',
    version = version + 1
  where project_id = $1
    and claimed_by = $2
    and status = 'claimed'
  returning id
)
select id
from updated;
