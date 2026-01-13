-- migrate:up
CREATE TABLE org_invites (
  code TEXT PRIMARY KEY,
  org_id BIGINT NOT NULL REFERENCES organizations(id),
  created_by BIGINT NOT NULL REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  used_at TIMESTAMPTZ,
  used_by BIGINT REFERENCES users(id)
);

CREATE INDEX idx_org_invites_org ON org_invites(org_id);
CREATE INDEX idx_org_invites_used_at ON org_invites(used_at);

-- migrate:down
DROP INDEX idx_org_invites_used_at;
DROP INDEX idx_org_invites_org;
DROP TABLE org_invites;
