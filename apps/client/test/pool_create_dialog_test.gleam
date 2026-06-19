import gleam/option as opt
import gleam/string
import lustre/element

import domain/api_error.{ApiError}
import domain/card.{type Card, Blue, Card, Pendiente}
import domain/milestone.{
  type MilestoneProgress, Milestone, MilestoneProgress, Ready,
}
import domain/remote.{Failed, Loaded, NotAsked}
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
    milestone_id: opt.None,
    title: "Release card",
    description: "",
    color: opt.Some(Blue),
    state: Pendiente,
    task_count: 0,
    completed_count: 0,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    due_date: opt.None,
    has_new_notes: False,
  )
}

fn milestone() -> MilestoneProgress {
  MilestoneProgress(
    milestone: Milestone(
      id: 13,
      project_id: 3,
      name: "Sprint launch",
      description: opt.None,
      state: Ready,
      position: 1,
      created_by: 1,
      created_at: "2026-01-01T00:00:00Z",
      activated_at: opt.None,
      completed_at: opt.None,
    ),
    cards_total: 0,
    cards_completed: 0,
    tasks_total: 0,
    tasks_completed: 0,
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
    milestone_id: opt.None,
    in_flight: False,
    task_types: Loaded([task_type()]),
    milestones: NotAsked,
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

pub fn create_dialog_renders_milestone_target_without_card_selector_test() {
  let html =
    create_dialog.view(
      create_dialog.Config(
        ..config(),
        card_id: opt.None,
        milestone_id: opt.Some(13),
        milestones: Loaded([milestone()]),
      ),
    )
    |> element.to_document_string

  assert_contains(html, "Milestones")
  assert_contains(html, "Sprint launch")
  assert_not_contains(html, "Release card")
}

pub fn create_dialog_falls_back_to_milestone_id_when_name_missing_test() {
  let html =
    create_dialog.view(
      create_dialog.Config(
        ..config(),
        milestone_id: opt.Some(99),
        milestones: Loaded([milestone()]),
      ),
    )
    |> element.to_document_string

  assert_contains(html, "#99")
}
