-- migrate:up
ALTER TABLE users
DROP CONSTRAINT users_password_for_humans_check,
ADD CONSTRAINT users_password_for_humans_check
  CHECK (
    (user_kind = 'human' AND password_hash IS NOT NULL)
    OR (user_kind = 'integration' AND password_hash IS NULL)
  );

-- migrate:down
ALTER TABLE users
DROP CONSTRAINT users_password_for_humans_check,
ADD CONSTRAINT users_password_for_humans_check
  CHECK (
    (user_kind = 'human' AND password_hash IS NOT NULL)
    OR user_kind = 'integration'
  );
