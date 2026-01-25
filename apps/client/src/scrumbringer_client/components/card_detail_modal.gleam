//// Card Detail Modal Component.
////
//// ## Mission
////
//// Encapsulated Lustre Component for displaying card details and managing
//// task creation within a card context.
////
//// ## Responsibilities
////
//// - Display card header with title, state, progress, description
//// - Fetch and display tasks belonging to a card
//// - Handle "Add Task" form with local state
//// - Emit events to parent for close and task creation
////
//// ## Relations
////
//// - Parent: features/fichas/view.gleam renders this component
//// - API: api/tasks.gleam for creating tasks
//// - API: api/cards.gleam for getting card tasks

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
import lustre/element/html.{button, div, input, label, span, text}
import lustre/event

import domain/api_error.{type ApiError}
import domain/card.{type Card, type CardState, Cerrada, EnCurso, Pendiente}
import domain/task.{type Task}
import domain/task_status.{Available, Completed}
import domain/task_type.{type TaskType}

import scrumbringer_client/api/core.{type ApiResult}
import scrumbringer_client/api/tasks as api_tasks
import scrumbringer_client/i18n/en as i18n_en
import scrumbringer_client/i18n/es as i18n_es
import scrumbringer_client/i18n/locale.{type Locale, En, Es}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/color_picker

// =============================================================================
// Internal Types
// =============================================================================

/// Remote data state for async operations.
pub type Remote(a) {
  NotAsked
  Loading
  Loaded(a)
  Failed(ApiError)
}

/// Internal component model - encapsulated state.
pub type Model {
  Model(
    card_id: Option(Int),
    card: Option(Card),
    locale: Locale,
    project_id: Option(Int),
    tasks: Remote(List(Task)),
    task_types: List(TaskType),
    add_task_open: Bool,
    add_task_title: String,
    add_task_priority: Int,
    add_task_in_flight: Bool,
    add_task_error: Option(String),
  )
}

/// Internal messages - not exposed to parent.
pub type Msg {
  // From attributes/properties
  CardIdReceived(Int)
  CardReceived(Card)
  LocaleReceived(Locale)
  ProjectIdReceived(Int)
  TaskTypesReceived(List(TaskType))
  TasksReceived(List(Task))
  // Internal state
  ToggleAddTaskForm
  TitleInput(String)
  PrioritySelect(Int)
  CancelAddTask
  SubmitAddTask
  TaskCreated(ApiResult(Task))
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
    component.on_attribute_change("project-id", decode_project_id),
    component.on_property_change("card", card_property_decoder()),
    component.on_property_change("task-types", task_types_property_decoder()),
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

fn card_property_decoder() -> Decoder(Msg) {
  use id <- decode.field("id", decode.int)
  use project_id <- decode.field("project_id", decode.int)
  use title <- decode.field("title", decode.string)
  use description <- decode.field("description", decode.string)
  use color <- decode.field("color", decode.optional(decode.string))
  use state <- decode.field("state", card_state_decoder())
  use task_count <- decode.field("task_count", decode.int)
  use completed_count <- decode.field("completed_count", decode.int)
  use created_by <- decode.field("created_by", decode.int)
  use created_at <- decode.field("created_at", decode.string)
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
    )),
  )
}

fn card_state_decoder() -> Decoder(CardState) {
  use state_str <- decode.then(decode.string)
  case state_str {
    "en_curso" -> decode.success(EnCurso)
    "cerrada" -> decode.success(Cerrada)
    _ -> decode.success(Pendiente)
  }
}

fn task_types_property_decoder() -> Decoder(Msg) {
  decode.list(task_type_decoder())
  |> decode.map(TaskTypesReceived)
}

fn tasks_property_decoder() -> Decoder(Msg) {
  decode.list(task_decoder())
  |> decode.map(TasksReceived)
}

