-- migrate:up
CREATE TABLE capabilities (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  org_id BIGINT NOT NULL REFERENCES organizations(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(name, org_id)
);

CREATE INDEX idx_capabilities_org ON capabilities(org_id);

CREATE TABLE user_capabilities (
  user_id BIGINT NOT NULL REFERENCES users(id),
  capability_id BIGINT NOT NULL REFERENCES capabilities(id),
  PRIMARY KEY (user_id, capability_id)
);

CREATE INDEX idx_user_capabilities_user ON user_capabilities(user_id);

-- migrate:down
DROP INDEX idx_user_capabilities_user;
DROP TABLE user_capabilities;

DROP INDEX idx_capabilities_org;
DROP TABLE capabilities;
