-- migrate:up

ALTER TABLE public.audit_events
  ADD COLUMN IF NOT EXISTS card_id BIGINT,
  ADD COLUMN IF NOT EXISTS payload_json JSONB NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE public.audit_events
  ALTER COLUMN task_id DROP NOT NULL;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.audit_events'::regclass
      AND conname = 'audit_events_event_type_check'
  ) THEN
    ALTER TABLE public.audit_events
      DROP CONSTRAINT audit_events_event_type_check;
  END IF;
END $$;

ALTER TABLE public.audit_events
  ADD CONSTRAINT audit_events_event_type_check CHECK (
    event_type IN (
      'task_created',
      'task_claimed',
      'task_released',
      'task_completed',
      'task_done',
      'card_activated',
      'card_closed'
    )
  );

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.audit_events'::regclass
      AND conname = 'audit_events_card_id_fkey'
  ) THEN
    ALTER TABLE public.audit_events
      ADD CONSTRAINT audit_events_card_id_fkey
      FOREIGN KEY (card_id) REFERENCES public.cards(id);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_audit_events_card_created_at
  ON public.audit_events(card_id, created_at);

-- migrate:down

DROP INDEX IF EXISTS public.idx_audit_events_card_created_at;

ALTER TABLE public.audit_events
  DROP CONSTRAINT IF EXISTS audit_events_card_id_fkey;

ALTER TABLE public.audit_events
  DROP CONSTRAINT IF EXISTS audit_events_event_type_check;

ALTER TABLE public.audit_events
  ADD CONSTRAINT audit_events_event_type_check CHECK (
    event_type IN (
      'task_created',
      'task_claimed',
      'task_released',
      'task_completed'
    )
  );

ALTER TABLE public.audit_events
  DROP COLUMN IF EXISTS payload_json,
  DROP COLUMN IF EXISTS card_id;

ALTER TABLE public.audit_events
  ALTER COLUMN task_id SET NOT NULL;
