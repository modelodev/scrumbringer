-- migrate:up
CREATE TABLE users (
  id BIGSERIAL PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  org_id BIGINT NOT NULL REFERENCES organizations(id),
  org_role TEXT NOT NULL DEFAULT 'member' CHECK (org_role IN ('member', 'admin')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- migrate:down
DROP TABLE users;
