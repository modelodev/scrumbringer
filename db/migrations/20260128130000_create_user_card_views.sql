-- migrate:up
CREATE TABLE user_card_views (
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  card_id BIGINT NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
  last_viewed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, card_id)
);

CREATE INDEX idx_user_card_views_card ON user_card_views(card_id);

-- migrate:down
DROP INDEX idx_user_card_views_card;

DROP TABLE user_card_views;
