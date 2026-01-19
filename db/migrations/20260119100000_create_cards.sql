-- migrate:up
-- Story 3.1: Cards (fichas) - containers for related tasks

--------------------------------------------------------------------------------
-- 1. Create cards table
--------------------------------------------------------------------------------

CREATE TABLE cards (
    id BIGSERIAL PRIMARY KEY,
    project_id BIGINT NOT NULL REFERENCES projects(id),
    title TEXT NOT NULL,
    description TEXT,
    created_by BIGINT NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_cards_project ON cards(project_id);

--------------------------------------------------------------------------------
-- 2. Add card_id to tasks table
--------------------------------------------------------------------------------

ALTER TABLE tasks ADD COLUMN card_id BIGINT REFERENCES cards(id);

CREATE INDEX idx_tasks_card ON tasks(card_id);

-- migrate:down

DROP INDEX idx_tasks_card;
ALTER TABLE tasks DROP COLUMN card_id;

DROP INDEX idx_cards_project;
DROP TABLE cards;
