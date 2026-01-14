-- migrate:up
CREATE TABLE org_invite_links (
  token TEXT PRIMARY KEY,
  org_id BIGINT NOT NULL REFERENCES organizations(id),
  email TEXT NOT NULL,
  created_by BIGINT NOT NULL REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  used_at TIMESTAMPTZ,
  used_by BIGINT REFERENCES users(id),
  invalidated_at TIMESTAMPTZ
);

CREATE INDEX idx_org_invite_links_org ON org_invite_links(org_id);
CREATE INDEX idx_org_invite_links_email ON org_invite_links(email);

-- Single active token per (org_id, email)
CREATE UNIQUE INDEX idx_org_invite_links_active_email
  ON org_invite_links(org_id, email)
  WHERE used_at IS NULL AND invalidated_at IS NULL;

-- migrate:down
DROP INDEX idx_org_invite_links_active_email;
DROP INDEX idx_org_invite_links_email;
DROP INDEX idx_org_invite_links_org;
DROP TABLE org_invite_links;
