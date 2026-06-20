//// Card Detail Modal Component.
////
//// ## Mission
////
//// Encapsulated Lustre Component for displaying card details with tabs
//// for Tasks, Notes, and Activity.
////
//// ## Responsibilities
////
//// - Display card header with title, state, progress, description
//// - Tab navigation (Tasks/Notes/Activity)
//// - Display task list and emit event to open main task dialog
//// - Manage notes: view, add, delete
//// - Emit events to parent for actions (close, create-task)
////
//// ## Relations
////
//// - Parent: features/cards/view.gleam renders this component
//// - API: api/cards.gleam for getting card notes

import gleam/dynamic/decode.{type Decoder}
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string

import lustre
import lustre/attribute
import lustre/component
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html.{div, span, text}
import lustre/event

import domain/card.{type Card, type CardNote, CardNote, Closed, Draft}
import domain/card/card_codec
import domain/metrics.{type CardModalMetrics}
import domain/task.{type Task, claimed_by}
import domain/task/task_codec
import domain/task_state
import domain/task_status.{Available, Done}

import domain/api_error.{type ApiResult}
import domain/remote.{type Remote, Failed, Loaded, Loading, NotAsked}
import scrumbringer_client/api/cards as api_cards
import scrumbringer_client/features/cards/detail_policy
import scrumbringer_client/i18n/en as i18n_en
import scrumbringer_client/i18n/es as i18n_es
import scrumbringer_client/i18n/locale.{type Locale, En, Es}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/badge
import scrumbringer_client/ui/button as ui_button
import scrumbringer_client/ui/card_progress
import scrumbringer_client/ui/card_section_header
import scrumbringer_client/ui/card_state
import scrumbringer_client/ui/card_state_badge
import scrumbringer_client/ui/card_tabs
import scrumbringer_client/ui/detail_metrics
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/modal_header
import scrumbringer_client/ui/note_dialog
import scrumbringer_client/ui/notes_list
import scrumbringer_client/ui/task_color
import scrumbringer_client/ui/task_item
import scrumbringer_client/ui/tooltips/types as notes_list_types

// =============================================================================
// Internal Types
// =============================================================================

/// Internal component model - encapsulated state.
pub type Model {
  Model(
    card_id: Option(Int),
    card: Option(Card),
    cards: List(Card),
    locale: Locale,
    current_user_id: Option(Int),
    project_id: Option(Int),
    can_manage_notes: Bool,
    can_manage_structure: Bool,
    can_execute_work: Bool,
    // AC21: Tab system
    active_tab: card_tabs.Tab,
    notes: Remote(List(CardNote)),
    // Note dialog state
    note_dialog_open: Bool,
    note_content: String,
    note_in_flight: Bool,
    note_error: Option(String),
    tasks: Remote(List(Task)),
    metrics: Remote(CardModalMetrics),
    move_dialog_open: Bool,
    activation_confirm_open: Bool,
  )
}

/// Internal messages - not exposed to parent.
pub type Msg {
  // From attributes/properties
  CardIdReceived(Int)
  CardReceived(Card)
  CardsReceived(List(Card))
  LocaleReceived(Locale)
  CurrentUserIdReceived(Int)
  ProjectIdReceived(Int)
  CanManageNotesReceived(Bool)
  CanManageStructureReceived(Bool)
  CanExecuteWorkReceived(Bool)
  NotesReceived(ApiResult(List(CardNote)))
  CardMetricsReceived(ApiResult(CardModalMetrics))
  TasksReceived(List(Task))
  // AC21: Tab navigation
  TabClicked(card_tabs.Tab)
  // Note dialog
  NoteDialogOpened
  NoteDialogClosed
  NoteContentChanged(String)
  NoteSubmitted
  NoteCreated(ApiResult(CardNote))
  NoteDeleteClicked(Int)
  NoteDeleted(Int, ApiResult(Nil))
  // Card operations
  CreateCardClicked
  ActivateCardClicked
  ActivateCardCancelled
  ActivateCardConfirmed
  MoveDialogOpened
  MoveDialogClosed
  DeleteCardClicked
  // Actions that emit events to parent
  CreateTaskClicked
  CloseClicked
}

// =============================================================================
// Component Registration
// =============================================================================

/// Register the card-detail-modal as a custom element.
/// Call this once at app init. Returns Result to handle registration errors.
pub fn register() -> Result(Nil, lustre.Error) {
  lustre.component(init, update, view, on_attribute_change())
  |> lustre.register("card-detail-modal")
}

/// Build attribute/property change handlers.
fn on_attribute_change() -> List(component.Option(Msg)) {
  [
    component.on_attribute_change("card-id", decode_card_id),
    component.on_attribute_change("locale", decode_locale),
    component.on_attribute_change("current-user-id", decode_current_user_id),
    component.on_attribute_change("project-id", decode_project_id),
    component.on_attribute_change("can-manage-notes", decode_can_manage_notes),
    component.on_attribute_change(
      "can-manage-structure",
      decode_can_manage_structure,
    ),
    component.on_attribute_change("can-execute-work", decode_can_execute_work),
    component.on_property_change("card", card_property_decoder()),
    component.on_property_change("cards", cards_property_decoder()),
    component.on_property_change("tasks", tasks_property_decoder()),
    component.adopt_styles(True),
  ]
}

fn decode_card_id(value: String) -> Result(Msg, Nil) {
  int.parse(value)
  |> result.map(CardIdReceived)
  |> result.replace_error(Nil)
}

fn decode_locale(value: String) -> Result(Msg, Nil) {
  locale.parse(value)
  |> result.map(LocaleReceived)
  |> result.replace_error(Nil)
}

