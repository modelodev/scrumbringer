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

import lustre
import lustre/attribute
import lustre/component
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html.{
  button, div, form, input, label, option as html_option, p, select, span, text,
}
import lustre/event

import domain/api_error.{type ApiError, type ApiResult}
import domain/capability.{type Capability}
import domain/capability/codec as capability_codec
import domain/task/codec as task_codec
import domain/task_type.{type TaskType}

import scrumbringer_client/api/tasks/task_types as api_task_types
import scrumbringer_client/components/crud_dialog_base
import scrumbringer_client/i18n/en as i18n_en
import scrumbringer_client/i18n/es as i18n_es
import scrumbringer_client/i18n/locale.{type Locale, En, Es}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/icon_catalog
import scrumbringer_client/ui/modal_header

// =============================================================================
// Internal Types
// =============================================================================

/// Dialog mode determines which view to show.
pub type DialogMode =
  crud_dialog_base.DialogLifecycle(TaskType)

/// Internal component model.
pub type Model {
  Model(
    // Attributes from parent
    locale: Locale,
    project_id: Option(Int),
    mode: DialogMode,
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
    component.on_property_change(
      "capabilities",
      capabilities_property_decoder(),
    ),
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
  crud_dialog_base.decode_create_mode(
    value,
    crud_dialog_base.Creating,
    ModeReceived,
  )
}

fn task_type_property_decoder() -> Decoder(Msg) {
  use task_type <- decode.then(task_codec.task_type_decoder())
  use mode <- decode.field("_mode", decode.string)
  crud_dialog_base.decode_entity_mode(
    mode,
    task_type,
    crud_dialog_base.Editing,
    crud_dialog_base.Deleting,
    ModeReceived,
  )
}

fn capabilities_property_decoder() -> Decoder(Msg) {
  decode.list(capability_codec.capability_decoder())
  |> decode.map(CapabilitiesReceived)
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
    mode: crud_dialog_base.Closed,
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
    crud_dialog_base.Closed -> #(
      Model(..model, mode: crud_dialog_base.Closed),
      effect.none(),
    )

    crud_dialog_base.Creating -> #(
      Model(
        ..model,
        mode: crud_dialog_base.Creating,
        create_name: "",
        create_icon: "clipboard-document-list",
        create_icon_open: False,
        create_capability_id: None,
        create_in_flight: False,
        create_error: None,
      ),
      effect.none(),
    )

    crud_dialog_base.Editing(task_type) -> #(
      Model(
        ..model,
        mode: crud_dialog_base.Editing(task_type),
        edit_name: task_type.name,
        edit_icon: task_type.icon,
        edit_icon_open: False,
        edit_capability_id: task_type.capability_id,
        edit_in_flight: False,
        edit_error: None,
      ),
      effect.none(),
    )

    crud_dialog_base.Deleting(task_type) -> #(
      Model(
        ..model,
        mode: crud_dialog_base.Deleting(task_type),
        delete_in_flight: False,
        delete_error: None,
      ),
      effect.none(),
    )
  }
}

fn handle_create_submitted(model: Model) -> #(Model, Effect(Msg)) {
  crud_dialog_base.submit_if_idle(model, model.create_in_flight, submit_create)
}

fn submit_create(model: Model) -> #(Model, Effect(Msg)) {
  case model.project_id {
    None -> #(model, effect.none())
    Some(project_id) -> {
      case crud_dialog_base.required_text(model.create_name) {
        Error(_) -> #(
          Model(..model, create_error: Some("Name is required")),
          effect.none(),
        )
        Ok(name) -> #(
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

fn handle_edit_submitted(model: Model) -> #(Model, Effect(Msg)) {
  crud_dialog_base.submit_if_idle(model, model.edit_in_flight, submit_edit)
}

fn submit_edit(model: Model) -> #(Model, Effect(Msg)) {
  case model.mode {
    crud_dialog_base.Editing(task_type) -> {
      case crud_dialog_base.required_text(model.edit_name) {
        Error(_) -> #(
          Model(..model, edit_error: Some("Name is required")),
          effect.none(),
        )
        Ok(name) -> #(
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
  crud_dialog_base.submit_if_idle(model, model.delete_in_flight, submit_delete)
}

fn submit_delete(model: Model) -> #(Model, Effect(Msg)) {
  case model.mode {
    crud_dialog_base.Deleting(task_type) -> #(
      Model(..model, delete_in_flight: True, delete_error: None),
      api_task_types.delete_task_type(task_type.id, DeleteResult),
    )
    _ -> #(model, effect.none())
  }
}

