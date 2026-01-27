import gleam/string
import gleeunit/should
import lustre/element

import scrumbringer_client/features/views/kanban_board
import scrumbringer_client/i18n/locale as i18n_locale

pub fn kanban_board_renders_empty_column_texts_test() {
  let config =
    kanban_board.KanbanConfig(
      locale: i18n_locale.En,
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

  string.contains(html, "kanban-empty-column") |> should.be_true
  string.contains(html, "No pending cards") |> should.be_true
  string.contains(html, "No cards in progress") |> should.be_true
  string.contains(html, "No closed cards") |> should.be_true
}
