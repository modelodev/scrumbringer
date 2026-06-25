import gleam/option.{None, Some}

import scrumbringer_client/features/cards/show as card_show
import scrumbringer_client/features/pool/card_show_state

pub fn card_show_opened_sets_selected_card_and_resets_show_model_test() {
  let #(card_show_open, card_show_model) = card_show_state.handle_opened(42)
  let expected = card_show.init_model()

  let assert Some(42) = card_show_open
  let assert True = card_show_model == expected
}

pub fn card_show_closed_clears_selection_and_resets_show_model_test() {
  let #(card_show_open, card_show_model) = card_show_state.handle_closed()
  let expected = card_show.reset()

  let assert None = card_show_open
  let assert True = card_show_model == expected
}
