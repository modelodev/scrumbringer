-- migrate:up
CREATE TABLE task_positions (
  task_id BIGINT NOT NULL REFERENCES tasks(id),
  user_id BIGINT NOT NULL REFERENCES users(id),
  x INT NOT NULL DEFAULT 0,
  y INT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (task_id, user_id)
);

-- migrate:down
DROP TABLE task_positions;