fn handle_delete_success(model: Model) -> #(Model, Effect(Msg)) {
  case model.mode {
    crud_dialog_base.Deleting(task_type) -> #(
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
    mode: crud_dialog_base.Closed,
    edit_name: "",
    edit_icon: "clipboard-document-list",
    edit_icon_open: False,
    edit_capability_id: None,
    edit_in_flight: False,
    edit_error: None,
  )
}

fn reset_delete_fields(model: Model) -> Model {
  Model(
    ..model,
    mode: crud_dialog_base.Closed,
    delete_in_flight: False,
    delete_error: None,
  )
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
    crud_dialog_base.Closed -> div([], [])
    crud_dialog_base.Creating -> view_create_dialog(model)
    crud_dialog_base.Editing(_) -> view_edit_dialog(model)
    crud_dialog_base.Deleting(task_type) -> view_delete_dialog(model, task_type)
  }
}

fn view_optional_fields(
  model: Model,
  icon: String,
  icon_open: Bool,
  on_icon_toggle: Msg,
  on_icon_changed: fn(String) -> Msg,
  capability_id: Option(Int),
  capability_selector_id: String,
  on_capability_changed: fn(Option(Int)) -> Msg,
) -> Element(Msg) {
  div([attribute.class("form-group-optional")], [
    label([attribute.class("optional-title")], [
      text(i18n_t(model.locale, i18n_text.OptionalFields)),
    ]),
    div([attribute.class("optional-fields")], [
      div([attribute.class("form-group")], [
        label([], [text(i18n_t(model.locale, i18n_text.Icon))]),
        view_icon_picker(
          model.locale,
          icon,
          icon_open,
          on_icon_toggle,
          on_icon_changed,
        ),
      ]),
      view_capability_selector(
        model,
        capability_selector_id,
        capability_id,
        on_capability_changed,
      ),
    ]),
  ])
}

fn view_name_field(
  model: Model,
  id: String,
  value: String,
  placeholder: Option(String),
  hint: Option(String),
  on_input: fn(String) -> Msg,
) -> Element(Msg) {
  div([attribute.class("form-group")], [
    label([attribute.for(id)], [
      text(i18n_t(model.locale, i18n_text.Name)),
      span([attribute.class("required")], [text(" *")]),
    ]),
    input(
      [
        attribute.id(id),
        attribute.type_("text"),
        attribute.value(value),
        attribute.autofocus(True),
        event.on_input(on_input),
      ]
      |> maybe_add_placeholder(placeholder),
    ),
    view_name_hint(hint),
  ])
}

fn maybe_add_placeholder(
  attrs: List(attribute.Attribute(Msg)),
  placeholder: Option(String),
) -> List(attribute.Attribute(Msg)) {
  case placeholder {
    Some(text) -> [attribute.placeholder(text), ..attrs]
    None -> attrs
  }
}

fn view_name_hint(hint: Option(String)) -> Element(Msg) {
  case hint {
    Some(message) -> div([attribute.class("form-hint")], [text(message)])
    None -> element.none()
  }
}

fn view_create_dialog(model: Model) -> Element(Msg) {
  crud_dialog_base.view_dialog_frame(
    "dialog dialog-lg dialog-lg-tight",
    modal_header.view_dialog(
      i18n_t(model.locale, i18n_text.CreateTaskType),
      option.None,
      CloseRequested,
    ),
    [
      form(
        [
          attribute.class("dialog-body"),
          event.on_submit(fn(_) { CreateSubmitted }),
        ],
        [
          view_name_field(
            model,
            "create-name",
            model.create_name,
            Some(i18n_t(model.locale, i18n_text.TaskTypeName)),
            Some(i18n_t(model.locale, i18n_text.TaskTypeNameHint)),
            CreateNameChanged,
          ),
          view_optional_fields(
            model,
            model.create_icon,
            model.create_icon_open,
            CreateIconToggle,
            CreateIconChanged,
            model.create_capability_id,
            "create-capability",
            CreateCapabilityChanged,
          ),
          crud_dialog_base.view_form_error(model.create_error),
        ],
      ),
    ],
    [
      crud_dialog_base.view_cancel_button_with_class(
        model.locale,
        CloseRequested,
        "btn btn-secondary btn-sm",
      ),
      crud_dialog_base.view_primary_action_button(
        CreateSubmitted,
        model.create_in_flight,
        i18n_t(model.locale, i18n_text.CreateTaskType),
        i18n_t(model.locale, i18n_text.Creating),
        "btn btn-primary btn-compact",
      ),
    ],
  )
}

