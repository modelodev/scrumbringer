import gleam/option as opt
import gleam/string
import lustre/element

import domain/card.{Card, Cerrada, Pendiente}
import domain/milestone.{Milestone, MilestoneProgress, Ready}
import domain/remote.{Loaded, NotAsked}
import scrumbringer_client/client_state/admin/cards as admin_cards
import scrumbringer_client/client_state/types as state_types
import scrumbringer_client/features/admin/cards_view
import scrumbringer_client/i18n/locale

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

fn sample_card(id: Int, title: String) {
  Card(
    id: id,
    project_id: 7,
    milestone_id: opt.None,
    title: title,
    description: "",
    color: opt.None,
    state: Pendiente,
    task_count: 1,
    completed_count: 0,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    has_new_notes: False,
  )
}

fn closed_empty_card() {
  Card(
    ..sample_card(9, "Closed Empty"),
    state: Cerrada,
    task_count: 0,
    completed_count: 0,
  )
}

fn sample_milestone_progress() {
  MilestoneProgress(
    milestone: Milestone(
      id: 89,
      project_id: 7,
      name: "Milestone 89",
      description: opt.None,
      state: Ready,
      position: 1,
      created_by: 1,
      created_at: "2026-01-01",
      activated_at: opt.None,
      completed_at: opt.None,
    ),
    cards_total: 0,
    cards_completed: 0,
    tasks_total: 0,
    tasks_completed: 0,
  )
}

fn config(model: admin_cards.Model) -> cards_view.Config(String) {
  cards_view.Config(
    locale: locale.En,
    project_id: 7,
    project_name: "Roadmap",
    model: model,
    milestones: Loaded([sample_milestone_progress()]),
    detail_modal: element.none(),
    on_create_opened: "create-opened",
    on_search_changed: fn(value) { "search:" <> value },
    on_state_filter_changed: fn(value) { "state:" <> value },
    on_show_empty_toggled: "show-empty",
    on_show_completed_toggled: "show-completed",
    on_detail_opened: fn(_) { "detail" },
    on_task_create_opened: fn(_) { "task" },
    on_edit_opened: fn(_) { "edit" },
    on_delete_opened: fn(_) { "delete" },
    on_dialog_closed: "closed",
    on_card_created: fn(_) { "created" },
    on_card_updated: fn(_) { "updated" },
    on_card_deleted: fn(_) { "deleted" },
  )
}

pub fn cards_view_renders_list_from_config_without_root_model_test() {
  let model =
    admin_cards.Model(
      ..admin_cards.default_model(),
      cards: Loaded([sample_card(1, "Playwright Card")]),
    )

  let html =
    cards_view.view(config(model))
    |> element.to_document_string

  assert_contains(html, "Cards - Roadmap")
  assert_contains(html, "Create Card")
  assert_contains(html, "Playwright Card")
  assert_contains(html, "card-detail-open")
  assert_contains(html, "card-edit-btn")
  assert_contains(html, "card-delete-btn")
}

pub fn cards_view_applies_filters_from_local_model_test() {
  let model =
    admin_cards.Model(
      ..admin_cards.default_model(),
      cards: Loaded([sample_card(1, "Visible Card"), closed_empty_card()]),
      cards_search: "visible",
      cards_show_empty: False,
      cards_show_completed: False,
    )

  let html =
    cards_view.view(config(model))
    |> element.to_document_string

  assert_contains(html, "Visible Card")
  assert_not_contains(html, "Closed Empty")
}

pub fn cards_view_renders_crud_dialog_with_milestone_context_test() {
  let model =
    admin_cards.Model(
      ..admin_cards.default_model(),
      cards: NotAsked,
      cards_dialog_mode: opt.Some(state_types.CardDialogCreate),
      cards_create_milestone_id: opt.Some(89),
    )

  let html =
    cards_view.view_crud_dialog(config(model))
    |> element.to_document_string

  assert_contains(html, "card-crud-dialog")
  assert_contains(html, "project-id=\"7\"")
  assert_contains(html, "milestone-id=\"89\"")
  assert_contains(html, "milestone-name=\"Milestone 89\"")
  assert_contains(html, "mode=\"create\"")
}
