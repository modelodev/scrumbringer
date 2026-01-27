//// Task Type CRUD Dialog Component.
////
//// ## Mission
////
//// Encapsulated Lustre Component for task type create, edit, and delete dialogs.
//// Story 4.9 AC12-14: Full CRUD for task types.
////
//// ## Responsibilities
////
//// - Handle create dialog: name, icon fields
//// - Handle edit dialog: prefill from task type, submit updates
//// - Handle delete confirmation dialog (with warning if tasks exist)
//// - Emit events to parent for type-created, type-updated, type-deleted
////
//// ## Relations
////
//// - Parent: features/admin/view.gleam renders this component
//// - API: api/tasks/task_types.gleam for CRUD operations

import gleam/dynamic/decode.{type Decoder}
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

import lustre
import lustre/attribute
import lustre/component
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html.{
  button, div, form, h3, input, label, option as html_option, p, select, span,
  text,
}
import lustre/event

import domain/api_error.{type ApiError}
import domain/capability.{type Capability, Capability}
import domain/task_type.{type TaskType, TaskType}

import scrumbringer_client/api/core.{type ApiResult}
import scrumbringer_client/api/tasks/task_types as api_task_types
import scrumbringer_client/components/crud_dialog_base
import scrumbringer_client/i18n/en as i18n_en
import scrumbringer_client/i18n/es as i18n_es
import scrumbringer_client/i18n/locale.{type Locale, En, Es}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/icon_catalog

// =============================================================================
// Internal Types
// =============================================================================

/// Dialog mode determines which view to show.
pub type DialogMode {
  ModeCreate
  ModeEdit(TaskType)
  ModeDelete(TaskType)
}

/// Internal component model.
pub type Model {
  Model(
    // Attributes from parent
    locale: Locale,
    project_id: Option(Int),
    mode: Option(DialogMode),
    capabilities: List(Capability),
    // Create dialog fields
    create_name: String,
    create_icon: String,
    create_icon_open: Bool,
    create_capability_id: Option(Int),
    create_in_flight: Bool,
    create_error: Option(String),
    // Edit dialog fields
    edit_name: String,
    edit_icon: String,
    edit_icon_open: Bool,
    edit_capability_id: Option(Int),
    edit_in_flight: Bool,
    edit_error: Option(String),
    // Delete dialog fields
    delete_in_flight: Bool,
    delete_error: Option(String),
  )
}

/// Internal messages - not exposed to parent.
pub type Msg {
  // Attribute/property changes
  LocaleReceived(Locale)
  ProjectIdReceived(Int)
  ModeReceived(DialogMode)
  CapabilitiesReceived(List(Capability))
  // Create form
  CreateNameChanged(String)
  CreateIconToggle
  CreateIconChanged(String)
  CreateCapabilityChanged(Option(Int))
  CreateSubmitted
  CreateResult(ApiResult(TaskType))
  // Edit form
  EditNameChanged(String)
  EditIconToggle
  EditIconChanged(String)
  EditCapabilityChanged(Option(Int))
  EditSubmitted
  EditResult(ApiResult(TaskType))
  EditCancelled
  // Delete confirmation
  DeleteConfirmed
  DeleteResult(ApiResult(Int))
  DeleteCancelled
  // Close dialog
  CloseRequested
}

// =============================================================================
// Component Registration
// =============================================================================

/// Register the task-type-crud-dialog as a custom element.
pub fn register() -> Result(Nil, lustre.Error) {
  lustre.component(init, update, view, on_attribute_change())
  |> lustre.register("task-type-crud-dialog")
}

/// Build attribute/property change handlers.
fn on_attribute_change() -> List(component.Option(Msg)) {
  [
    component.on_attribute_change("locale", decode_locale),
    component.on_attribute_change("project-id", decode_project_id),
    component.on_attribute_change("mode", decode_mode),
    component.on_property_change("task-type", task_type_property_decoder()),
    component.on_property_change("capabilities", capabilities_property_decoder()),
    component.adopt_styles(True),
  ]
}

