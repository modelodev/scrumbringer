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
//// - Parent: features/fichas/view.gleam renders this component
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

import domain/card.{type Card, type CardNote, CardNote}
import domain/task.{type Task, claimed_by}
import domain/task_state
import domain/task_status.{Available, Completed}

import domain/remote.{type Remote, Failed, Loaded, Loading, NotAsked}
import scrumbringer_client/api/cards as api_cards
import scrumbringer_client/api/core.{type ApiResult}
import scrumbringer_client/api/tasks/decoders as task_decoders
import scrumbringer_client/decoders
import scrumbringer_client/i18n/en as i18n_en
import scrumbringer_client/i18n/es as i18n_es
import scrumbringer_client/i18n/locale.{type Locale, En, Es}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/card_progress
import scrumbringer_client/ui/card_section_header
import scrumbringer_client/ui/card_state
import scrumbringer_client/ui/card_state_badge
import scrumbringer_client/ui/card_tabs
import scrumbringer_client/ui/color_picker
import scrumbringer_client/ui/modal_header
import scrumbringer_client/ui/note_dialog
import scrumbringer_client/ui/notes_list
import scrumbringer_client/ui/tooltips/types as notes_list_types

// =============================================================================
// Internal Types
// =============================================================================

/// Internal component model - encapsulated state.
pub type Model {
  Model(
    card_id: Option(Int),
    card: Option(Card),
    locale: Locale,
    current_user_id: Option(Int),
    project_id: Option(Int),
    can_manage_notes: Bool,
    // AC21: Tab system
    active_tab: card_tabs.Tab,
    notes: Remote(List(CardNote)),
    // Note dialog state
    note_dialog_open: Bool,
    note_content: String,
    note_in_flight: Bool,
    note_error: Option(String),
    tasks: Remote(List(Task)),
  )
}

/// Internal messages - not exposed to parent.
pub type Msg {
  // From attributes/properties
  CardIdReceived(Int)
  CardReceived(Card)
  LocaleReceived(Locale)
  CurrentUserIdReceived(Int)
  ProjectIdReceived(Int)
  CanManageNotesReceived(Bool)
  NotesReceived(ApiResult(List(CardNote)))
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
    component.on_property_change("card", card_property_decoder()),
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
  Ok(LocaleReceived(locale.deserialize(value)))
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

fn card_property_decoder() -> Decoder(Msg) {
  use id <- decode.field("id", decode.int)
  use project_id <- decode.field("project_id", decode.int)
  use title <- decode.field("title", decode.string)
  use description <- decode.field("description", decode.string)
  use color <- decode.field("color", decode.optional(decode.string))
  use state <- decode.field("state", decoders.card_state_decoder())
  use task_count <- decode.field("task_count", decode.int)
  use completed_count <- decode.field("completed_count", decode.int)
  use created_by <- decode.field("created_by", decode.int)
  use created_at <- decode.field("created_at", decode.string)
  use has_new_notes <- decode.optional_field(
    "has_new_notes",
    False,
    decode.bool,
  )
  decode.success(
    CardReceived(card.Card(
      id: id,
      project_id: project_id,
      title: title,
      description: description,
      color: color,
      state: state,
      task_count: task_count,
      completed_count: completed_count,
      created_by: created_by,
      created_at: created_at,
      has_new_notes: has_new_notes,
    )),
  )
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
    task_decoders.task_type_inline_decoder(),
  )
  use ongoing_by <- decode.optional_field(
    "ongoing_by",
    option.None,
    decode.optional(task_decoders.ongoing_by_decoder()),
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
  use version <- decode.field("version", decode.int)
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
    decode.optional(decode.string),
  )
  use blocked_count <- decode.optional_field("blocked_count", 0, decode.int)
  use dependencies <- decode.optional_field(
    "dependencies",
    [],
    decode.list(task_decoders.task_dependency_decoder()),
  )

  let is_ongoing = status_raw == "ongoing"
  let state = case
    task_state.from_db(
      status_raw,
      is_ongoing,
      claimed_by,
      claimed_at,
      completed_at,
    )
  {
    Ok(s) -> s
    Error(_) -> task_state.Available
  }
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
    version: version,
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
      locale: En,
      current_user_id: option.None,
      project_id: option.None,
      can_manage_notes: False,
      // AC21: Default to Tasks tab
      active_tab: card_tabs.TasksTab,
      notes: NotAsked,
      note_dialog_open: False,
      note_content: "",
      note_in_flight: False,
      note_error: option.None,
      tasks: NotAsked,
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
      Model(..model, card_id: option.Some(id), notes: Loading),
      fetch_notes(id),
    )

    CardReceived(card) -> #(
      Model(..model, card: option.Some(card)),
      effect.none(),
    )

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

    NotesReceived(Ok(notes)) -> #(
      Model(..model, notes: Loaded(notes), note_error: option.None),
      effect.none(),
    )

    NotesReceived(Error(err)) -> #(
      Model(..model, notes: Failed(err), note_error: option.Some(err.message)),
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

    // Actions that emit events to parent
    CreateTaskClicked -> #(model, emit_create_task_requested())

    CloseClicked -> #(model, emit_close_requested())
  }
}

