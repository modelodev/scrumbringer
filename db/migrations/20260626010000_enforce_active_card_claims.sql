-- migrate:up

CREATE OR REPLACE FUNCTION public.task_card_claimable(p_card_id bigint)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  WITH RECURSIVE ancestors AS (
    SELECT id, parent_card_id, execution_state
    FROM public.cards
    WHERE id = p_card_id

    UNION ALL

    SELECT parent.id, parent.parent_card_id, parent.execution_state
    FROM public.cards parent
    JOIN ancestors child ON child.parent_card_id = parent.id
  )
  SELECT EXISTS (
    SELECT 1
    FROM ancestors target
    WHERE target.id = p_card_id
      AND target.execution_state = 'active'
  )
  AND NOT EXISTS (
    SELECT 1
    FROM ancestors
    WHERE execution_state = 'closed'
  );
$$;

CREATE TEMP TABLE _invalid_claimed_tasks ON COMMIT DROP AS
WITH RECURSIVE ancestors AS (
  SELECT
    t.id AS task_id,
    t.card_id,
    c.parent_card_id,
    c.execution_state
  FROM public.tasks t
  LEFT JOIN public.cards c ON c.id = t.card_id
  WHERE t.execution_state = 'claimed'

  UNION ALL

  SELECT
    ancestors.task_id,
    parent.id,
    parent.parent_card_id,
    parent.execution_state
  FROM ancestors
  JOIN public.cards parent ON parent.id = ancestors.parent_card_id
)
SELECT
  task_id,
  bool_or(card_id IS NULL) AS missing_card,
  bool_or(execution_state = 'closed') AS closed_lineage,
  NOT bool_or(card_id IS NOT NULL AND execution_state = 'active') AS inactive_target
FROM ancestors
GROUP BY task_id
HAVING
  bool_or(card_id IS NULL)
  OR bool_or(execution_state = 'closed')
  OR NOT bool_or(card_id IS NOT NULL AND execution_state = 'active');

UPDATE public.user_task_work_session session
SET ended_at = now()
FROM _invalid_claimed_tasks invalid
WHERE session.task_id = invalid.task_id
  AND session.ended_at IS NULL;

UPDATE public.tasks task
SET execution_state = 'closed',
    claimed_mode = NULL,
    claimed_by = NULL,
    claimed_at = NULL,
    closed_at = now(),
    closed_by = coalesce(task.claimed_by, task.created_by),
    closed_reason = 'closed_by_ancestor',
    last_entered_pool_at = NULL,
    version = version + 1
FROM _invalid_claimed_tasks invalid
WHERE task.id = invalid.task_id
  AND invalid.closed_lineage = true;

UPDATE public.tasks task
SET execution_state = 'available',
    claimed_mode = NULL,
    claimed_by = NULL,
    claimed_at = NULL,
    closed_at = NULL,
    closed_by = NULL,
    closed_reason = NULL,
    last_entered_pool_at = NULL,
    version = version + 1
FROM _invalid_claimed_tasks invalid
WHERE task.id = invalid.task_id
  AND invalid.closed_lineage = false;

CREATE OR REPLACE FUNCTION public.enforce_claimed_task_active_card()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.execution_state = 'claimed' THEN
    IF NEW.card_id IS NULL THEN
      RAISE EXCEPTION 'claimed task requires an active card'
        USING ERRCODE = '23514',
              CONSTRAINT = 'tasks_claimed_requires_active_card';
    END IF;

    IF NEW.claimed_by IS NULL OR NEW.claimed_at IS NULL THEN
      RAISE EXCEPTION 'claimed task requires claim ownership fields'
        USING ERRCODE = '23514',
              CONSTRAINT = 'tasks_claimed_requires_owner';
    END IF;

    IF NEW.claimed_mode IS NULL
      OR NEW.claimed_mode NOT IN ('taken', 'ongoing')
    THEN
      RAISE EXCEPTION 'claimed task requires a valid claimed_mode'
        USING ERRCODE = '23514',
              CONSTRAINT = 'tasks_claimed_requires_mode';
    END IF;

    IF NOT public.task_card_claimable(NEW.card_id) THEN
      RAISE EXCEPTION 'claimed task card lineage is not claimable'
        USING ERRCODE = '23514',
              CONSTRAINT = 'tasks_claimed_requires_active_card';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tasks_enforce_claimed_active_card ON public.tasks;
CREATE TRIGGER tasks_enforce_claimed_active_card
BEFORE INSERT OR UPDATE OF execution_state, card_id, claimed_by, claimed_at, claimed_mode
ON public.tasks
FOR EACH ROW
EXECUTE FUNCTION public.enforce_claimed_task_active_card();

CREATE OR REPLACE FUNCTION public.card_lineage_has_closed_ancestor(p_card_id bigint)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  WITH RECURSIVE ancestors AS (
    SELECT id, parent_card_id, execution_state
    FROM public.cards
    WHERE id = p_card_id

    UNION ALL

    SELECT parent.id, parent.parent_card_id, parent.execution_state
    FROM public.cards parent
    JOIN ancestors child ON child.parent_card_id = parent.id
  )
  SELECT EXISTS (
    SELECT 1
    FROM ancestors
    WHERE execution_state = 'closed'
  );
$$;

CREATE OR REPLACE FUNCTION public.enforce_card_claimed_descendants_claimable()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  has_claimed_descendant boolean;
BEGIN
  WITH RECURSIVE subtree AS (
    SELECT NEW.id

    UNION ALL

    SELECT child.id
    FROM public.cards child
    JOIN subtree parent ON child.parent_card_id = parent.id
  )
  SELECT EXISTS (
    SELECT 1
    FROM public.tasks task
    JOIN subtree ON subtree.id = task.card_id
    WHERE task.execution_state = 'claimed'
  )
  INTO has_claimed_descendant;

  IF has_claimed_descendant THEN
    IF NEW.execution_state <> 'active' THEN
      RAISE EXCEPTION 'card with claimed descendant tasks must remain active'
        USING ERRCODE = '23514',
              CONSTRAINT = 'cards_claimed_descendants_require_active_lineage';
    END IF;

    IF NEW.parent_card_id IS NOT NULL
      AND public.card_lineage_has_closed_ancestor(NEW.parent_card_id)
    THEN
      RAISE EXCEPTION 'card with claimed descendant tasks cannot move below a closed ancestor'
        USING ERRCODE = '23514',
              CONSTRAINT = 'cards_claimed_descendants_require_active_lineage';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS cards_enforce_claimed_descendants_claimable ON public.cards;
CREATE TRIGGER cards_enforce_claimed_descendants_claimable
BEFORE UPDATE OF execution_state, parent_card_id
ON public.cards
FOR EACH ROW
EXECUTE FUNCTION public.enforce_card_claimed_descendants_claimable();

-- migrate:down

DROP TRIGGER IF EXISTS cards_enforce_claimed_descendants_claimable ON public.cards;
DROP FUNCTION IF EXISTS public.enforce_card_claimed_descendants_claimable();
DROP FUNCTION IF EXISTS public.card_lineage_has_closed_ancestor(bigint);

DROP TRIGGER IF EXISTS tasks_enforce_claimed_active_card ON public.tasks;
DROP FUNCTION IF EXISTS public.enforce_claimed_task_active_card();
DROP FUNCTION IF EXISTS public.task_card_claimable(bigint);
