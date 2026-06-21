import gleam/option.{None}
import gleam/string
import lustre/element

import scrumbringer_client/capability_scope
import scrumbringer_client/client_state/member/pool as member_pool
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
      surface_title: "Kanban",
      surface_purpose: "Card flow by state",
      purpose: kanban_board.ExecutionKanban,
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
      depth_names: [],
      scope_kind: member_pool.PlanScopeLevel,
      selected_depth: None,
      selected_card_id: None,
      card_query: "",
      show_closed: None,
      plan_mode: member_pool.PlanKanban,
      on_plan_mode_change: fn(_value) { 0 },
      on_scope_kind_change: fn(_value) { 0 },
      on_scope_depth_change: fn(_value) { 0 },
      on_scope_card_change: fn(_value) { 0 },
      on_scope_card_search_change: fn(_value) { 0 },
      on_closed_toggled: fn(_value) { 0 },
    )

  let html = kanban_board.view(config) |> element.to_document_string

  assert_contains(html, "kanban-empty-column")
  assert_contains(html, "No cards are waiting for work")
  assert_contains(html, "No active cards need attention")
}
