import gleam/option.{None, Some}

import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/components/card_show
import scrumbringer_client/features/pool/card_detail

fn default_pool() -> member_pool.Model {
  member_pool.default_model()
}

pub fn card_detail_opened_sets_selected_card_and_resets_detail_model_test() {
  let pool = card_detail.handle_opened(default_pool(), 42)
  let expected = card_show.init_model()

  let assert Some(42) = pool.card_detail_open
  let assert True = pool.card_show_model == expected
}

pub fn card_detail_closed_clears_selection_and_resets_detail_model_test() {
  let pool = member_pool.Model(..default_pool(), card_detail_open: Some(42))

  let next = card_detail.handle_closed(pool)
  let expected = card_show.reset()

  let assert None = next.card_detail_open
  let assert True = next.card_show_model == expected
}