fn decode_locale(value: String) -> Result(Msg, Nil) {
  crud_dialog_base.decode_locale(value, LocaleReceived)
}

fn decode_project_id(value: String) -> Result(Msg, Nil) {
  crud_dialog_base.decode_int_attribute(value, ProjectIdReceived)
}

fn decode_mode(value: String) -> Result(Msg, Nil) {
  crud_dialog_base.decode_create_mode(value, ModeCreate, ModeReceived)
}

fn task_type_property_decoder() -> Decoder(Msg) {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use icon <- decode.field("icon", decode.string)
  use capability_id <- decode.optional_field(
    "capability_id",
    None,
    decode.optional(decode.int),
  )
  use tasks_count <- decode.optional_field("tasks_count", 0, decode.int)
  use mode <- decode.field("_mode", decode.string)
  let task_type =
    TaskType(
      id: id,
      name: name,
      icon: icon,
      capability_id: capability_id,
      tasks_count: tasks_count,
    )
  case mode {
    "edit" -> decode.success(ModeReceived(ModeEdit(task_type)))
    "delete" -> decode.success(ModeReceived(ModeDelete(task_type)))
    _ -> decode.success(ModeReceived(ModeEdit(task_type)))
  }
}

fn capabilities_property_decoder() -> Decoder(Msg) {
  decode.list(capability_decoder())
  |> decode.map(CapabilitiesReceived)
}

fn capability_decoder() -> Decoder(Capability) {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  decode.success(Capability(id: id, name: name))
}

// =============================================================================
// Init
// =============================================================================

fn init(_: Nil) -> #(Model, Effect(Msg)) {
  #(default_model(), effect.none())
}

fn default_model() -> Model {
  Model(
    locale: En,
    project_id: None,
    mode: None,
    capabilities: [],
    create_name: "",
    create_icon: "clipboard-document-list",
    create_icon_open: False,
    create_capability_id: None,
    create_in_flight: False,
    create_error: None,
    edit_name: "",
    edit_icon: "clipboard-document-list",
    edit_icon_open: False,
    edit_capability_id: None,
    edit_in_flight: False,
    edit_error: None,
    delete_in_flight: False,
    delete_error: None,
  )
}

// =============================================================================
// Update
// =============================================================================

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    LocaleReceived(loc) -> #(Model(..model, locale: loc), effect.none())

    ProjectIdReceived(id) -> #(
      Model(..model, project_id: Some(id)),
      effect.none(),
    )

    ModeReceived(mode) -> handle_mode_received(model, mode)

    CapabilitiesReceived(caps) -> #(
      Model(..model, capabilities: caps),
      effect.none(),
    )

    // Create form handlers
    CreateNameChanged(name) -> #(
      Model(..model, create_name: name),
      effect.none(),
    )

    CreateIconToggle -> #(
      Model(..model, create_icon_open: !model.create_icon_open),
      effect.none(),
    )

    CreateIconChanged(icon) -> #(
      Model(..model, create_icon: icon, create_icon_open: False),
      effect.none(),
    )

    CreateCapabilityChanged(cap_id) -> #(
      Model(..model, create_capability_id: cap_id),
      effect.none(),
    )

    CreateSubmitted -> handle_create_submitted(model)

    CreateResult(Ok(task_type)) -> handle_create_success(model, task_type)

    CreateResult(Error(err)) -> #(
      Model(..model, create_in_flight: False, create_error: Some(err.message)),
      effect.none(),
    )

    // Edit form handlers
    EditNameChanged(name) -> #(Model(..model, edit_name: name), effect.none())

    EditIconToggle -> #(
      Model(..model, edit_icon_open: !model.edit_icon_open),
      effect.none(),
    )

    EditIconChanged(icon) -> #(
      Model(..model, edit_icon: icon, edit_icon_open: False),
      effect.none(),
    )

    EditCapabilityChanged(cap_id) -> #(
      Model(..model, edit_capability_id: cap_id),
      effect.none(),
    )

    EditSubmitted -> handle_edit_submitted(model)

    EditResult(Ok(task_type)) -> handle_edit_success(model, task_type)

    EditResult(Error(err)) -> #(
      Model(..model, edit_in_flight: False, edit_error: Some(err.message)),
      effect.none(),
    )

    EditCancelled -> #(reset_edit_fields(model), emit_close_requested())

    // Delete handlers
    DeleteConfirmed -> handle_delete_confirmed(model)

    DeleteResult(Ok(_)) -> handle_delete_success(model)

    DeleteResult(Error(err)) -> handle_delete_error(model, err)

    DeleteCancelled -> #(reset_delete_fields(model), emit_close_requested())

    CloseRequested -> #(model, emit_close_requested())
  }
}

