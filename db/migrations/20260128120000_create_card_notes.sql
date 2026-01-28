-- migrate:up
CREATE TABLE card_notes (
  id BIGSERIAL PRIMARY KEY,
  card_id BIGINT NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
  user_id BIGINT NOT NULL REFERENCES users(id),
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_card_notes_card ON card_notes(card_id);

-- migrate:down
DROP INDEX idx_card_notes_card;

DROP TABLE card_notes;
