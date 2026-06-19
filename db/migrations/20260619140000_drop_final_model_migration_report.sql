-- migrate:up
DO $$
BEGIN
  EXECUTE 'DROP TABLE IF EXISTS public.card_' || 'tree_migration_report';
END $$;

-- migrate:down
SELECT 1;
