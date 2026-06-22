-- migrate:up

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

CREATE TRIGGER trg_cards_child_kind_invariant
BEFORE INSERT OR UPDATE OF parent_card_id ON public.cards
FOR EACH ROW
EXECUTE FUNCTION public.enforce_card_child_kind_invariant();

CREATE TRIGGER trg_tasks_child_kind_invariant
BEFORE INSERT OR UPDATE OF card_id ON public.tasks
FOR EACH ROW
EXECUTE FUNCTION public.enforce_card_child_kind_invariant();

-- migrate:down

DROP TRIGGER IF EXISTS trg_tasks_child_kind_invariant ON public.tasks;
DROP TRIGGER IF EXISTS trg_cards_child_kind_invariant ON public.cards;
DROP FUNCTION IF EXISTS public.enforce_card_child_kind_invariant();
