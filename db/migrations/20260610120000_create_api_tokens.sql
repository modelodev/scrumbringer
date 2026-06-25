-- migrate:up
ALTER TABLE users
ADD COLUMN user_kind TEXT NOT NULL DEFAULT 'human',
ALTER COLUMN password_hash DROP NOT NULL,
ADD CONSTRAINT users_user_kind_check
  CHECK (user_kind IN ('human', 'integration')),
ADD CONSTRAINT users_password_for_humans_check
  CHECK (
    (user_kind = 'human' AND password_hash IS NOT NULL)
    OR user_kind = 'integration'
  );

CREATE TABLE api_tokens (
  id BIGSERIAL PRIMARY KEY,
  org_id BIGINT NOT NULL REFERENCES organizations(id),
  integration_user_id BIGINT NOT NULL REFERENCES users(id),
  project_id BIGINT REFERENCES projects(id),
  created_by BIGINT NOT NULL REFERENCES users(id),
  name TEXT NOT NULL,
  public_id TEXT NOT NULL UNIQUE,
  token_hash TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_used_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  revoked_at TIMESTAMPTZ,
  CHECK (length(trim(name)) > 0)
);

CREATE TABLE api_token_scopes (
  token_id BIGINT NOT NULL REFERENCES api_tokens(id) ON DELETE CASCADE,
  scope TEXT NOT NULL,
  PRIMARY KEY (token_id, scope),
  CHECK (
    scope IN (
      'projects:read',
      'tasks:read',
      'tasks:write',
      'cards:read',
      'cards:write',
      'notes:read',
      'notes:write'
    )
  )
);

CREATE TABLE api_token_audit_log (
  id BIGSERIAL PRIMARY KEY,
  token_id BIGINT REFERENCES api_tokens(id),
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ip TEXT,
  method TEXT NOT NULL,
  endpoint TEXT NOT NULL,
  status INT NOT NULL
);
