-- name: user_task_views_upsert
insert into user_task_views (user_id, task_id, last_viewed_at)
values ($1, $2, now())
on conflict (user_id, task_id)
do update set last_viewed_at = excluded.last_viewed_at
returning user_id, task_id, to_char(last_viewed_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as last_viewed_at;
