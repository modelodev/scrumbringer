-- name: list_user_capability_ids
select
  uc.capability_id
from user_capabilities uc
join capabilities c on c.id = uc.capability_id
where uc.user_id = $1
  and c.org_id = $2
order by uc.capability_id asc;