fn task_decoder() -> Decoder(Task) {
  use id <- decode.field("id", decode.int)
  use project_id <- decode.field("project_id", decode.int)
  use type_id <- decode.field("type_id", decode.int)
  use task_type <- decode.field("task_type", task_type_inline_decoder())
  use ongoing_by <- decode.optional_field(
    "ongoing_by",
    option.None,
    decode.optional(ongoing_by_decoder()),
  )
  use title <- decode.field("title", decode.string)
  use description <- decode.optional_field(
    "description",
    option.None,
    decode.optional(decode.string),
  )
  use priority <- decode.field("priority", decode.int)
  use status <- decode.field("status", task_status_decoder())
  use work_state <- decode.field("work_state", decode.string)
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

  decode.success(task.Task(
    id: id,
    project_id: project_id,
    type_id: type_id,
    task_type: task_type,
    ongoing_by: ongoing_by,
    title: title,
    description: description,
    priority: priority,
    status: status,
    work_state: work_state_from_string(work_state),
    created_by: created_by,
    claimed_by: claimed_by,
    claimed_at: claimed_at,
    completed_at: completed_at,
    created_at: created_at,
    version: version,
    card_id: card_id,
    card_title: card_title,
    card_color: card_color,
  ))
}

fn task_type_inline_decoder() -> Decoder(task_type.TaskTypeInline) {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use icon <- decode.field("icon", decode.string)
  decode.success(task_type.TaskTypeInline(id: id, name: name, icon: icon))
}

fn ongoing_by_decoder() -> Decoder(task_status.OngoingBy) {
  use user_id <- decode.field("user_id", decode.int)
  decode.success(task_status.OngoingBy(user_id: user_id))
}

fn task_status_decoder() -> Decoder(task_status.TaskStatus) {
  use status_str <- decode.then(decode.string)
  case task_status.parse_task_status(status_str) {
    Ok(s) -> decode.success(s)
    Error(_) -> decode.success(Available)
  }
}

fn work_state_from_string(s: String) -> task_status.WorkState {
  case s {
    "available" -> task_status.WorkAvailable
    "claimed" -> task_status.WorkClaimed
    "ongoing" -> task_status.WorkOngoing
    "completed" -> task_status.WorkCompleted
    _ -> task_status.WorkClaimed
  }
}

fn task_type_decoder() -> Decoder(TaskType) {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use icon <- decode.field("icon", decode.string)
  use capability_id <- decode.optional_field(
    "capability_id",
    option.None,
    decode.optional(decode.int),
  )
  use tasks_count <- decode.optional_field("tasks_count", 0, decode.int)
  decode.success(task_type.TaskType(
    id: id,
    name: name,
    icon: icon,
    capability_id: capability_id,
    tasks_count: tasks_count,
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
      project_id: option.None,
      tasks: NotAsked,
      task_types: [],
      add_task_open: False,
      add_task_title: "",
      add_task_priority: 3,
      add_task_in_flight: False,
      add_task_error: option.None,
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
      Model(..model, card_id: option.Some(id)),
      effect.none(),
    )

    CardReceived(card) -> #(
      Model(..model, card: option.Some(card)),
      effect.none(),
    )

    LocaleReceived(loc) -> #(Model(..model, locale: loc), effect.none())

    ProjectIdReceived(id) -> #(
      Model(..model, project_id: option.Some(id)),
      effect.none(),
    )

    TaskTypesReceived(types) -> #(
      Model(..model, task_types: types),
      effect.none(),
    )

    TasksReceived(tasks) -> #(
      Model(..model, tasks: Loaded(tasks)),
      effect.none(),
    )

    ToggleAddTaskForm -> #(
      Model(..model, add_task_open: !model.add_task_open),
      effect.none(),
    )

    TitleInput(title) -> #(Model(..model, add_task_title: title), effect.none())

    PrioritySelect(priority) -> #(
      Model(..model, add_task_priority: priority),
      effect.none(),
    )

    CancelAddTask -> #(
      Model(
        ..model,
        add_task_open: False,
        add_task_title: "",
        add_task_priority: 3,
        add_task_error: option.None,
      ),
      effect.none(),
    )

    SubmitAddTask -> handle_submit_add_task(model)

    TaskCreated(Ok(_task)) -> #(
      Model(
        ..model,
        add_task_in_flight: False,
        add_task_open: False,
        add_task_title: "",
        add_task_priority: 3,
        add_task_error: option.None,
      ),
      emit_task_created(),
    )

    TaskCreated(Error(err)) -> #(
      Model(
        ..model,
        add_task_in_flight: False,
        add_task_error: option.Some(err.message),
      ),
      effect.none(),
    )

    CloseClicked -> #(model, emit_close_requested())
  }
}

