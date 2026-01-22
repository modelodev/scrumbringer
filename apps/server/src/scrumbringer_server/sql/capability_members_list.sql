-- name: list_capability_members
select
  pmc.project_id,
  pmc.capability_id,
  pmc.user_id
from project_member_capabilities pmc
where pmc.project_id = $1 and pmc.capability_id = $2
order by pmc.user_id asc;
