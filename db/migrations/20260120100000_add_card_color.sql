-- migrate:up
-- Story 3.4: Add color field to cards for visual identification

ALTER TABLE cards ADD COLUMN color TEXT;

-- Constraint to ensure only valid colors
ALTER TABLE cards ADD CONSTRAINT cards_color_check
    CHECK (color IS NULL OR color IN ('gray', 'red', 'orange', 'yellow', 'green', 'blue', 'purple', 'pink'));

-- migrate:down

ALTER TABLE cards DROP CONSTRAINT cards_color_check;
ALTER TABLE cards DROP COLUMN color;