fn handle_submit_add_task(model: Model) -> #(Model, Effect(Msg)) {
  // Guard: already in flight
  case model.add_task_in_flight {
    True -> #(model, effect.none())
    False -> validate_and_submit(model)
  }
}

fn validate_and_submit(model: Model) -> #(Model, Effect(Msg)) {
  let title = string.trim(model.add_task_title)

  // Validate title
  case title == "" {
    True -> #(
      Model(
        ..model,
        add_task_error: option.Some(t(model.locale, i18n_text.TitleRequired)),
      ),
      effect.none(),
    )
    False -> validate_and_submit_with_type(model, title)
  }
}

fn validate_and_submit_with_type(
  model: Model,
  title: String,
) -> #(Model, Effect(Msg)) {
  // Get project_id from card or attribute
  let project_id_opt = case model.card {
    option.Some(c) -> option.Some(c.project_id)
    option.None -> model.project_id
  }

  case project_id_opt {
    option.None -> #(
      Model(
        ..model,
        add_task_error: option.Some(t(
          model.locale,
          i18n_text.SelectProjectFirst,
        )),
      ),
      effect.none(),
    )
    option.Some(project_id) ->
      validate_task_type_and_submit(model, title, project_id)
  }
}

fn validate_task_type_and_submit(
  model: Model,
  title: String,
  project_id: Int,
) -> #(Model, Effect(Msg)) {
  // Get first task type as default
  case list.first(model.task_types) {
    Error(_) -> #(
      Model(
        ..model,
        add_task_error: option.Some(t(model.locale, i18n_text.TypeRequired)),
      ),
      effect.none(),
    )
    Ok(first_type) -> {
      let card_id = case model.card {
        option.Some(c) -> option.Some(c.id)
        option.None -> model.card_id
      }

      let model =
        Model(..model, add_task_in_flight: True, add_task_error: option.None)

      #(
        model,
        api_tasks.create_task_with_card(
          project_id,
          title,
          option.None,
          model.add_task_priority,
          first_type.id,
          card_id,
          TaskCreated,
        ),
      )
    }
  }
}

// =============================================================================
// Effects
// =============================================================================

/// Emit task-created custom event to parent.
fn emit_task_created() -> Effect(Msg) {
  effect.from(fn(_dispatch) { emit_custom_event("task-created", json.null()) })
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
    div([attribute.class("modal-content card-detail " <> border_class)], [
      view_card_header(model, card),
      view_card_tasks_section(model),
    ]),
  ])
}

fn view_card_header(model: Model, card: Card) -> Element(Msg) {
  let state_class = state_to_class(card.state)
  let state_label = state_to_label(model.locale, card.state)
  let progress_pct = case card.task_count {
    0 -> 0
    n -> card.completed_count * 100 / n
  }

  div([attribute.class("card-detail-header")], [
    // Title row with close button
    div([attribute.class("card-detail-title-row")], [
      span([attribute.class("card-detail-title")], [text(card.title)]),
      button(
        [
          attribute.class("btn-icon"),
          event.on_click(CloseClicked),
          attribute.attribute("aria-label", "Close"),
        ],
        [text("\u{2715}")],
      ),
    ]),
    // State and progress
    div([attribute.class("card-detail-meta")], [
      span([attribute.class("card-state-badge " <> state_class)], [
        text(state_label),
      ]),
      span([attribute.class("card-detail-progress-text")], [
        text(
          int.to_string(card.completed_count)
          <> "/"
          <> int.to_string(card.task_count)
          <> " "
          <> t(model.locale, i18n_text.CardTasksCompleted),
        ),
      ]),
    ]),
    // Progress bar
    div([attribute.class("card-detail-progress-bar")], [
      div(
        [
          attribute.class("card-detail-progress-fill"),
          attribute.attribute(
            "style",
            "width: " <> int.to_string(progress_pct) <> "%",
          ),
        ],
        [],
      ),
    ]),
    // Description
    case card.description {
      "" -> element.none()
      desc -> div([attribute.class("card-detail-description")], [text(desc)])
    },
  ])
}

