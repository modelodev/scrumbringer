-- name: task_events_insert
insert into task_events (
  org_id,
  project_id,
  task_id,
  actor_user_id,
  event_type,
  created_at
)
values ($1, $2, $3, $4, $5, now())
returning id;
