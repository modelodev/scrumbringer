-- name: audit_events_insert_card
insert into audit_events (
  org_id,
  project_id,
  card_id,
  actor_user_id,
  event_type,
  created_at
)
values ($1, $2, $3, $4, $5, now())
returning id;
