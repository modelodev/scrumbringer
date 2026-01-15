-- migrate:up
-- Enforce short titles (UX): max 56 chars

-- Truncate existing data to satisfy the new constraint.
UPDATE tasks
SET title = left(title, 56)
WHERE char_length(title) > 56;

ALTER TABLE tasks
ADD CONSTRAINT tasks_title_max_56
CHECK (char_length(title) <= 56);

-- migrate:down
ALTER TABLE tasks
DROP CONSTRAINT tasks_title_max_56;
