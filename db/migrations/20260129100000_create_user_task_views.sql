-- migrate:up
CREATE TABLE user_task_views (
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  task_id BIGINT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  last_viewed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, task_id)
);

CREATE INDEX idx_user_task_views_task ON user_task_views(task_id);

-- migrate:down
DROP INDEX idx_user_task_views_task;

DROP TABLE user_task_views;