fn decode_project_id(value: String) -> Result(Msg, Nil) {
  int.parse(value)
  |> result.map(ProjectIdReceived)
  |> result.replace_error(Nil)
}

fn decode_current_user_id(value: String) -> Result(Msg, Nil) {
  int.parse(value)
  |> result.map(CurrentUserIdReceived)
  |> result.replace_error(Nil)
}

fn decode_can_manage_notes(value: String) -> Result(Msg, Nil) {
  let enabled = value == "true"
  Ok(CanManageNotesReceived(enabled))
}

fn decode_can_manage_structure(value: String) -> Result(Msg, Nil) {
  let enabled = value == "true"
  Ok(CanManageStructureReceived(enabled))
}

fn decode_can_execute_work(value: String) -> Result(Msg, Nil) {
  let enabled = value == "true"
  Ok(CanExecuteWorkReceived(enabled))
}

fn card_property_decoder() -> Decoder(Msg) {
  card_codec.card_decoder()
  |> decode.map(CardReceived)
}

fn cards_property_decoder() -> Decoder(Msg) {
  decode.list(card_codec.card_decoder())
  |> decode.map(CardsReceived)
}

fn tasks_property_decoder() -> Decoder(Msg) {
  decode.list(task_decoder())
  |> decode.map(TasksReceived)
}

fn task_decoder() -> Decoder(Task) {
  use id <- decode.field("id", decode.int)
  use project_id <- decode.field("project_id", decode.int)
  use type_id <- decode.field("type_id", decode.int)
  use task_type <- decode.field(
    "task_type",
    task_codec.task_type_inline_decoder(),
  )
  use ongoing_by <- decode.optional_field(
    "ongoing_by",
    option.None,
    decode.optional(task_codec.ongoing_by_decoder()),
  )
  use title <- decode.field("title", decode.string)
  use description <- decode.optional_field(
    "description",
    option.None,
    decode.optional(decode.string),
  )
  use priority <- decode.field("priority", decode.int)
  use status_raw <- decode.field("status", decode.string)
  use created_by <- decode.field("created_by", decode.int)
  use claimed_by <- decode.optional_field(
    "claimed_by",
    option.None,
    decode.optional(decode.int),
  )
  use claimed_at <- decode.optional_field(
    "claimed_at",
    option.None,
    decode.optional(decode.string),
  )
  use completed_at <- decode.optional_field(
    "completed_at",
    option.None,
    decode.optional(decode.string),
  )
  use created_at <- decode.field("created_at", decode.string)
  use due_date <- decode.optional_field(
    "due_date",
    option.None,
    decode.optional(decode.string),
  )
  use version <- decode.field("version", decode.int)
  use parent_card_id <- decode.optional_field(
    "parent_card_id",
    option.None,
    decode.optional(decode.int),
  )
  use card_id <- decode.optional_field(
    "card_id",
    option.None,
    decode.optional(decode.int),
  )
  use card_title <- decode.optional_field(
    "card_title",
    option.None,
    decode.optional(decode.string),
  )
  use card_color <- decode.optional_field(
    "card_color",
    option.None,
    card_codec.optional_color_decoder(),
  )
  use blocked_count <- decode.optional_field("blocked_count", 0, decode.int)
  use dependencies <- decode.optional_field(
    "dependencies",
    [],
    decode.list(task_codec.task_dependency_decoder()),
  )

  let is_ongoing = status_raw == "ongoing"
  use state <- decode.then(task_codec.task_state_decoder_from_fields(
    status_raw,
    is_ongoing,
    claimed_by,
    claimed_at,
    completed_at,
  ))
  let status = task_state.to_status(state)
  let work_state = task_state.to_work_state(state)

  decode.success(task.Task(
    id: id,
    project_id: project_id,
    type_id: type_id,
    task_type: task_type,
    ongoing_by: ongoing_by,
    title: title,
    description: description,
    priority: priority,
    state: state,
    status: status,
    work_state: work_state,
    created_by: created_by,
    created_at: created_at,
    due_date: due_date,
    version: version,
    parent_card_id: parent_card_id,
    card_id: card_id,
    card_title: card_title,
    card_color: card_color,
    // Story 5.4: Task notes indicator not used in card detail context
    has_new_notes: False,
    blocked_count: blocked_count,
    dependencies: dependencies,
  ))
}

// =============================================================================
// Init
// =============================================================================

fn init(_: Nil) -> #(Model, Effect(Msg)) {
  #(
    Model(
      card_id: option.None,
      card: option.None,
      cards: [],
      locale: En,
      current_user_id: option.None,
      project_id: option.None,
      can_manage_notes: False,
      can_manage_structure: False,
      can_execute_work: False,
      // AC21: Default to Tasks tab
      active_tab: card_tabs.TasksTab,
      notes: NotAsked,
      note_dialog_open: False,
      note_content: "",
      note_in_flight: False,
      note_error: option.None,
      tasks: NotAsked,
      metrics: NotAsked,
      move_dialog_open: False,
      activation_confirm_open: False,
    ),
    effect.none(),
  )
}

