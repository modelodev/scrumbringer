-- name: task_positions_list_for_user
select
  tp.task_id,
  tp.user_id,
  tp.x,
  tp.y,
  to_char(tp.updated_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as updated_at
from task_positions tp
join tasks t on t.id = tp.task_id
where tp.user_id = $1
  and ($2 = 0 or t.project_id = $2)
  and exists(
    select 1
    from project_members pm
    where pm.project_id = t.project_id
      and pm.user_id = $1
  )
order by tp.task_id asc;
