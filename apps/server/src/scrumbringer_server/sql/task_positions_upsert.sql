-- name: task_positions_upsert
insert into task_positions (task_id, user_id, x, y, updated_at)
values ($1, $2, $3, $4, now())
on conflict (task_id, user_id) do update
set x = $3,
    y = $4,
    updated_at = now()
returning
  task_id,
  user_id,
  x,
  y,
  to_char(updated_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as updated_at;
