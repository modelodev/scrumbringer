-- migrate:up

ALTER TABLE public.cards
  ADD COLUMN IF NOT EXISTS activation_source_card_id BIGINT;

-- migrate:down

DO $$
BEGIN
  RAISE EXCEPTION 'repair_card_activation_source_card_id_is_irreversible';
END $$;
