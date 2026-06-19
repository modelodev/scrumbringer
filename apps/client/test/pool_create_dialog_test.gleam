import gleam/option as opt
import gleam/string
import lustre/element

import domain/api_error.{ApiError}
import domain/card.{type Card, Blue, Card, Draft}
import domain/remote.{Failed, Loaded}
import domain/task_type.{type TaskType, TaskType}
import scrumbringer_client/features/pool/create_dialog
import scrumbringer_client/i18n/locale

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

fn task_type() -> TaskType {
  TaskType(
    id: 5,
    name: "Bug",
    icon: "bug-ant",
    capability_id: opt.None,
    tasks_count: 0,
  )
}

fn card() -> Card {
  Card(
    id: 8,
    project_id: 3,
    parent_card_id: opt.None,
    title: "Release card",
    description: "",
    color: opt.Some(Blue),
    state: Draft,
    task_count: 0,
    completed_count: 0,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    due_date: opt.None,
    has_new_notes: False,
  )
}

fn config() -> create_dialog.Config(String) {
  create_dialog.Config(
    locale: locale.En,
    error: opt.None,
    title: "Fix login",
    description: "OAuth callback",
    priority: "2",
    type_id: "5",
    card_id: opt.Some(8),
    in_flight: False,
    task_types: Loaded([task_type()]),
    cards: [card()],
    on_close: "close",
    on_submit: "submit",
    on_title_changed: fn(value) { "title-" <> value },
    on_description_changed: fn(value) { "description-" <> value },
    on_priority_changed: fn(value) { "priority-" <> value },
    on_type_id_changed: fn(value) { "type-" <> value },
    on_type_options_retry_clicked: "retry",
    on_card_id_changed: fn(value) { "card-" <> value },
  )
}

pub fn create_dialog_renders_form_and_card_selector_without_root_model_test() {
  let html =
    create_dialog.view(config())
    |> element.to_document_string

  assert_contains(html, "New task")
  assert_contains(html, "Fix login")
  assert_contains(html, "OAuth callback")
  assert_contains(html, "Bug")
  assert_contains(html, "Card")
  assert_contains(html, "No card")
  assert_contains(html, "Release card")
  assert_contains(html, "form=\"task-create-form\"")
}

pub fn create_dialog_retry_uses_shared_button_classes_test() {
  let html =
    create_dialog.view(
      create_dialog.Config(
        ..config(),
        task_types: Failed(ApiError(status: 500, code: "ERR", message: "boom")),
      ),
    )
    |> element.to_document_string

  assert_contains(html, "Retry")
  assert_contains(html, "btn-secondary")
  assert_contains(html, "btn-entity-action")
  assert_not_contains(html, "<button type=\"button\">Retry</button>")
}
