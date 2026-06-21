-- migrate:up

CREATE OR REPLACE FUNCTION public.enforce_card_child_kind_invariant()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_TABLE_NAME = 'cards' THEN
    IF NEW.parent_card_id IS NOT NULL THEN
      IF EXISTS (
        SELECT 1
        FROM public.tasks
        WHERE card_id = NEW.parent_card_id
      ) THEN
        RAISE EXCEPTION 'parent card % already contains tasks', NEW.parent_card_id
          USING ERRCODE = '23514';
      END IF;
    END IF;
  END IF;

  IF TG_TABLE_NAME = 'tasks' THEN
    IF NEW.card_id IS NOT NULL THEN
      IF EXISTS (
        SELECT 1
        FROM public.cards
        WHERE parent_card_id = NEW.card_id
      ) THEN
        RAISE EXCEPTION 'card % already contains child cards', NEW.card_id
          USING ERRCODE = '23514';
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- migrate:down

CREATE OR REPLACE FUNCTION public.enforce_card_child_kind_invariant()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_TABLE_NAME = 'cards' AND NEW.parent_card_id IS NOT NULL THEN
    IF EXISTS (
      SELECT 1
      FROM public.tasks
      WHERE card_id = NEW.parent_card_id
    ) THEN
      RAISE EXCEPTION 'parent card % already contains tasks', NEW.parent_card_id
        USING ERRCODE = '23514';
    END IF;
  END IF;

  IF TG_TABLE_NAME = 'tasks' AND NEW.card_id IS NOT NULL THEN
    IF EXISTS (
      SELECT 1
      FROM public.cards
      WHERE parent_card_id = NEW.card_id
    ) THEN
      RAISE EXCEPTION 'card % already contains child cards', NEW.card_id
        USING ERRCODE = '23514';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;
