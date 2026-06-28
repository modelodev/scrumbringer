import gleam/option as opt
import lustre/element
import support/domain_fixtures
import support/render_assertions

import domain/api_error.{ApiError}
import domain/card.{type Card, type CardPhase, Active, Blue, Card, Closed, Draft}
import domain/remote.{Failed, Loaded}
import domain/task_type.{type TaskType}
import scrumbringer_client/features/hierarchy/scope_view
import scrumbringer_client/features/pool/create_dialog
import scrumbringer_client/i18n/locale

fn task_type() -> TaskType {
  domain_fixtures.task_type(5, "Bug")
}

fn card() -> Card {
  card_with(8, opt.None, "Release card", Active)
}

fn depth_names() -> List(scope_view.DepthName) {
  [
    scope_view.DepthName(1, "Initiative", "Initiatives"),
    scope_view.DepthName(2, "Feature", "Features"),
    scope_view.DepthName(3, "Story", "Stories"),
  ]
}

fn card_with(
  id: Int,
  parent_card_id: opt.Option(Int),
  title: String,
  state: CardPhase,
) -> Card {
  Card(
    ..domain_fixtures.card(id, 3, title),
    parent_card_id: parent_card_id,
    color: opt.Some(Blue),
    state: state,
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
    card_query: "",
    in_flight: False,
    task_types: Loaded([task_type()]),
    cards: [card()],
    cards_loading: False,
    cards_error: opt.None,
    depth_names: depth_names(),
    on_close: "close",
    on_submit: "submit",
    on_title_changed: fn(value) { "title-" <> value },
    on_description_changed: fn(value) { "description-" <> value },
    on_priority_changed: fn(value) { "priority-" <> value },
    on_type_id_changed: fn(value) { "type-" <> value },
    on_card_id_changed: fn(value) { "card-" <> value },
    on_card_query_changed: fn(value) { "card-query-" <> value },
    on_type_options_retry_clicked: "retry",
    on_card_options_retry_clicked: "retry-cards",
  )
}

pub fn create_dialog_renders_card_target_field_test() {
  let html =
    create_dialog.view(config())
    |> element.to_document_string

  render_assertions.contains(html, "New task")
  render_assertions.contains(html, "Fix login")
  render_assertions.contains(html, "OAuth callback")
  render_assertions.contains(html, "Bug")
  render_assertions.contains(html, "Active card")
  render_assertions.contains(html, "Release card")
  render_assertions.contains(html, "data-testid=\"task-create-card-search\"")
  render_assertions.contains(html, "form=\"task-create-form\"")
  render_assertions.contains(html, "id=\"task-create-title\"")
  render_assertions.contains(html, "aria-label=\"Title\"")
  render_assertions.contains(html, "id=\"task-create-description\"")
  render_assertions.contains(html, "aria-label=\"Description\"")
  render_assertions.contains(html, "id=\"task-create-priority\"")
  render_assertions.contains(html, "aria-label=\"Priority\"")
  render_assertions.contains(html, "id=\"task-create-type\"")
  render_assertions.contains(html, "aria-label=\"Type\"")
  render_assertions.not_contains(html, "No card")
}

pub fn create_dialog_opened_without_card_requires_card_and_blocks_submit_test() {
  let html =
    create_dialog.view(
      create_dialog.Config(..config(), card_id: opt.None, cards: [card()]),
    )
    |> element.to_document_string

  render_assertions.contains(html, "Choose an active card to create the task")
  render_assertions.contains(
    html,
    "Type to search all active cards in this project.",
  )
  render_assertions.not_contains(
    html,
    "data-testid=\"task-create-card-option\"",
  )
  render_assertions.not_contains(html, "Release card - Story #8")
  render_assertions.contains(html, "disabled")
}

pub fn create_dialog_card_target_search_shows_matching_cards_test() {
  let html =
    create_dialog.view(
      create_dialog.Config(
        ..config(),
        card_id: opt.None,
        card_query: "Release",
        cards: [card()],
      ),
    )
    |> element.to_document_string

  render_assertions.contains(html, "data-testid=\"task-create-card-option\"")
  render_assertions.contains(html, "Release card")
  render_assertions.contains(html, "Initiative #8")
}

pub fn create_dialog_card_target_uses_spanish_locale_test() {
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

  render_assertions.contains(html, "Tarjeta activa")
  render_assertions.contains(html, "Activa")
  render_assertions.not_contains(html, "This task will enter the Pool")
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

  render_assertions.contains(html, "Retry")
  render_assertions.contains(html, "btn-secondary")
  render_assertions.contains(html, "btn-entity-action")
  render_assertions.not_contains(html, "<button type=\"button\">Retry</button>")
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

  render_assertions.contains(html, "This card already contains child cards")
  render_assertions.contains(html, "disabled")
}

pub fn create_dialog_disables_submit_when_context_card_is_closed_test() {
  let html =
    create_dialog.view(
      create_dialog.Config(..config(), card_id: opt.Some(10), cards: [
        card_with(10, opt.None, "Archivada", Closed),
      ]),
    )
    |> element.to_document_string

  render_assertions.contains(html, "Closed cards cannot receive new tasks")
  render_assertions.contains(html, "disabled")
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

  render_assertions.contains(
    html,
    "Las tarjetas cerradas no pueden recibir tareas nuevas",
  )
  render_assertions.contains(html, "disabled")
  render_assertions.not_contains(html, "Closed cards cannot receive new tasks")
}

pub fn create_dialog_keeps_submit_enabled_for_active_leaf_card_test() {
  let html =
    create_dialog.view(
      create_dialog.Config(..config(), card_id: opt.Some(10), cards: [
        card_with(10, opt.None, "Active leaf", Active),
      ]),
    )
    |> element.to_document_string

  render_assertions.contains(html, "Active leaf")
  render_assertions.not_contains(html, "disabled")
}

pub fn create_dialog_disables_submit_when_title_is_missing_even_with_active_card_test() {
  let html =
    create_dialog.view(
      create_dialog.Config(..config(), title: "", card_id: opt.Some(10), cards: [
        card_with(10, opt.None, "Active leaf", Active),
      ]),
    )
    |> element.to_document_string

  render_assertions.contains(html, "Active leaf")
  render_assertions.contains(html, "disabled")
}

pub fn create_dialog_disables_submit_when_type_is_missing_even_with_active_card_test() {
  let html =
    create_dialog.view(
      create_dialog.Config(
        ..config(),
        type_id: "",
        card_id: opt.Some(10),
        cards: [card_with(10, opt.None, "Active leaf", Active)],
      ),
    )
    |> element.to_document_string

  render_assertions.contains(html, "Active leaf")
  render_assertions.contains(html, "disabled")
}
