-- migrate:up

CREATE TABLE automation_config_events (
  id BIGSERIAL PRIMARY KEY,
  org_id BIGINT NOT NULL REFERENCES organizations(id),
  project_id BIGINT NOT NULL REFERENCES projects(id),
  actor_user_id BIGINT NOT NULL REFERENCES users(id),
  entity_type TEXT NOT NULL CHECK (
    entity_type IN ('engine', 'rule', 'template')
  ),
  entity_id BIGINT NOT NULL,
  change_type TEXT NOT NULL CHECK (
    change_type IN (
      'created',
      'updated',
      'paused',
      'reactivated',
      'deleted',
      'archived'
    )
  ),
  payload_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_automation_config_events_project_created_at
  ON automation_config_events(project_id, created_at);

CREATE INDEX idx_automation_config_events_entity_created_at
  ON automation_config_events(entity_type, entity_id, created_at);

CREATE INDEX idx_automation_config_events_actor_created_at
  ON automation_config_events(actor_user_id, created_at);

-- migrate:down

DROP TABLE IF EXISTS automation_config_events;
