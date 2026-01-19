-- migrate:up
-- Story 3.0b: Time tracking with clean sessions model
-- This migration replaces user_now_working + user_task_now_working_time
-- with a proper work sessions model supporting multi-ongoing per user.

--------------------------------------------------------------------------------
-- 1. Create new tables
--------------------------------------------------------------------------------

-- user_task_work_session: source of truth for "ongoing" and time tracking
CREATE TABLE user_task_work_session (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id),
    task_id BIGINT NOT NULL REFERENCES tasks(id),
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_heartbeat_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ended_at TIMESTAMPTZ,                    -- NULL = active session
    ended_reason TEXT,                       -- 'user_pause' | 'stale_timeout' | 'task_completed' | 'task_released'
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- CONSTRAINT: max 1 active session per task (not per user!)
CREATE UNIQUE INDEX idx_work_session_active_task
    ON user_task_work_session(task_id)
    WHERE ended_at IS NULL;

-- Index for user's active sessions
CREATE INDEX idx_work_session_user_active
    ON user_task_work_session(user_id)
    WHERE ended_at IS NULL;

-- Index for stale session cleanup
CREATE INDEX idx_work_session_stale
    ON user_task_work_session(last_heartbeat_at)
    WHERE ended_at IS NULL;

-- user_task_work_total: cache/materialization of accumulated time
CREATE TABLE user_task_work_total (
    user_id BIGINT NOT NULL REFERENCES users(id),
    task_id BIGINT NOT NULL REFERENCES tasks(id),
    accumulated_s INT NOT NULL DEFAULT 0 CHECK (accumulated_s >= 0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, task_id)
);

CREATE INDEX idx_work_total_task_id ON user_task_work_total(task_id);

--------------------------------------------------------------------------------
-- 2. Migrate existing data
--------------------------------------------------------------------------------

-- Migrate accumulated times from old table
INSERT INTO user_task_work_total (user_id, task_id, accumulated_s, updated_at)
SELECT user_id, task_id, accumulated_s, updated_at
FROM user_task_now_working_time;

-- Migrate active sessions from old table (where task_id is not null)
INSERT INTO user_task_work_session (user_id, task_id, started_at, last_heartbeat_at, created_at)
SELECT user_id, task_id, started_at, updated_at, NOW()
FROM user_now_working
WHERE task_id IS NOT NULL AND started_at IS NOT NULL;

--------------------------------------------------------------------------------
-- 3. Drop old tables
--------------------------------------------------------------------------------

DROP INDEX idx_user_task_now_working_time_task_id;
DROP TABLE user_task_now_working_time;

DROP INDEX idx_user_now_working_project_id;
DROP INDEX idx_user_now_working_task_id;
DROP TABLE user_now_working;

-- migrate:down
-- Reverse: recreate old tables, migrate data back, drop new tables

-- Recreate old tables
CREATE TABLE user_now_working (
    user_id BIGINT PRIMARY KEY REFERENCES users(id),
    task_id BIGINT REFERENCES tasks(id),
    project_id BIGINT REFERENCES projects(id),
    started_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_user_now_working_task_id ON user_now_working(task_id);
CREATE INDEX idx_user_now_working_project_id ON user_now_working(project_id);

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

-- Migrate data back (accumulated)
INSERT INTO user_task_now_working_time (user_id, task_id, accumulated_s, updated_at)
SELECT user_id, task_id, accumulated_s, updated_at
FROM user_task_work_total;

-- Migrate active sessions back (only the first active session per user)
INSERT INTO user_now_working (user_id, task_id, started_at, updated_at)
SELECT DISTINCT ON (user_id) user_id, task_id, started_at, last_heartbeat_at
FROM user_task_work_session
WHERE ended_at IS NULL
ORDER BY user_id, started_at;

-- Drop new tables
DROP INDEX idx_work_total_task_id;
DROP TABLE user_task_work_total;

DROP INDEX idx_work_session_stale;
DROP INDEX idx_work_session_user_active;
DROP INDEX idx_work_session_active_task;
DROP TABLE user_task_work_session;
