-- name: list_project_member_capabilities
select
  pmc.project_id,
  pmc.user_id,
  pmc.capability_id,
  c.name as capability_name
from project_member_capabilities pmc
join capabilities c on c.id = pmc.capability_id
where pmc.project_id = $1 and pmc.user_id = $2
order by c.name asc;