fn handle_mode_received(model: Model, mode: DialogMode) -> #(Model, Effect(Msg)) {
  case mode {
    ModeCreate -> #(
      Model(
        ..model,
        mode: Some(ModeCreate),
        create_name: "",
        create_icon: "clipboard-document-list",
        create_icon_open: False,
        create_capability_id: None,
        create_in_flight: False,
        create_error: None,
      ),
      effect.none(),
    )

    ModeEdit(task_type) -> #(
      Model(
        ..model,
        mode: Some(ModeEdit(task_type)),
        edit_name: task_type.name,
        edit_icon: task_type.icon,
        edit_icon_open: False,
        edit_capability_id: task_type.capability_id,
        edit_in_flight: False,
        edit_error: None,
      ),
      effect.none(),
    )

    ModeDelete(task_type) -> #(
      Model(
        ..model,
        mode: Some(ModeDelete(task_type)),
        delete_in_flight: False,
        delete_error: None,
      ),
      effect.none(),
    )
  }
}

// Justification: nested case improves clarity for branching logic.
fn handle_create_submitted(model: Model) -> #(Model, Effect(Msg)) {
  case model.project_id {
    None -> #(model, effect.none())
    Some(project_id) -> {
      let name = string.trim(model.create_name)
      case name {
        "" -> #(
          Model(..model, create_error: Some("Name is required")),
          effect.none(),
        )
        _ -> #(
          Model(..model, create_in_flight: True, create_error: None),
          api_task_types.create_task_type(
            project_id,
            name,
            model.create_icon,
            model.create_capability_id,
            CreateResult,
          ),
        )
      }
    }
  }
}

fn handle_create_success(
  model: Model,
  task_type: TaskType,
) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      create_in_flight: False,
      create_name: "",
      create_icon: "clipboard-document-list",
      create_capability_id: None,
      create_error: None,
    ),
    emit_type_created(task_type),
  )
}

// Justification: nested case improves clarity for branching logic.
fn handle_edit_submitted(model: Model) -> #(Model, Effect(Msg)) {
  case model.mode {
    Some(ModeEdit(task_type)) -> {
      let name = string.trim(model.edit_name)
      case name {
        "" -> #(
          Model(..model, edit_error: Some("Name is required")),
          effect.none(),
        )
        _ -> #(
          Model(..model, edit_in_flight: True, edit_error: None),
          api_task_types.update_task_type(
            task_type.id,
            name,
            model.edit_icon,
            model.edit_capability_id,
            EditResult,
          ),
        )
      }
    }
    _ -> #(model, effect.none())
  }
}

fn handle_edit_success(
  model: Model,
  task_type: TaskType,
) -> #(Model, Effect(Msg)) {
  #(reset_edit_fields(model), emit_type_updated(task_type))
}

fn handle_delete_confirmed(model: Model) -> #(Model, Effect(Msg)) {
  case model.mode {
    Some(ModeDelete(task_type)) -> #(
      Model(..model, delete_in_flight: True, delete_error: None),
      api_task_types.delete_task_type(task_type.id, DeleteResult),
    )
    _ -> #(model, effect.none())
  }
}

fn handle_delete_success(model: Model) -> #(Model, Effect(Msg)) {
  case model.mode {
    Some(ModeDelete(task_type)) -> #(
      reset_delete_fields(model),
      emit_type_deleted(task_type.id),
    )
    _ -> #(model, effect.none())
  }
}

