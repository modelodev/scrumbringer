-- migrate:up
-- Now Working (personal) state for a user.
-- 0..1 active task per user (global).

CREATE TABLE user_now_working (
    user_id BIGINT PRIMARY KEY REFERENCES users(id),
    task_id BIGINT REFERENCES tasks(id),
    project_id BIGINT REFERENCES projects(id),
    started_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_user_now_working_task_id ON user_now_working(task_id);
CREATE INDEX idx_user_now_working_project_id ON user_now_working(project_id);

-- migrate:down
DROP INDEX idx_user_now_working_project_id;
DROP INDEX idx_user_now_working_task_id;
DROP TABLE user_now_working;
