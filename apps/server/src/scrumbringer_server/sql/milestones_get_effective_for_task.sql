-- name: get_effective_milestone_for_task
select
  coalesce(t.milestone_id, c.milestone_id, 0) as milestone_id
from tasks t
left join cards c on c.id = t.card_id
where t.id = $1;
