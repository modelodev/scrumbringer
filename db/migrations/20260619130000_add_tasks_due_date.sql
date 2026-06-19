-- migrate:up

ALTER TABLE tasks
  ADD COLUMN IF NOT EXISTS due_date DATE;

-- migrate:down

-- No-op. The card-tree migration owns this column for fresh databases; this
-- follow-up only repairs environments that applied that migration before HT-11.