// =============================================================================
// Update
// =============================================================================

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    CardIdReceived(id) -> #(
      Model(..model, card_id: option.Some(id), notes: Loading, metrics: Loading),
      effect.batch([fetch_notes(id), fetch_metrics(id)]),
    )

    CardReceived(card) -> #(
      Model(..model, card: option.Some(card)),
      effect.none(),
    )

    CardsReceived(cards) -> #(Model(..model, cards: cards), effect.none())

    LocaleReceived(loc) -> #(Model(..model, locale: loc), effect.none())

    CurrentUserIdReceived(id) -> #(
      Model(..model, current_user_id: option.Some(id)),
      effect.none(),
    )

    ProjectIdReceived(id) -> #(
      Model(..model, project_id: option.Some(id)),
      effect.none(),
    )

    CanManageNotesReceived(can_manage) -> #(
      Model(..model, can_manage_notes: can_manage),
      effect.none(),
    )

    CanManageStructureReceived(can_manage) -> #(
      Model(..model, can_manage_structure: can_manage),
      effect.none(),
    )

    CanExecuteWorkReceived(can_execute) -> #(
      Model(..model, can_execute_work: can_execute),
      effect.none(),
    )

    NotesReceived(Ok(notes)) -> #(
      Model(..model, notes: Loaded(notes), note_error: option.None),
      effect.none(),
    )

    NotesReceived(Error(err)) -> #(
      Model(..model, notes: Failed(err), note_error: option.Some(err.message)),
      effect.none(),
    )

    CardMetricsReceived(Ok(metrics)) -> #(
      Model(..model, metrics: Loaded(metrics)),
      effect.none(),
    )

    CardMetricsReceived(Error(err)) -> #(
      Model(..model, metrics: Failed(err)),
      effect.none(),
    )

    TasksReceived(tasks) -> #(
      Model(..model, tasks: Loaded(tasks)),
      effect.none(),
    )

    // AC21: Tab navigation
    TabClicked(tab) -> #(Model(..model, active_tab: tab), effect.none())

    // Note dialog
    NoteDialogOpened -> #(
      Model(..model, note_dialog_open: True, note_error: option.None),
      effect.none(),
    )

    NoteDialogClosed -> #(
      Model(
        ..model,
        note_dialog_open: False,
        note_content: "",
        note_error: option.None,
      ),
      effect.none(),
    )

    NoteContentChanged(content) -> #(
      Model(..model, note_content: content, note_error: option.None),
      effect.none(),
    )

    NoteSubmitted -> handle_submit_note(model)

    NoteCreated(Ok(note)) -> #(
      Model(
        ..model,
        note_dialog_open: False,
        note_in_flight: False,
        note_content: "",
        note_error: option.None,
        notes: Loaded(append_note(model.notes, note)),
      ),
      effect.none(),
    )

    NoteCreated(Error(err)) -> #(
      Model(
        ..model,
        note_in_flight: False,
        note_error: option.Some(err.message),
      ),
      effect.none(),
    )

    NoteDeleteClicked(note_id) -> handle_delete_note(model, note_id)

    NoteDeleted(note_id, Ok(_)) -> #(
      Model(
        ..model,
        note_error: option.None,
        notes: Loaded(remove_note(model.notes, note_id)),
      ),
      effect.none(),
    )

    NoteDeleted(_note_id, Error(err)) -> #(
      Model(..model, note_error: option.Some(err.message)),
      effect.none(),
    )

    CreateCardClicked -> #(model, emit_create_card_requested(model.card_id))

    ActivateCardClicked -> #(
      Model(..model, activation_confirm_open: True),
      effect.none(),
    )

    ActivateCardCancelled -> #(
      Model(..model, activation_confirm_open: False),
      effect.none(),
    )

    ActivateCardConfirmed -> #(
      Model(..model, activation_confirm_open: False),
      emit_activate_requested(model.card_id),
    )

    MoveDialogOpened -> #(Model(..model, move_dialog_open: True), effect.none())

    MoveDialogClosed -> #(
      Model(..model, move_dialog_open: False),
      effect.none(),
    )

    DeleteCardClicked -> #(model, emit_delete_card_requested(model.card_id))

    // Actions that emit events to parent
    CreateTaskClicked -> #(model, emit_create_task_requested(model.card_id))

    CloseClicked -> #(model, emit_close_requested())
  }
}

fn fetch_notes(card_id: Int) -> Effect(Msg) {
  api_cards.get_card_notes(card_id, NotesReceived)
}

fn fetch_metrics(card_id: Int) -> Effect(Msg) {
  api_cards.get_card_metrics(card_id, CardMetricsReceived)
}

fn handle_submit_note(model: Model) -> #(Model, Effect(Msg)) {
  case model.note_in_flight {
    True -> #(model, effect.none())
    False -> validate_and_submit_note(model)
  }
}

fn validate_and_submit_note(model: Model) -> #(Model, Effect(Msg)) {
  let content = string.trim(model.note_content)

  case content == "" {
    True -> #(
      Model(
        ..model,
        note_error: option.Some(t(model.locale, i18n_text.ContentRequired)),
      ),
      effect.none(),
    )
    False -> submit_note(model, content)
  }
}

fn submit_note(model: Model, content: String) -> #(Model, Effect(Msg)) {
  case model.card_id {
    option.None -> #(model, effect.none())
    option.Some(card_id) -> #(
      Model(..model, note_in_flight: True, note_error: option.None),
      api_cards.create_card_note(card_id, content, NoteCreated),
    )
  }
}

fn handle_delete_note(model: Model, note_id: Int) -> #(Model, Effect(Msg)) {
  case model.card_id {
    option.None -> #(model, effect.none())
    option.Some(card_id) -> #(
      model,
      api_cards.delete_card_note(card_id, note_id, fn(result) {
        NoteDeleted(note_id, result)
      }),
    )
  }
}

fn append_note(notes: Remote(List(CardNote)), note: CardNote) -> List(CardNote) {
  case notes {
    Loaded(existing) -> list.append(existing, [note])
    _ -> [note]
  }
}

fn remove_note(notes: Remote(List(CardNote)), note_id: Int) -> List(CardNote) {
  case notes {
    Loaded(existing) -> list.filter(existing, fn(note) { note.id != note_id })
    _ -> []
  }
}

// =============================================================================
// Effects
// =============================================================================

