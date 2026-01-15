-- migrate:up
ALTER TABLE users
ADD COLUMN first_login_at TIMESTAMPTZ;

-- migrate:down
ALTER TABLE users
DROP COLUMN first_login_at;