fn handle_delete_error(model: Model, err: ApiError) -> #(Model, Effect(Msg)) {
  let error_msg = case err.status {
    409 -> "Cannot delete: task type is in use"
    _ -> err.message
  }
  #(
    Model(..model, delete_in_flight: False, delete_error: Some(error_msg)),
    effect.none(),
  )
}

fn reset_edit_fields(model: Model) -> Model {
  Model(
    ..model,
    mode: None,
    edit_name: "",
    edit_icon: "clipboard-document-list",
    edit_icon_open: False,
    edit_capability_id: None,
    edit_in_flight: False,
    edit_error: None,
  )
}

fn reset_delete_fields(model: Model) -> Model {
  Model(..model, mode: None, delete_in_flight: False, delete_error: None)
}

// =============================================================================
// Effects - Custom Events
// =============================================================================

fn emit_type_created(task_type: TaskType) -> Effect(Msg) {
  effect.event("type-created", task_type_to_json(task_type))
}

fn emit_type_updated(task_type: TaskType) -> Effect(Msg) {
  effect.event("type-updated", task_type_to_json(task_type))
}

fn emit_type_deleted(id: Int) -> Effect(Msg) {
  effect.event("type-deleted", json.object([#("id", json.int(id))]))
}

fn emit_close_requested() -> Effect(Msg) {
  effect.event("close-requested", json.object([]))
}

fn task_type_to_json(task_type: TaskType) -> json.Json {
  json.object([
    #("id", json.int(task_type.id)),
    #("name", json.string(task_type.name)),
    #("icon", json.string(task_type.icon)),
    #("capability_id", case task_type.capability_id {
      Some(id) -> json.int(id)
      None -> json.null()
    }),
    #("tasks_count", json.int(task_type.tasks_count)),
  ])
}

// =============================================================================
// View
// =============================================================================

fn view(model: Model) -> Element(Msg) {
  case model.mode {
    None -> div([], [])
    Some(ModeCreate) -> view_create_dialog(model)
    Some(ModeEdit(_)) -> view_edit_dialog(model)
    Some(ModeDelete(task_type)) -> view_delete_dialog(model, task_type)
  }
}

fn view_create_dialog(model: Model) -> Element(Msg) {
  div([attribute.class("dialog-overlay")], [
    div([attribute.class("dialog dialog-medium")], [
      div([attribute.class("dialog-header")], [
        h3([], [text(i18n_t(model.locale, i18n_text.CreateTaskType))]),
        button(
          [
            attribute.class("dialog-close"),
            attribute.type_("button"),
            event.on_click(CloseRequested),
          ],
          [text("\u{2715}")],
        ),
      ]),
      form(
        [
          attribute.class("dialog-body"),
          event.on_submit(fn(_) { CreateSubmitted }),
        ],
        [
          // Name field
          div([attribute.class("form-group")], [
            label([attribute.for("create-name")], [
              text(i18n_t(model.locale, i18n_text.Name)),
              span([attribute.class("required")], [text(" *")]),
            ]),
            input([
              attribute.id("create-name"),
              attribute.type_("text"),
              attribute.value(model.create_name),
              attribute.placeholder(i18n_t(model.locale, i18n_text.TaskTypeName)),
              attribute.autofocus(True),
              event.on_input(CreateNameChanged),
            ]),
          ]),
          // Icon picker
          div([attribute.class("form-group")], [
            label([], [text(i18n_t(model.locale, i18n_text.Icon))]),
            view_icon_picker(
              model.create_icon,
              model.create_icon_open,
              CreateIconToggle,
              CreateIconChanged,
            ),
          ]),
          // Capability selector
          view_capability_selector(
            model,
            "create-capability",
            model.create_capability_id,
            CreateCapabilityChanged,
          ),
          // Error
          case model.create_error {
            Some(err) -> div([attribute.class("form-error")], [text(err)])
            None -> element.none()
          },
        ],
      ),
      div([attribute.class("dialog-footer")], [
        button(
          [
            attribute.class("btn btn-secondary"),
            attribute.type_("button"),
            event.on_click(CloseRequested),
          ],
          [text(i18n_t(model.locale, i18n_text.Cancel))],
        ),
        button(
          [
            attribute.class("btn btn-primary"),
            attribute.type_("button"),
            attribute.disabled(model.create_in_flight),
            event.on_click(CreateSubmitted),
          ],
          [
            case model.create_in_flight {
              True -> text(i18n_t(model.locale, i18n_text.Creating))
              False -> text(i18n_t(model.locale, i18n_text.Create))
            },
          ],
        ),
      ]),
    ]),
  ])
}

fn view_edit_dialog(model: Model) -> Element(Msg) {
  div([attribute.class("dialog-overlay")], [
    div([attribute.class("dialog dialog-medium")], [
      div([attribute.class("dialog-header")], [
        h3([], [text(i18n_t(model.locale, i18n_text.EditTaskType))]),
        button(
          [
            attribute.class("dialog-close"),
            attribute.type_("button"),
            event.on_click(EditCancelled),
          ],
          [text("\u{2715}")],
        ),
      ]),
      form(
        [
          attribute.class("dialog-body"),
          event.on_submit(fn(_) { EditSubmitted }),
        ],
        [
          // Name field
          div([attribute.class("form-group")], [
            label([attribute.for("edit-name")], [
              text(i18n_t(model.locale, i18n_text.Name)),
              span([attribute.class("required")], [text(" *")]),
            ]),
            input([
              attribute.id("edit-name"),
              attribute.type_("text"),
              attribute.value(model.edit_name),
              attribute.autofocus(True),
              event.on_input(EditNameChanged),
            ]),
          ]),
          // Icon picker
          div([attribute.class("form-group")], [
            label([], [text(i18n_t(model.locale, i18n_text.Icon))]),
            view_icon_picker(
              model.edit_icon,
              model.edit_icon_open,
              EditIconToggle,
              EditIconChanged,
            ),
          ]),
          // Capability selector
          view_capability_selector(
            model,
            "edit-capability",
            model.edit_capability_id,
            EditCapabilityChanged,
          ),
          // Error
          case model.edit_error {
            Some(err) -> div([attribute.class("form-error")], [text(err)])
            None -> element.none()
          },
        ],
      ),
      div([attribute.class("dialog-footer")], [
        button(
          [
            attribute.class("btn btn-secondary"),
            attribute.type_("button"),
            event.on_click(EditCancelled),
          ],
          [text(i18n_t(model.locale, i18n_text.Cancel))],
        ),
        button(
          [
            attribute.class("btn btn-primary"),
            attribute.type_("button"),
            attribute.disabled(model.edit_in_flight),
            event.on_click(EditSubmitted),
          ],
          [
            case model.edit_in_flight {
              True -> text(i18n_t(model.locale, i18n_text.Saving))
              False -> text(i18n_t(model.locale, i18n_text.Save))
            },
          ],
        ),
      ]),
    ]),
  ])
}

fn view_delete_dialog(model: Model, task_type: TaskType) -> Element(Msg) {
  div([attribute.class("dialog-overlay")], [
    div([attribute.class("dialog dialog-small")], [
      div([attribute.class("dialog-header")], [
        h3([], [text(i18n_t(model.locale, i18n_text.DeleteTaskType))]),
        button(
          [
            attribute.class("dialog-close"),
            attribute.type_("button"),
            event.on_click(DeleteCancelled),
          ],
          [text("\u{2715}")],
        ),
      ]),
      div([attribute.class("dialog-body")], [
        p([], [
          text(i18n_t(
            model.locale,
            i18n_text.ConfirmDeleteTaskType(task_type.name),
          )),
        ]),
        // Warning if type has tasks
        case task_type.tasks_count > 0 {
          True ->
            div([attribute.class("form-warning")], [
              text("\u{26A0}"),
              text(" "),
              text(i18n_t(
                model.locale,
                i18n_text.TaskTypeHasTasks(task_type.tasks_count),
              )),
            ])
          False -> element.none()
        },
        // Error
        case model.delete_error {
          Some(err) -> div([attribute.class("form-error")], [text(err)])
          None -> element.none()
        },
      ]),
      div([attribute.class("dialog-footer")], [
        button(
          [
            attribute.class("btn btn-secondary"),
            attribute.type_("button"),
            event.on_click(DeleteCancelled),
          ],
          [text(i18n_t(model.locale, i18n_text.Cancel))],
        ),
        button(
          [
            attribute.class("btn btn-danger"),
            attribute.type_("button"),
            attribute.disabled(
              model.delete_in_flight || task_type.tasks_count > 0,
            ),
            event.on_click(DeleteConfirmed),
          ],
          [
            case model.delete_in_flight {
              True -> text(i18n_t(model.locale, i18n_text.Deleting))
              False -> text(i18n_t(model.locale, i18n_text.Delete))
            },
          ],
        ),
      ]),
    ]),
  ])
}

// =============================================================================
// Icon Picker
// =============================================================================

/// Common icons for task types.
const task_type_icons = [
  "clipboard-document-list", "bug-ant", "sparkles", "rocket-launch",
  "check-circle", "wrench-screwdriver", "document-text", "code-bracket",
  "beaker", "shield-check", "bolt", "cog-6-tooth", "cube", "flag", "light-bulb",
  "puzzle-piece",
]

fn view_icon_picker(
  current_icon: String,
  is_open: Bool,
  on_toggle: Msg,
  on_select: fn(String) -> Msg,
) -> Element(Msg) {
  div([attribute.class("icon-picker")], [
    button(
      [
        attribute.class("icon-picker-trigger"),
        attribute.type_("button"),
        event.on_click(on_toggle),
      ],
      [
        icon_catalog.render(current_icon, 20),
        span([attribute.class("icon-picker-label")], [text(current_icon)]),
        text(" \u{25BC}"),
      ],
    ),
    case is_open {
      True ->
        div([attribute.class("icon-picker-dropdown")], [
          div(
            [attribute.class("icon-picker-grid")],
            task_type_icons
              |> list.map(fn(icon_name) {
                button(
                  [
                    attribute.class(case icon_name == current_icon {
                      True -> "icon-option selected"
                      False -> "icon-option"
                    }),
                    attribute.type_("button"),
                    event.on_click(on_select(icon_name)),
                  ],
                  [icon_catalog.render(icon_name, 20)],
                )
              }),
          ),
        ])
      False -> element.none()
    },
  ])
}

// =============================================================================
// Capability Selector
// =============================================================================

/// Render capability selector dropdown.
fn view_capability_selector(
  model: Model,
  id: String,
  current_value: Option(Int),
  on_change: fn(Option(Int)) -> Msg,
) -> Element(Msg) {
  div([attribute.class("form-group")], [
    label([attribute.for(id)], [
      text(i18n_t(model.locale, i18n_text.CapabilityOptional)),
    ]),
    select(
      [
        attribute.id(id),
        attribute.name("capability_id"),
        attribute.class("form-select"),
        event.on_input(fn(value) {
          case int.parse(value) {
            Ok(0) -> on_change(None)
            Ok(cap_id) -> on_change(Some(cap_id))
            Error(_) -> on_change(None)
          }
        }),
      ],
      [
        html_option(
          [attribute.value("0"), attribute.selected(current_value == None)],
          i18n_t(model.locale, i18n_text.NoneOption),
        ),
        ..list.map(model.capabilities, fn(cap) {
          html_option(
            [
              attribute.value(int.to_string(cap.id)),
              attribute.selected(current_value == Some(cap.id)),
            ],
            cap.name,
          )
        })
      ],
    ),
  ])
}

// =============================================================================
// I18n Helper
// =============================================================================

fn i18n_t(locale: Locale, key: i18n_text.Text) -> String {
  case locale {
    En -> i18n_en.translate(key)
    Es -> i18n_es.translate(key)
  }
}
