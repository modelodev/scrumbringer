-- migrate:up
CREATE TABLE password_resets (
  token TEXT PRIMARY KEY,
  email TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  used_at TIMESTAMPTZ,
  invalidated_at TIMESTAMPTZ
);

CREATE INDEX idx_password_resets_email ON password_resets(email);
CREATE INDEX idx_password_resets_created_at ON password_resets(created_at);

-- Single active token per email
CREATE UNIQUE INDEX idx_password_resets_active_email
  ON password_resets(email)
  WHERE used_at IS NULL AND invalidated_at IS NULL;

-- migrate:down
DROP INDEX idx_password_resets_active_email;
DROP INDEX idx_password_resets_created_at;
DROP INDEX idx_password_resets_email;
DROP TABLE password_resets;
