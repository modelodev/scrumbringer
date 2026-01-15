-- migrate:up
CREATE TABLE task_events (
  id BIGSERIAL PRIMARY KEY,
  org_id BIGINT NOT NULL REFERENCES organizations(id),
  project_id BIGINT NOT NULL REFERENCES projects(id),
  task_id BIGINT NOT NULL REFERENCES tasks(id),
  actor_user_id BIGINT NOT NULL REFERENCES users(id),
  event_type TEXT NOT NULL CHECK (
    event_type IN (
      'task_created',
      'task_claimed',
      'task_released',
      'task_completed'
    )
  ),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_task_events_org_created_at ON task_events(org_id, created_at);
CREATE INDEX idx_task_events_project_created_at ON task_events(project_id, created_at);
CREATE INDEX idx_task_events_actor_created_at ON task_events(actor_user_id, created_at);
CREATE INDEX idx_task_events_task_created_at ON task_events(task_id, created_at);

-- migrate:down
DROP INDEX idx_task_events_task_created_at;
DROP INDEX idx_task_events_actor_created_at;
DROP INDEX idx_task_events_project_created_at;
DROP INDEX idx_task_events_org_created_at;

DROP TABLE task_events;
