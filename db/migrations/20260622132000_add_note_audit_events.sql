-- migrate:up

ALTER TABLE public.audit_events
  DROP CONSTRAINT IF EXISTS audit_events_event_type_check,
  DROP CONSTRAINT IF EXISTS audit_events_target_check;

ALTER TABLE public.audit_events
  ADD CONSTRAINT audit_events_event_type_check CHECK (
    event_type IN (
      'task_created',
      'task_claimed',
      'task_released',
      'task_closed',
      'card_activated',
      'card_closed',
      'card_moved',
      'task_dependency_added',
      'task_dependency_removed',
      'note_created',
      'note_pinned',
      'note_unpinned'
    )
  ),
  ADD CONSTRAINT audit_events_target_check CHECK (
    (
      event_type IN (
        'task_created',
        'task_claimed',
        'task_released',
        'task_closed',
        'task_dependency_added',
        'task_dependency_removed',
        'note_created',
        'note_pinned',
        'note_unpinned'
      )
      AND task_id IS NOT NULL
      AND card_id IS NULL
    )
    OR (
      event_type IN (
        'card_activated',
        'card_closed',
        'card_moved',
        'note_created',
        'note_pinned',
        'note_unpinned'
      )
      AND card_id IS NOT NULL
      AND task_id IS NULL
    )
  );

-- migrate:down

DELETE FROM public.audit_events
WHERE event_type IN ('note_created', 'note_pinned', 'note_unpinned');

ALTER TABLE public.audit_events
  DROP CONSTRAINT IF EXISTS audit_events_event_type_check,
  DROP CONSTRAINT IF EXISTS audit_events_target_check;

ALTER TABLE public.audit_events
  ADD CONSTRAINT audit_events_event_type_check CHECK (
    event_type IN (
      'task_created',
      'task_claimed',
      'task_released',
      'task_closed',
      'card_activated',
      'card_closed',
      'card_moved',
      'task_dependency_added',
      'task_dependency_removed'
    )
  ),
  ADD CONSTRAINT audit_events_target_check CHECK (
    (
      event_type IN (
        'task_created',
        'task_claimed',
        'task_released',
        'task_closed',
        'task_dependency_added',
        'task_dependency_removed'
      )
      AND task_id IS NOT NULL
      AND card_id IS NULL
    )
    OR (
      event_type IN ('card_activated', 'card_closed', 'card_moved')
      AND card_id IS NOT NULL
      AND task_id IS NULL
    )
  );
