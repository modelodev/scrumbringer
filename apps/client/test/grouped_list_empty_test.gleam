import gleam/dict
import lustre/element
import support/render_assertions

import scrumbringer_client/features/views/grouped_list
import scrumbringer_client/i18n/locale as i18n_locale
import scrumbringer_client/theme

pub fn grouped_list_renders_empty_state_test() {
  let config =
    grouped_list.GroupedListConfig(
      locale: i18n_locale.En,
      theme: theme.Default,
      tasks: [],
      cards: [],
      org_users: [],
      expanded_cards: dict.new(),
      hide_closed: False,
      on_toggle_card: fn(id) { id },
      on_toggle_hide_closed: 0,
      on_task_click: fn(id) { id },
      on_task_claim: fn(a, b) { a + b },
    )

  let html = grouped_list.view(config) |> element.to_document_string

  render_assertions.contains(html, "No available tasks right now")
}
