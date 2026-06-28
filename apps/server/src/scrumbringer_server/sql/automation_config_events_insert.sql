insert into automation_config_events (
  org_id,
  project_id,
  actor_user_id,
  entity_type,
  entity_id,
  change_type,
  payload_json,
  created_at
)
values ($1, $2, $3, $4, $5, $6, $7::jsonb, now())
returning id;
