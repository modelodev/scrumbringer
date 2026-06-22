-- migrate:up

UPDATE public.tasks
SET status = CASE
  WHEN execution_state = 'closed' THEN 'completed'
  ELSE execution_state
END
WHERE status IS DISTINCT FROM CASE
  WHEN execution_state = 'closed' THEN 'completed'
  ELSE execution_state
END;

-- migrate:down

DO $$
BEGIN
  RAISE EXCEPTION 'repair_task_legacy_status_sync_is_irreversible';
END $$;
