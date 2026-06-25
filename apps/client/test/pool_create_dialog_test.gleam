import gleam/option as opt
import gleam/string
import lustre/element

import domain/api_error.{ApiError}
import domain/card.{type Card, type CardPhase, Active, Blue, Card, Closed, Draft}
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
  card_with(8, opt.None, "Release card", Draft)
}

fn card_with(
  id: Int,
  parent_card_id: opt.Option(Int),
  title: String,
  state: CardPhase,
) -> Card {
  Card(
    id: id,
    project_id: 3,
    parent_card_id: parent_card_id,
    title: title,
    description: "",
    color: opt.Some(Blue),
    state: state,
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
  )
}

pub fn create_dialog_renders_contextual_form_without_location_selector_test() {
  let html =
    create_dialog.view(config())
    |> element.to_document_string

  assert_contains(html, "New task")
  assert_contains(html, "Fix login")
  assert_contains(html, "OAuth callback")
  assert_contains(html, "Bug")
  assert_contains(html, "prepared until this card is activated")
  assert_contains(html, "form=\"task-create-form\"")
  assert_contains(html, "id=\"task-create-title\"")
  assert_contains(html, "aria-label=\"Title\"")
  assert_contains(html, "id=\"task-create-description\"")
  assert_contains(html, "aria-label=\"Description\"")
  assert_contains(html, "id=\"task-create-priority\"")
  assert_contains(html, "aria-label=\"Priority\"")
  assert_contains(html, "id=\"task-create-type\"")
  assert_contains(html, "aria-label=\"Type\"")
  assert_not_contains(html, "id=\"task-create-card\"")
  assert_not_contains(html, "No card")
}

pub fn create_dialog_opened_from_pool_explains_root_pool_without_selector_test() {
  let html =
    create_dialog.view(
      create_dialog.Config(..config(), card_id: opt.None, cards: [card()]),
    )
    |> element.to_document_string

  assert_contains(html, "Root Pool task")
  assert_not_contains(html, "id=\"task-create-card\"")
}

pub fn create_dialog_context_hint_uses_spanish_locale_test() {
  let html =
    create_dialog.view(
      create_dialog.Config(
        ..config(),
        locale: locale.Es,
        card_id: opt.Some(10),
        cards: [card_with(10, opt.None, "Activa", Active)],
      ),
    )
    |> element.to_document_string

  assert_contains(html, "Esta tarea")
  assert_contains(html, "Pool al crearse")
  assert_contains(html, "capacidad correspondiente")
  assert_not_contains(html, "This task will enter the Pool")
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

pub fn create_dialog_disables_submit_when_context_card_has_child_cards_test() {
  let parent = card_with(8, opt.None, "Release card", Draft)
  let child = card_with(9, opt.Some(8), "Story group", Draft)
  let html =
    create_dialog.view(
      create_dialog.Config(..config(), card_id: opt.Some(8), cards: [
        parent,
        child,
      ]),
    )
    |> element.to_document_string

  assert_contains(html, "This card already contains child cards")
  assert_contains(html, "disabled")
  assert_not_contains(html, "id=\"task-create-card\"")
}

pub fn create_dialog_disables_submit_when_context_card_is_closed_test() {
  let html =
    create_dialog.view(
      create_dialog.Config(..config(), card_id: opt.Some(10), cards: [
        card_with(10, opt.None, "Archivada", Closed),
      ]),
    )
    |> element.to_document_string

  assert_contains(html, "Closed cards cannot receive new tasks")
  assert_contains(html, "disabled")
  assert_not_contains(html, "id=\"task-create-card\"")
}

pub fn create_dialog_closed_context_uses_spanish_locale_test() {
  let html =
    create_dialog.view(
      create_dialog.Config(
        ..config(),
        locale: locale.Es,
        card_id: opt.Some(10),
        cards: [card_with(10, opt.None, "Archivada", Closed)],
      ),
    )
    |> element.to_document_string

  assert_contains(html, "Las tarjetas cerradas no pueden recibir tareas nuevas")
  assert_contains(html, "disabled")
  assert_not_contains(html, "Closed cards cannot receive new tasks")
}

pub fn create_dialog_keeps_submit_enabled_for_active_leaf_card_test() {
  let html =
    create_dialog.view(
      create_dialog.Config(..config(), card_id: opt.Some(10), cards: [
        card_with(10, opt.None, "Active leaf", Active),
      ]),
    )
    |> element.to_document_string

  assert_contains(html, "This task will enter the Pool")
  assert_not_contains(html, "disabled")
}