fn fetch_notes(card_id: Int) -> Effect(Msg) {
  api_cards.get_card_notes(card_id, NotesReceived)
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
fn emit_create_task_requested() -> Effect(Msg) {
  effect.from(fn(_dispatch) {
    emit_custom_event("create-task-requested", json.null())
  })
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
  let color_opt = color_from_string(card.color)
  let border_class = color_picker.border_class(color_opt)

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
        div([attribute.class("modal-header-block card-detail-header-block")], [
          view_card_header(model, card),
          // AC21: Tab navigation
          card_tabs.view(card_tabs.Config(
            active_tab: model.active_tab,
            notes_count: notes_count,
            has_new_notes: card.has_new_notes,
            labels: card_tabs.Labels(
              tasks: t(model.locale, i18n_text.TabTasks),
              notes: t(model.locale, i18n_text.TabNotes),
            ),
            on_tab_click: TabClicked,
          )),
        ]),
        div([attribute.class("modal-body card-detail-body")], [
          // AC21: Conditional section rendering based on active tab
          case model.active_tab {
            card_tabs.TasksTab -> view_card_tasks_section(model)
            card_tabs.NotesTab -> view_card_notes_section(model)
          },
        ]),
      ],
    ),
    // Note creation dialog (modal within modal)
    case model.note_dialog_open {
      True -> view_note_dialog(model)
      False -> element.none()
    },
  ])
}

fn view_card_header(model: Model, card: Card) -> Element(Msg) {
  let state_label = card_state.label(model.locale, card.state)
  let meta =
    div([attribute.class("card-detail-meta")], [
      card_state_badge.view(card.state, state_label, card_state_badge.Detail),
      card_progress.view(
        card.completed_count,
        card.task_count,
        card_progress.Default,
      ),
    ])

  div([attribute.class("card-detail-header")], [
    modal_header.view_extended(modal_header.ExtendedConfig(
      title: card.title,
      title_element: modal_header.TitleSpan,
      close_position: modal_header.CloseBeforeTitle,
      icon: option.None,
      badges: [],
      meta: option.Some(meta),
      progress: option.None,
      on_close: CloseClicked,
      header_class: "card-detail-header-inner",
      title_row_class: "card-detail-title-row",
      title_class: "card-detail-title",
      title_id: "card-detail-title",
      close_button_class: "modal-close btn-icon",
    )),
    case card.description {
      "" -> element.none()
      desc -> div([attribute.class("card-detail-description")], [text(desc)])
    },
  ])
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

  div([attribute.class("card-detail-notes-section")], [
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
  let current_user_id = option.unwrap(model.current_user_id, 0)
  let is_own_note = user_id == current_user_id
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

fn view_card_tasks_section(model: Model) -> Element(Msg) {
  let tasks = case model.tasks {
    Loaded(task_list) -> task_list
    _ -> []
  }

  div([attribute.class("card-detail-tasks-section")], [
    // Shared section header component (same as Notes tab)
    card_section_header.view(card_section_header.Config(
      title: t(model.locale, i18n_text.CardTasks),
      button_label: "+ " <> t(model.locale, i18n_text.CardAddTask),
      button_disabled: False,
      on_button_click: CreateTaskClicked,
    )),
    // Task list content
    case model.tasks {
      Loading ->
        div([attribute.class("card-tasks-loading")], [
          text(t(model.locale, i18n_text.LoadingEllipsis)),
        ])
      Failed(_) ->
        div([attribute.class("card-tasks-error")], [
          text("Error loading tasks"),
        ])
      _ ->
        case list.is_empty(tasks) {
          True -> view_empty_tasks(model)
          False -> view_task_list(tasks)
        }
    },
  ])
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
  let status_icon = case task.status {
    Completed -> "\u{2705}"
    // green checkmark
    task_status.Claimed(_) -> "\u{1F7E1}"
    // yellow circle
    Available -> "\u{26AA}"
    // white circle
  }

  let claimed_text = case claimed_by(task) {
    option.Some(_id) -> " (claimed)"
    option.None -> ""
  }

  div([attribute.class("card-task-item")], [
    span([attribute.class("card-task-status")], [text(status_icon)]),
    span([attribute.class("card-task-title")], [text(task.title)]),
    span([attribute.class("card-task-info")], [text(claimed_text)]),
  ])
}

// =============================================================================
// Helper Functions
// =============================================================================

/// Convert string color from Card to color_picker.CardColor option.
fn color_from_string(
  color: option.Option(String),
) -> option.Option(color_picker.CardColor) {
  case color {
    option.None -> option.None
    option.Some(c) -> color_picker.string_to_color(c)
  }
}

/// Internal i18n helper - maps locale + key to translated text.
fn t(loc: Locale, key: i18n_text.Text) -> String {
  case loc {
    En -> i18n_en.translate(key)
    Es -> i18n_es.translate(key)
  }
}
