import gleam/option.{None}
import gleam/string
import lustre/element

import scrumbringer_client/capability_scope
import scrumbringer_client/features/views/kanban_board
import scrumbringer_client/i18n/locale as i18n_locale
import scrumbringer_client/theme

fn assert_contains(html: String, text: String) {
  let assert True = string.contains(html, text)
}

pub fn kanban_board_renders_empty_column_texts_test() {
  let config =
    kanban_board.KanbanConfig(
      locale: i18n_locale.En,
      theme: theme.Default,
      cards: [],
      tasks: [],
      task_types: [],
      type_filter: None,
      capability_filter: None,
      search_query: "",
      capability_scope: capability_scope.AllCapabilities,
      my_capability_ids: [],
      org_users: [],
      is_pm_or_admin: False,
      on_card_click: fn(id) { id },
      on_card_edit: fn(id) { id },
      on_card_delete: fn(id) { id },
      on_task_click: fn(id) { id },
      on_task_claim: fn(a, b) { a + b },
      on_create_task_in_card: fn(id) { id },
    )

  let html = kanban_board.view(config) |> element.to_document_string

  assert_contains(html, "kanban-empty-column")
  assert_contains(html, "No cards are waiting for work")
  assert_contains(html, "No active cards need attention")
  assert_contains(html, "Closed cards will appear here")
}
