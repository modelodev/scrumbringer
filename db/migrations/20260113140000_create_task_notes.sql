-- migrate:up
CREATE TABLE task_notes (
  id BIGSERIAL PRIMARY KEY,
  task_id BIGINT NOT NULL REFERENCES tasks(id),
  user_id BIGINT NOT NULL REFERENCES users(id),
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_task_notes_task ON task_notes(task_id);

-- migrate:down
DROP INDEX idx_task_notes_task;

DROP TABLE task_notes;
