-- migrate:up
-- Accumulated Now Working time per (user, task), in seconds.

CREATE TABLE user_task_now_working_time (
    user_id BIGINT NOT NULL REFERENCES users(id),
    task_id BIGINT NOT NULL REFERENCES tasks(id),
    accumulated_s BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, task_id),
    CONSTRAINT user_task_now_working_time_accumulated_nonnegative CHECK (accumulated_s >= 0)
);

CREATE INDEX idx_user_task_now_working_time_task_id
    ON user_task_now_working_time(task_id);

-- migrate:down
DROP INDEX idx_user_task_now_working_time_task_id;
DROP TABLE user_task_now_working_time;