/// Emit create-task-requested custom event to parent.
/// The parent will open the main task creation dialog pre-filled with card_id.
fn emit_create_task_requested(card_id: option.Option(Int)) -> Effect(Msg) {
  let detail = case card_id {
    option.Some(id) -> json.object([#("card_id", json.int(id))])
    option.None -> json.null()
  }

  effect.from(fn(_dispatch) {
    emit_custom_event("create-task-requested", detail)
  })
}

/// Emit create-card-requested custom event to parent.
/// The parent will open the card creation dialog with this card as parent.
fn emit_create_card_requested(card_id: option.Option(Int)) -> Effect(Msg) {
  emit_card_id_event("create-card-requested", card_id)
}

/// Emit activate-requested custom event to parent.
/// The parent activates this card subtree and refreshes Pool data.
fn emit_activate_requested(card_id: option.Option(Int)) -> Effect(Msg) {
  emit_card_id_event("activate-requested", card_id)
}

/// Emit delete-card-requested custom event to parent.
/// The parent will open the existing card deletion confirmation.
fn emit_delete_card_requested(card_id: option.Option(Int)) -> Effect(Msg) {
  emit_card_id_event("delete-card-requested", card_id)
}

fn emit_card_id_event(name: String, card_id: option.Option(Int)) -> Effect(Msg) {
  let detail = case card_id {
    option.Some(id) -> json.object([#("card_id", json.int(id))])
    option.None -> json.null()
  }

  effect.from(fn(_dispatch) { emit_custom_event(name, detail) })
}

/// Emit close-requested custom event to parent.
fn emit_close_requested() -> Effect(Msg) {
  effect.from(fn(_dispatch) {
    emit_custom_event("close-requested", json.null())
  })
}

@external(javascript, "../component.ffi.mjs", "emit_custom_event")
fn emit_custom_event(_name: String, _detail: json.Json) -> Nil {
  Nil
}

// =============================================================================
// View
// =============================================================================

fn view(model: Model) -> Element(Msg) {
  case model.card {
    option.None -> element.none()
    option.Some(card) -> view_modal(model, card)
  }
}

fn view_modal(model: Model, card: Card) -> Element(Msg) {
  let border_class = task_color.card_border_class(card.color)

  // AC21: Calculate notes count for tab display
  let notes_count = case model.notes {
    Loaded(notes_list) -> list.length(notes_list)
    _ -> 0
  }

  div([attribute.class("card-detail-modal")], [
    // Backdrop (clicking closes modal)
    div(
      [
        attribute.class("modal-backdrop"),
        event.on_click(CloseClicked),
      ],
      [],
    ),
    // Modal content
    div(
      [
        attribute.class("modal-content card-detail " <> border_class),
        attribute.attribute("role", "dialog"),
        attribute.attribute("aria-modal", "true"),
        attribute.attribute("aria-labelledby", "card-detail-title"),
      ],
      [
        div(
          [
            attribute.class("modal-header-block detail-header-block"),
          ],
          [
            view_card_header(model, card),
            // AC21: Tab navigation
            card_tabs.view(card_tabs.Config(
              active_tab: model.active_tab,
              notes_count: notes_count,
              has_new_notes: card.has_new_notes,
              labels: card_tabs.Labels(
                tasks: t(model.locale, i18n_text.TabTasks),
                notes: t(model.locale, i18n_text.TabNotes),
                metrics: t(model.locale, i18n_text.TabMetrics),
              ),
              on_tab_click: TabClicked,
            )),
          ],
        ),
        div([attribute.class("modal-body card-detail-body")], [
          // AC21: Conditional section rendering based on active tab
          div(
            [
              attribute.class("detail-tabpanel"),
              attribute.attribute("role", "tabpanel"),
              attribute.id(card_tabpanel_id(model.active_tab)),
              attribute.attribute(
                "aria-labelledby",
                card_tab_id(model.active_tab),
              ),
            ],
            [
              case model.active_tab {
                card_tabs.TasksTab -> view_card_tasks_section(model, card)
                card_tabs.NotesTab -> view_card_notes_section(model)
                card_tabs.MetricsTab -> view_card_metrics_section(model)
              },
            ],
          ),
        ]),
      ],
    ),
    // Note creation dialog (modal within modal)
    case model.note_dialog_open {
      True -> view_note_dialog(model)
      False -> element.none()
    },
    case model.activation_confirm_open {
      True -> view_activation_confirm_dialog(model, card)
      False -> element.none()
    },
    case model.move_dialog_open {
      True -> view_move_dialog(model, card)
      False -> element.none()
    },
  ])
}

fn view_activation_confirm_dialog(model: Model, card: Card) -> Element(Msg) {
  div([attribute.class("card-activation-dialog-shell")], [
    div(
      [
        attribute.class("modal-backdrop"),
        event.on_click(ActivateCardCancelled),
      ],
      [],
    ),
    div(
      [
        attribute.class("card-move-dialog"),
        attribute.attribute("role", "dialog"),
        attribute.attribute("aria-modal", "true"),
        attribute.attribute("aria-labelledby", "card-activation-dialog-title"),
        attribute.attribute("data-testid", "card-activation-dialog"),
      ],
      [
        div([attribute.class("card-move-dialog-header")], [
          span(
            [
              attribute.class("card-move-dialog-title"),
              attribute.id("card-activation-dialog-title"),
            ],
            [text(t(model.locale, i18n_text.HierarchyActivationTitle))],
          ),
          ui_button.icon(
            t(model.locale, i18n_text.Close),
            ActivateCardCancelled,
            icons.Close,
            ui_button.Ghost,
            ui_button.EntityAction,
          )
            |> ui_button.with_testid("card-activation-close")
            |> ui_button.view,
        ]),
        div([attribute.class("card-move-dialog-help")], [
          text(t(
            model.locale,
            i18n_text.HierarchyActivationBody(
              affected_card_count(card, model.cards),
              card.task_count,
            ),
          )),
        ]),
        div([attribute.class("card-move-dialog-help")], [
          text(t(model.locale, i18n_text.HierarchyActivationWarning)),
        ]),
        div([attribute.class("dialog-actions")], [
          ui_button.text(
            t(model.locale, i18n_text.Cancel),
            ActivateCardCancelled,
            ui_button.Secondary,
            ui_button.EntityAction,
          )
            |> ui_button.with_testid("card-activation-cancel")
            |> ui_button.view,
          ui_button.icon_text(
            t(model.locale, i18n_text.ActivateHierarchy),
            ActivateCardConfirmed,
            icons.Play,
            ui_button.Primary,
            ui_button.EntityAction,
          )
            |> ui_button.with_testid("card-activation-confirm")
            |> ui_button.view,
        ]),
      ],
    ),
  ])
}

fn affected_card_count(card: Card, cards: List(Card)) -> Int {
  1
  + list.length(
    list.filter(cards, fn(candidate) {
      is_descendant_of(candidate, card, cards)
    }),
  )
}

fn is_descendant_of(candidate: Card, ancestor: Card, cards: List(Card)) -> Bool {
  case candidate.parent_card_id {
    option.Some(parent_id) if parent_id == ancestor.id -> True
    option.Some(parent_id) ->
      case find_card_by_id(cards, parent_id) {
        option.Some(parent) -> is_descendant_of(parent, ancestor, cards)
        option.None -> False
      }
    option.None -> False
  }
}

fn find_card_by_id(cards: List(Card), card_id: Int) -> option.Option(Card) {
  case list.find(cards, fn(card) { card.id == card_id }) {
    Ok(card) -> option.Some(card)
    Error(_) -> option.None
  }
}

fn view_card_header(model: Model, card: Card) -> Element(Msg) {
  let state_label = card_state.label(model.locale, card.state)
  let meta =
    div([attribute.class("detail-meta")], [
      card_state_badge.view(card.state, state_label, card_state_badge.Detail),
      card_progress.view(
        card.completed_count,
        card.task_count,
        card_progress.Default,
      ),
    ])

  div([attribute.class("detail-header")], [
    modal_header.view_extended_with_close_label(
      modal_header.ExtendedConfig(
        title: card.title,
        title_element: modal_header.TitleSpan,
        close_position: modal_header.CloseBeforeTitle,
        icon: option.None,
        badges: [],
        meta: option.Some(meta),
        progress: option.None,
        on_close: CloseClicked,
        header_class: "detail-header",
        title_row_class: "detail-title-row",
        title_class: "detail-title",
        title_id: "card-detail-title",
        close_button_class: "modal-close btn-icon",
      ),
      t(model.locale, i18n_text.Close),
    ),
    case card.description {
      "" -> element.none()
      desc -> div([attribute.class("card-detail-description")], [text(desc)])
    },
    view_card_action_bar(model, card),
  ])
}

fn view_card_action_bar(model: Model, card: Card) -> Element(Msg) {
  let policy = action_policy(model, card)

  div([attribute.class("card-detail-actions")], [
    view_create_card_action(model, policy),
    view_create_task_action(model, policy),
    view_activate_action(model, card),
    view_move_action(model, card),
    view_delete_action(model, policy),
  ])
}

fn view_create_card_action(
  model: Model,
  policy: detail_policy.Policy,
) -> Element(Msg) {
  case policy.can_create_card, policy.create_disabled_reason {
    True, _ ->
      ui_button.icon_text(
        t(model.locale, i18n_text.NewCard),
        CreateCardClicked,
        icons.Plus,
        ui_button.Secondary,
        ui_button.EntityAction,
      )
      |> ui_button.with_testid("card-create-card-action")
      |> ui_button.view
    False, option.Some(reason) ->
      blocked_action(
        t(model.locale, i18n_text.NewCard),
        CreateCardClicked,
        icons.Plus,
        "card-create-card-action",
        disabled_reason_label(model, reason),
      )
    False, option.None -> element.none()
  }
}

fn view_create_task_action(
  model: Model,
  policy: detail_policy.Policy,
) -> Element(Msg) {
  case policy.can_create_task, policy.create_disabled_reason {
    True, _ ->
      ui_button.icon_text(
        t(model.locale, i18n_text.CardAddTask),
        CreateTaskClicked,
        icons.Plus,
        ui_button.Primary,
        ui_button.EntityAction,
      )
      |> ui_button.with_testid("card-create-task-action")
      |> ui_button.view
    False, option.Some(reason) ->
      blocked_action(
        t(model.locale, i18n_text.CardAddTask),
        CreateTaskClicked,
        icons.Plus,
        "card-create-task-action",
        disabled_reason_label(model, reason),
      )
    False, option.None -> element.none()
  }
}

fn view_activate_action(model: Model, card: Card) -> Element(Msg) {
  case card.state, model.can_manage_structure {
    Draft, True ->
      ui_button.icon_text(
        t(model.locale, i18n_text.ActivateHierarchy),
        ActivateCardClicked,
        icons.Play,
        ui_button.Primary,
        ui_button.EntityAction,
      )
      |> ui_button.with_testid("card-activate-action")
      |> ui_button.with_class("hierarchy-activate-btn")
      |> ui_button.view
    Draft, False ->
      blocked_action(
        t(model.locale, i18n_text.ActivateHierarchy),
        ActivateCardClicked,
        icons.Play,
        "card-activate-action",
        t(model.locale, i18n_text.ActivateHierarchyManagerOnly),
      )
    _, _ -> element.none()
  }
}

fn view_move_action(model: Model, card: Card) -> Element(Msg) {
  case card.state == Closed {
    True -> element.none()
    False ->
      ui_button.icon_text(
        t(model.locale, i18n_text.HierarchyMoveTo),
        MoveDialogOpened,
        icons.Return,
        ui_button.Secondary,
        ui_button.EntityAction,
      )
      |> ui_button.with_testid("card-move-action")
      |> ui_button.view
  }
}

fn view_delete_action(
  model: Model,
  policy: detail_policy.Policy,
) -> Element(Msg) {
  case policy.can_delete, policy.delete_disabled_reason {
    True, _ ->
      ui_button.icon_text(
        t(model.locale, i18n_text.DeleteCard),
        DeleteCardClicked,
        icons.Trash,
        ui_button.Danger,
        ui_button.EntityAction,
      )
      |> ui_button.with_testid("card-delete-action")
      |> ui_button.view
    False, option.Some(reason) ->
      blocked_action(
        t(model.locale, i18n_text.DeleteCard),
        DeleteCardClicked,
        icons.Trash,
        "card-delete-action",
        disabled_reason_label(model, reason),
      )
    False, option.None -> element.none()
  }
}

fn disabled_reason_label(
  model: Model,
  reason: detail_policy.DisabledReason,
) -> String {
  case reason {
    detail_policy.ClosedCardCannotReceiveChildren ->
      t(model.locale, i18n_text.CardClosedCannotReceiveChildren)
    detail_policy.CardHasOperationalHistory ->
      t(model.locale, i18n_text.CardHasOperationalHistory)
  }
}

fn blocked_action(
  label: String,
  msg: Msg,
  icon: icons.NavIcon,
  testid: String,
  reason: String,
) -> Element(Msg) {
  ui_button.icon_text(
    label,
    msg,
    icon,
    ui_button.Secondary,
    ui_button.EntityAction,
  )
  |> ui_button.with_blocked_reason(reason)
  |> ui_button.with_testid(testid)
  |> ui_button.with_class("card-detail-action-blocked")
  |> ui_button.view
}

fn view_card_notes_section(model: Model) -> Element(Msg) {
  let notes = case model.notes {
    Loaded(list) -> list
    _ -> []
  }
  let count_label =
    t(model.locale, i18n_text.Notes)
    <> " ("
    <> int.to_string(list.length(notes))
    <> ")"

  div([attribute.class("card-detail-notes-section detail-section")], [
    // Shared section header component (consistent with Tasks tab)
    // Button opens dialog instead of submitting directly
    card_section_header.view(card_section_header.Config(
      title: count_label,
      button_label: "+ " <> t(model.locale, i18n_text.AddNote),
      button_disabled: False,
      on_button_click: NoteDialogOpened,
    )),
    case model.notes {
      Loading ->
        div([attribute.class("card-notes-loading")], [
          text(t(model.locale, i18n_text.LoadingEllipsis)),
        ])
      Failed(err) ->
        div([attribute.class("card-notes-error")], [text(err.message)])
      _ ->
        notes_list.view(
          // Reverse to show newest first (descending chronological order)
          list.map(list.reverse(notes), fn(note) { note_to_view(model, note) }),
          t(model.locale, i18n_text.Delete),
          t(model.locale, i18n_text.DeleteAsAdmin),
          NoteDeleteClicked,
        )
    },
  ])
}

/// Note creation dialog - uses shared note_dialog component (Story 5.4.2).
fn view_note_dialog(model: Model) -> Element(Msg) {
  note_dialog.view(note_dialog.Config(
    title: t(model.locale, i18n_text.AddNote),
    content: model.note_content,
    placeholder: t(model.locale, i18n_text.NotePlaceholder),
    error: model.note_error,
    submit_label: t(model.locale, i18n_text.AddNote),
    submit_disabled: model.note_in_flight || model.note_content == "",
    cancel_label: t(model.locale, i18n_text.Cancel),
    close_label: t(model.locale, i18n_text.Close),
    on_content_change: NoteContentChanged,
    on_submit: NoteSubmitted,
    on_close: NoteDialogClosed,
  ))
}

fn note_to_view(model: Model, note: CardNote) -> notes_list.NoteView {
  let CardNote(
    id: id,
    user_id: user_id,
    content: content,
    created_at: created_at,
    author_email: author_email,
    author_project_role: author_project_role,
    author_org_role: author_org_role,
    ..,
  ) = note
  let is_own_note = note_belongs_to_current_user(model.current_user_id, user_id)
  let author_label = case is_own_note {
    True -> t(model.locale, i18n_text.You)
    False -> t(model.locale, i18n_text.UserNumber(user_id))
  }
  let can_delete = model.can_manage_notes || is_own_note
  let delete_context = case is_own_note {
    True -> notes_list_types.DeleteOwnNote
    False -> notes_list_types.DeleteAsAdmin
  }

  notes_list.NoteView(
    id: id,
    author: author_label,
    created_at: created_at,
    content: content,
    can_delete: can_delete,
    delete_context: delete_context,
    author_email: author_email,
    author_project_role: author_project_role,
    author_org_role: author_org_role,
  )
}

fn note_belongs_to_current_user(
  current_user_id: Option(Int),
  note_user_id: Int,
) -> Bool {
  case current_user_id {
    option.Some(user_id) -> user_id == note_user_id
    option.None -> False
  }
}

fn view_card_tasks_section(model: Model, card: Card) -> Element(Msg) {
  let tasks = case model.tasks {
    Loaded(task_list) -> task_list
    _ -> []
  }
  let policy = action_policy(model, card)

  div([attribute.class("card-detail-tasks-section detail-section")], [
    view_tasks_header(model, policy),
    // Task list content
    case model.tasks {
      Loading ->
        div([attribute.class("card-tasks-loading")], [
          text(t(model.locale, i18n_text.LoadingEllipsis)),
        ])
      Failed(_) ->
        div([attribute.class("card-tasks-error")], [
          text(t(model.locale, i18n_text.ErrorLoadingTasks)),
        ])
      _ ->
        case list.is_empty(tasks) {
          True -> view_empty_tasks(model)
          False -> view_task_list(tasks)
        }
    },
  ])
}

fn view_tasks_header(model: Model, policy: detail_policy.Policy) -> Element(Msg) {
  case policy.can_create_task, policy.create_disabled_reason {
    True, _ ->
      card_section_header.view(card_section_header.Config(
        title: t(model.locale, i18n_text.CardTasks),
        button_label: "+ " <> t(model.locale, i18n_text.CardAddTask),
        button_disabled: False,
        on_button_click: CreateTaskClicked,
      ))
    False, option.Some(_reason) ->
      card_section_header.view(card_section_header.Config(
        title: t(model.locale, i18n_text.CardTasks),
        button_label: "+ " <> t(model.locale, i18n_text.CardAddTask),
        button_disabled: True,
        on_button_click: CreateTaskClicked,
      ))
    False, option.None ->
      div([attribute.class("card-section-header")], [
        span([attribute.class("card-section-title")], [
          text(t(model.locale, i18n_text.CardTasks)),
        ]),
      ])
  }
}

fn view_empty_tasks(model: Model) -> Element(Msg) {
  div([attribute.class("card-tasks-empty")], [
    span([attribute.class("card-tasks-empty-text")], [
      text(t(model.locale, i18n_text.CardTasksEmpty)),
    ]),
  ])
}

fn view_task_list(tasks: List(Task)) -> Element(Msg) {
  div([attribute.class("card-task-list")], list.map(tasks, view_task_item))
}

fn view_task_item(task: Task) -> Element(Msg) {
  task_item.view(
    task_item.Config(
      container_class: "card-task-item detail-item-row",
      content_class: "card-task-content",
      leading: option.Some(view_task_status(task)),
      on_click: option.None,
      content_title: option.None,
      content_label: option.None,
      icon: option.None,
      icon_class: option.None,
      title: task.title,
      title_class: option.Some("card-task-title"),
      secondary: view_task_claim_status(task),
      actions: task_item.no_actions(),
      reserve_actions_slot: False,
      action_slot_class: option.None,
      testid: option.None,
    ),
    task_item.Div,
  )
}

fn view_task_status(task: Task) -> Element(Msg) {
  let status_icon = case task.status {
    Done -> "\u{2705}"
    task_status.Claimed(_) -> "\u{1F7E1}"
    Available -> "\u{26AA}"
  }

  span([attribute.class("card-task-status")], [text(status_icon)])
}

fn view_task_claim_status(task: Task) -> Element(Msg) {
  let claimed_text = case claimed_by(task) {
    option.Some(_id) -> " (claimed)"
    option.None -> ""
  }

  span([attribute.class("card-task-info")], [text(claimed_text)])
}

fn view_move_dialog(model: Model, card: Card) -> Element(Msg) {
  let destinations = detail_policy.move_destinations(card, model.cards)

  div([attribute.class("card-move-dialog-shell")], [
    div(
      [attribute.class("modal-backdrop"), event.on_click(MoveDialogClosed)],
      [],
    ),
    div(
      [
        attribute.class("card-move-dialog"),
        attribute.attribute("role", "dialog"),
        attribute.attribute("aria-modal", "true"),
        attribute.attribute("aria-labelledby", "card-move-dialog-title"),
        attribute.attribute("data-testid", "card-move-dialog"),
      ],
      [
        div([attribute.class("card-move-dialog-header")], [
          span(
            [
              attribute.class("card-move-dialog-title"),
              attribute.id("card-move-dialog-title"),
            ],
            [text(t(model.locale, i18n_text.HierarchyMoveTo))],
          ),
          ui_button.icon(
            t(model.locale, i18n_text.Close),
            MoveDialogClosed,
            icons.Close,
            ui_button.Ghost,
            ui_button.EntityAction,
          )
            |> ui_button.with_testid("card-move-close")
            |> ui_button.view,
        ]),
        div([attribute.class("card-move-dialog-help")], [
          text(
            "Only same-level destinations that accept child cards are listed.",
          ),
        ]),
        case list.is_empty(destinations) {
          True ->
            div([attribute.class("card-move-empty")], [
              text("No valid same-level destinations are available."),
            ])
          False ->
            div(
              [attribute.class("card-move-options")],
              list.map(destinations, view_move_destination),
            )
        },
        view_invalid_move_examples(card, model.cards, destinations),
      ],
    ),
  ])
}

fn view_move_destination(destination: Card) -> Element(Msg) {
  div(
    [
      attribute.class("card-move-option"),
      attribute.attribute("data-testid", "card-move-option"),
    ],
    [
      span([attribute.class("card-move-option-title")], [
        text(destination.title),
      ]),
    ],
  )
}

fn view_invalid_move_examples(
  card: Card,
  cards: List(Card),
  destinations: List(Card),
) -> Element(Msg) {
  let destination_ids =
    list.map(destinations, fn(destination) { destination.id })
  let invalid =
    cards
    |> list.filter(fn(candidate) {
      candidate.project_id == card.project_id
      && candidate.id != card.id
      && !list.contains(destination_ids, candidate.id)
    })

  case list.is_empty(invalid) {
    True -> element.none()
    False ->
      div(
        [attribute.class("card-move-invalid-list")],
        list.map(invalid, fn(candidate) {
          div(
            [
              attribute.class("card-move-invalid"),
              attribute.attribute("data-testid", "card-move-invalid"),
            ],
            [
              span([attribute.class("card-move-invalid-title")], [
                text(candidate.title),
              ]),
              span([attribute.class("card-move-invalid-reason")], [
                text(detail_policy.invalid_move_explanation(
                  card,
                  candidate,
                  cards,
                )),
              ]),
            ],
          )
        }),
      )
  }
}

fn action_policy(model: Model, card: Card) -> detail_policy.Policy {
  let tasks = case model.tasks {
    Loaded(task_list) -> task_list
    _ -> []
  }

  detail_policy.policy_for(
    card,
    detail_policy.direct_child_cards(card, model.cards),
    tasks,
    model.can_manage_structure,
    model.can_execute_work,
  )
}

fn view_card_metrics_section(model: Model) -> Element(Msg) {
  case model.metrics {
    NotAsked | Loading ->
      div([attribute.class("card-metrics-loading")], [
        text(t(model.locale, i18n_text.LoadingMetrics)),
      ])

    Failed(_err) ->
      div([attribute.class("card-metrics-error")], [
        text(t(model.locale, i18n_text.MetricsLoadError)),
      ])

    Loaded(metrics) ->
      case metrics.tasks_total == 0 {
        True ->
          div([attribute.class("card-metrics-empty")], [
            text(t(model.locale, i18n_text.MetricsEmptyState)),
          ])
        False ->
          div([attribute.class("card-metrics-grid")], [
            div([attribute.class("card-detail-progress-bar")], [
              div(
                [
                  attribute.class("card-detail-progress-fill"),
                  attribute.attribute(
                    "style",
                    "--progress-width: "
                      <> int.to_string(metrics.tasks_percent)
                      <> "%",
                  ),
                ],
                [],
              ),
            ]),
            detail_metrics.view_row(
              t(model.locale, i18n_text.MetricsTasksTotal),
              int.to_string(metrics.tasks_total),
            ),
            detail_metrics.view_row(
              t(model.locale, i18n_text.MetricsTasksDone),
              int.to_string(metrics.tasks_completed),
            ),
            detail_metrics.view_row(
              t(model.locale, i18n_text.MetricsProgress),
              int.to_string(metrics.tasks_percent) <> "%",
            ),
            detail_metrics.view_row(
              t(model.locale, i18n_text.MetricsAvailable),
              int.to_string(metrics.tasks_available),
            ),
            detail_metrics.view_row(
              t(model.locale, i18n_text.MetricsClaimed),
              int.to_string(metrics.tasks_claimed),
            ),
            detail_metrics.view_row(
              t(model.locale, i18n_text.MetricsOngoing),
              int.to_string(metrics.tasks_ongoing),
            ),
            div([attribute.class("assignments-metrics")], [
              badge.quick(
                t(model.locale, i18n_text.MetricsAvailable)
                  <> ": "
                  <> int.to_string(metrics.tasks_available),
                badge.Neutral,
              ),
              badge.quick(
                t(model.locale, i18n_text.MetricsClaimed)
                  <> ": "
                  <> int.to_string(metrics.tasks_claimed),
                badge.Primary,
              ),
              badge.quick(
                t(model.locale, i18n_text.MetricsOngoing)
                  <> ": "
                  <> int.to_string(metrics.tasks_ongoing),
                badge.Warning,
              ),
              badge.quick(
                t(model.locale, i18n_text.MetricsTasksDone)
                  <> ": "
                  <> int.to_string(metrics.tasks_completed),
                badge.Success,
              ),
            ]),
            detail_metrics.view_row(
              t(model.locale, i18n_text.MetricsRebotesAvg),
              int.to_string(metrics.health.avg_rebotes),
            ),
            detail_metrics.view_row(
              t(model.locale, i18n_text.MetricsPoolLifetimeAvg),
              detail_metrics.format_duration_s(
                metrics.health.avg_pool_lifetime_s,
              ),
            ),
            detail_metrics.view_row(
              t(model.locale, i18n_text.MetricsAvgExecutors),
              int.to_string(metrics.health.avg_executors),
            ),
            detail_metrics.view_row(
              t(model.locale, i18n_text.MetricsMostActivated),
              metrics.most_activated
                |> metrics_text_or_not_available(model),
            ),
            detail_metrics.view_workflows(
              t(model.locale, i18n_text.MetricsWorkflows),
              t(model.locale, i18n_text.MetricsNotAvailable),
              metrics.workflows,
            ),
          ])
      }
  }
}

fn metrics_text_or_not_available(value: Option(String), model: Model) -> String {
  case value {
    option.Some(text) -> text
    option.None -> t(model.locale, i18n_text.MetricsNotAvailable)
  }
}

fn card_tabpanel_id(tab: card_tabs.Tab) -> String {
  case tab {
    card_tabs.TasksTab -> "modal-tabpanel-0"
    card_tabs.NotesTab -> "modal-tabpanel-1"
    card_tabs.MetricsTab -> "modal-tabpanel-2"
  }
}

fn card_tab_id(tab: card_tabs.Tab) -> String {
  case tab {
    card_tabs.TasksTab -> "modal-tab-0"
    card_tabs.NotesTab -> "modal-tab-1"
    card_tabs.MetricsTab -> "modal-tab-2"
  }
}

// =============================================================================
// Helper Functions
// =============================================================================

/// Internal i18n helper - maps locale + key to translated text.
fn t(loc: Locale, key: i18n_text.Text) -> String {
  case loc {
    En -> i18n_en.translate(key)
    Es -> i18n_es.translate(key)
  }
}
