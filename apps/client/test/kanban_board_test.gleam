import gleam/string
import gleeunit/should
import lustre/element

import scrumbringer_client/features/views/kanban_board
import scrumbringer_client/i18n/locale as i18n_locale
import scrumbringer_client/theme

pub fn kanban_column_headers_show_icons_test() {
  let config =
    kanban_board.KanbanConfig(
      locale: i18n_locale.En,
      theme: theme.Default,
      cards: [],
      tasks: [],
      org_users: [],
      is_pm_or_admin: False,
      on_card_click: fn(id) { id },
      on_card_edit: fn(id) { id },
      on_card_delete: fn(id) { id },
      on_new_card: 0,
      on_task_click: fn(id) { id },
      on_task_claim: fn(a, b) { a + b },
      on_create_task_in_card: fn(id) { id },
    )

  let html = kanban_board.view(config) |> element.to_document_string

  string.contains(html, "kanban-column-icon") |> should.be_true
  string.contains(html, "aria-hidden") |> should.be_true
}