fn view_card_tasks_section(model: Model) -> Element(Msg) {
  let tasks = case model.tasks {
    Loaded(t) -> t
    _ -> []
  }

  div([attribute.class("card-detail-tasks-section")], [
    // Section header with Add button
    div([attribute.class("card-detail-tasks-header")], [
      span([attribute.class("card-detail-tasks-title")], [
        text(t(model.locale, i18n_text.CardTasks)),
      ]),
      button(
        [
          attribute.class("btn btn-sm btn-primary"),
          event.on_click(ToggleAddTaskForm),
        ],
        [text("+ " <> t(model.locale, i18n_text.CardAddTask))],
      ),
    ]),
    // Add task form (if open)
    case model.add_task_open {
      True -> view_add_task_form(model)
      False -> element.none()
    },
    // Loading state
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

fn view_add_task_form(model: Model) -> Element(Msg) {
  div([attribute.class("card-add-task-form")], [
    div([attribute.class("form-group")], [
      label([attribute.for("task-title")], [
        text(t(model.locale, i18n_text.Title)),
      ]),
      input([
        attribute.type_("text"),
        attribute.id("task-title"),
        attribute.class("form-input"),
        attribute.placeholder(t(model.locale, i18n_text.TaskTitlePlaceholder)),
        attribute.value(model.add_task_title),
        event.on_input(TitleInput),
      ]),
    ]),
    div([attribute.class("form-row")], [
      // Task type selector (placeholder)
      div([attribute.class("form-group form-group-half")], [
        label([], [text(t(model.locale, i18n_text.TaskType))]),
        // For now, use a simple text showing default type
        span([attribute.class("form-static")], [text("Feature")]),
      ]),
      // Priority selector
      div([attribute.class("form-group form-group-half")], [
        label([], [text(t(model.locale, i18n_text.Priority))]),
        view_priority_dots(model.add_task_priority),
      ]),
    ]),
    // Error display
    case model.add_task_error {
      option.Some(err) -> div([attribute.class("form-error")], [text(err)])
      option.None -> element.none()
    },
    div([attribute.class("form-actions")], [
      button(
        [
          attribute.class("btn btn-secondary"),
          event.on_click(CancelAddTask),
        ],
        [text(t(model.locale, i18n_text.Cancel))],
      ),
      button(
        [
          attribute.class("btn btn-primary"),
          event.on_click(SubmitAddTask),
          attribute.disabled(
            model.add_task_title == "" || model.add_task_in_flight,
          ),
        ],
        [text(t(model.locale, i18n_text.Create))],
      ),
    ]),
  ])
}

fn view_priority_dots(priority: Int) -> Element(Msg) {
  div(
    [attribute.class("priority-dots")],
    list.range(1, 5)
      |> list.map(fn(p) {
        let active_class = case p <= priority {
          True -> " active"
          False -> ""
        }
        button(
          [
            attribute.class("priority-dot" <> active_class),
            event.on_click(PrioritySelect(p)),
            attribute.attribute("aria-label", "Priority " <> int.to_string(p)),
          ],
          [],
        )
      }),
  )
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

  let claimed_text = case task.claimed_by {
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

fn state_to_class(state: CardState) -> String {
  case state {
    Pendiente -> "card-state-pendiente"
    EnCurso -> "card-state-en_curso"
    Cerrada -> "card-state-cerrada"
  }
}

fn state_to_label(loc: Locale, state: CardState) -> String {
  case state {
    Pendiente -> t(loc, i18n_text.CardStatePendiente)
    EnCurso -> t(loc, i18n_text.CardStateEnCurso)
    Cerrada -> t(loc, i18n_text.CardStateCerrada)
  }
}

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