fn view_edit_dialog(model: Model) -> Element(Msg) {
  crud_dialog_base.view_dialog_frame(
    "dialog dialog-lg dialog-lg-tight",
    modal_header.view_dialog(
      i18n_t(model.locale, i18n_text.EditTaskType),
      option.None,
      EditCancelled,
    ),
    [
      form(
        [
          attribute.class("dialog-body"),
          event.on_submit(fn(_) { EditSubmitted }),
        ],
        [
          view_name_field(
            model,
            "edit-name",
            model.edit_name,
            None,
            None,
            EditNameChanged,
          ),
          view_optional_fields(
            model,
            model.edit_icon,
            model.edit_icon_open,
            EditIconToggle,
            EditIconChanged,
            model.edit_capability_id,
            "edit-capability",
            EditCapabilityChanged,
          ),
          crud_dialog_base.view_form_error(model.edit_error),
        ],
      ),
    ],
    [
      crud_dialog_base.view_cancel_button_with_class(
        model.locale,
        EditCancelled,
        "btn btn-secondary btn-sm",
      ),
      crud_dialog_base.view_primary_action_button(
        EditSubmitted,
        model.edit_in_flight,
        i18n_t(model.locale, i18n_text.Save),
        i18n_t(model.locale, i18n_text.Saving),
        "btn btn-primary btn-compact",
      ),
    ],
  )
}

fn view_delete_dialog(model: Model, task_type: TaskType) -> Element(Msg) {
  crud_dialog_base.view_dialog_frame(
    "dialog dialog-small",
    modal_header.view_dialog(
      i18n_t(model.locale, i18n_text.DeleteTaskType),
      option.None,
      DeleteCancelled,
    ),
    [
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
        crud_dialog_base.view_form_error(model.delete_error),
      ]),
    ],
    [
      crud_dialog_base.view_cancel_button_with_class(
        model.locale,
        DeleteCancelled,
        "btn btn-secondary",
      ),
      crud_dialog_base.view_danger_action_button(
        DeleteConfirmed,
        model.delete_in_flight,
        model.delete_in_flight || task_type.tasks_count > 0,
        i18n_t(model.locale, i18n_text.Delete),
        i18n_t(model.locale, i18n_text.Deleting),
        "btn btn-danger",
      ),
    ],
  )
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

/// Minimal icon picker view for tests (no dropdown open).
pub fn view_icon_picker_trigger_for_test(
  locale: Locale,
  current_icon: String,
) -> Element(Msg) {
  view_icon_picker(
    locale,
    current_icon,
    False,
    CreateIconToggle,
    CreateIconChanged,
  )
}

pub fn view_create_dialog_for_test(locale: Locale) -> Element(Msg) {
  let model = default_model()
  let model = Model(..model, locale: locale, mode: crud_dialog_base.Creating)
  view_create_dialog(model)
}

pub fn view_edit_dialog_for_test(
  locale: Locale,
  task_type: TaskType,
) -> Element(Msg) {
  let model = default_model()
  let model =
    Model(
      ..model,
      locale: locale,
      mode: crud_dialog_base.Editing(task_type),
      edit_name: task_type.name,
      edit_icon: task_type.icon,
      edit_capability_id: task_type.capability_id,
    )
  view_edit_dialog(model)
}

fn view_icon_picker(
  locale: Locale,
  current_icon: String,
  is_open: Bool,
  on_toggle: Msg,
  on_select: fn(String) -> Msg,
) -> Element(Msg) {
  let icon_label = resolve_icon_label(locale, current_icon)
  div([attribute.class("icon-picker")], [
    button(
      [
        attribute.class("icon-picker-trigger form-control"),
        attribute.type_("button"),
        attribute.attribute("title", icon_label),
        attribute.attribute("aria-label", icon_label),
        event.on_click(on_toggle),
      ],
      [
        span([attribute.class("icon-picker-trigger-left")], [
          icon_catalog.render(current_icon, 20),
          span([attribute.class("icon-picker-placeholder")], [
            text(i18n_t(locale, i18n_text.SelectIcon)),
          ]),
        ]),
        span([attribute.class("icon-picker-caret")], [text("\u{25BC}")]),
        span([attribute.class("sr-only")], [text(icon_label)]),
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

fn resolve_icon_label(locale: Locale, icon_id: String) -> String {
  case icon_catalog.get(icon_id) {
    Some(icon) -> icon.label
    None -> i18n_t(locale, i18n_text.UnknownIcon)
  }
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
      text(i18n_t(model.locale, i18n_text.CapabilityLabel)),
    ]),
    select(
      [
        attribute.id(id),
        attribute.name("capability_id"),
        attribute.class("form-select form-control"),
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
