//// Task Template CRUD Dialog Component.
////
//// ## Mission
////
//// Encapsulated Lustre Component for task template create, edit, and delete dialogs.
////
//// ## Responsibilities
////
//// - Handle create dialog: name, description, type_id, priority fields
//// - Handle edit dialog: prefill from template, submit updates
//// - Handle delete confirmation dialog
//// - Emit events to parent for task-template-created, task-template-updated, task-template-deleted
//// - Support both org-scoped and project-scoped templates
////
//// ## Relations
////
//// - Parent: features/admin/view.gleam renders this component
//// - API: api/workflows.gleam for CRUD operations

import gleam/dynamic/decode.{type Decoder}
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option}
import gleam/result

import lustre
import lustre/attribute
import lustre/component
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html.{
  button, div, form, h3, input, label, option as html_option, p, select, span,
  text, textarea,
}
import lustre/event

import domain/api_error.{type ApiError}
import domain/task_type.{type TaskType, TaskType}
import domain/workflow.{type TaskTemplate, TaskTemplate}

import scrumbringer_client/api/core.{type ApiResult}
import scrumbringer_client/api/workflows as api_workflows
import scrumbringer_client/i18n/en as i18n_en
import scrumbringer_client/i18n/es as i18n_es
import scrumbringer_client/i18n/locale.{type Locale, En, Es}
import scrumbringer_client/i18n/text as i18n_text

// =============================================================================
// Internal Types
// =============================================================================

/// Dialog mode determines which view to show.
pub type DialogMode {
  ModeCreate
  ModeEdit(TaskTemplate)
  ModeDelete(TaskTemplate)
}

/// Internal component model - encapsulates all 17 task template CRUD fields.
pub type Model {
  Model(
    // Attributes from parent
    locale: Locale,
    project_id: Option(Int),
    mode: Option(DialogMode),
    task_types: List(TaskType),
    // Create dialog fields
    create_name: String,
    create_description: String,
    create_type_id: Option(Int),
    create_priority: String,
    create_in_flight: Bool,
    create_error: Option(String),
    // Edit dialog fields
    edit_name: String,
    edit_description: String,
    edit_type_id: Option(Int),
    edit_priority: String,
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
  ProjectIdReceived(Option(Int))
  ModeReceived(DialogMode)
  TaskTypesReceived(List(TaskType))
  // Create form
  CreateNameChanged(String)
  CreateDescriptionChanged(String)
  CreateTypeIdChanged(String)
  CreatePriorityChanged(String)
  CreateSubmitted
  CreateResult(ApiResult(TaskTemplate))
  // Edit form
  EditNameChanged(String)
  EditDescriptionChanged(String)
  EditTypeIdChanged(String)
  EditPriorityChanged(String)
  EditSubmitted
  EditResult(ApiResult(TaskTemplate))
  EditCancelled
  // Delete confirmation
  DeleteConfirmed
  DeleteResult(ApiResult(Nil))
  DeleteCancelled
  // Close dialog
  CloseRequested
}

// =============================================================================
// Component Registration
// =============================================================================

/// Register the task-template-crud-dialog as a custom element.
/// Call this once at app init. Returns Result to handle registration errors.
pub fn register() -> Result(Nil, lustre.Error) {
  lustre.component(init, update, view, on_attribute_change())
  |> lustre.register("task-template-crud-dialog")
}

/// Build attribute/property change handlers.
fn on_attribute_change() -> List(component.Option(Msg)) {
  [
    component.on_attribute_change("locale", decode_locale),
    component.on_attribute_change("project-id", decode_project_id),
    component.on_attribute_change("mode", decode_mode),
    component.on_property_change("template", template_property_decoder()),
    component.on_property_change("task-types", task_types_property_decoder()),
    component.adopt_styles(True),
  ]
}

fn decode_locale(value: String) -> Result(Msg, Nil) {
  Ok(LocaleReceived(locale.deserialize(value)))
}

fn decode_project_id(value: String) -> Result(Msg, Nil) {
  case value {
    "" | "null" | "undefined" -> Ok(ProjectIdReceived(option.None))
    _ ->
      int.parse(value)
      |> result.map(fn(id) { ProjectIdReceived(option.Some(id)) })
      |> result.replace_error(Nil)
  }
}

fn decode_mode(value: String) -> Result(Msg, Nil) {
  case value {
    "create" -> Ok(ModeReceived(ModeCreate))
    // edit and delete modes need template data from property
    _ -> Error(Nil)
  }
}

fn template_property_decoder() -> Decoder(Msg) {
  use id <- decode.field("id", decode.int)
  use org_id <- decode.field("org_id", decode.int)
  use project_id <- decode.field("project_id", decode.optional(decode.int))
  use name <- decode.field("name", decode.string)
  use description <- decode.field("description", decode.optional(decode.string))
  use type_id <- decode.field("type_id", decode.int)
  use type_name <- decode.field("type_name", decode.string)
  use priority <- decode.field("priority", decode.int)
  use _created_by <- decode.field("created_by", decode.int)
  use _created_at <- decode.field("created_at", decode.string)
  use rules_count <- decode.optional_field("rules_count", 0, decode.int)
  use mode <- decode.field("_mode", decode.string)
  let template =
    TaskTemplate(
      id: id,
      org_id: org_id,
      project_id: project_id,
      name: name,
      description: description,
      type_id: type_id,
      type_name: type_name,
      priority: priority,
      created_by: 0,
      created_at: "",
      rules_count: rules_count,
    )
  case mode {
    "edit" -> decode.success(ModeReceived(ModeEdit(template)))
    "delete" -> decode.success(ModeReceived(ModeDelete(template)))
    _ -> decode.success(ModeReceived(ModeEdit(template)))
  }
}

fn task_types_property_decoder() -> Decoder(Msg) {
  use types <- decode.then(decode.list(task_type_decoder()))
  decode.success(TaskTypesReceived(types))
}

fn task_type_decoder() -> Decoder(TaskType) {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use icon <- decode.field("icon", decode.string)
  decode.success(TaskType(
    id: id,
    name: name,
    icon: icon,
    capability_id: option.None,
    tasks_count: 0,
  ))
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
    project_id: option.None,
    mode: option.None,
    task_types: [],
    create_name: "",
    create_description: "",
    create_type_id: option.None,
    create_priority: "3",
    create_in_flight: False,
    create_error: option.None,
    edit_name: "",
    edit_description: "",
    edit_type_id: option.None,
    edit_priority: "3",
    edit_in_flight: False,
    edit_error: option.None,
    delete_in_flight: False,
    delete_error: option.None,
  )
}

// =============================================================================
// Update
// =============================================================================

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    LocaleReceived(loc) ->
      #(Model(..model, locale: loc), effect.none())

    ProjectIdReceived(id) ->
      #(Model(..model, project_id: id), effect.none())

    ModeReceived(mode) ->
      handle_mode_received(model, mode)

    TaskTypesReceived(types) ->
      #(Model(..model, task_types: types), effect.none())

    // Create form handlers
    CreateNameChanged(name) ->
      #(Model(..model, create_name: name), effect.none())

    CreateDescriptionChanged(desc) ->
      #(Model(..model, create_description: desc), effect.none())

    CreateTypeIdChanged(type_id_str) ->
      #(
        Model(..model, create_type_id: parse_optional_int(type_id_str)),
        effect.none(),
      )

    CreatePriorityChanged(priority) ->
      #(Model(..model, create_priority: priority), effect.none())

    CreateSubmitted ->
      handle_create_submitted(model)

    CreateResult(Ok(template)) ->
      handle_create_success(model, template)

    CreateResult(Error(err)) ->
      #(
        Model(..model, create_in_flight: False, create_error: option.Some(err.message)),
        effect.none(),
      )

    // Edit form handlers
    EditNameChanged(name) ->
      #(Model(..model, edit_name: name), effect.none())

    EditDescriptionChanged(desc) ->
      #(Model(..model, edit_description: desc), effect.none())

    EditTypeIdChanged(type_id_str) ->
      #(
        Model(..model, edit_type_id: parse_optional_int(type_id_str)),
        effect.none(),
      )

    EditPriorityChanged(priority) ->
      #(Model(..model, edit_priority: priority), effect.none())

    EditSubmitted ->
      handle_edit_submitted(model)

    EditResult(Ok(template)) ->
      handle_edit_success(model, template)

    EditResult(Error(err)) ->
      #(
        Model(..model, edit_in_flight: False, edit_error: option.Some(err.message)),
        effect.none(),
      )

    EditCancelled ->
      #(reset_edit_fields(model), emit_close_requested())

    // Delete handlers
    DeleteConfirmed ->
      handle_delete_confirmed(model)

    DeleteResult(Ok(_)) ->
      handle_delete_success(model)

    DeleteResult(Error(err)) ->
      handle_delete_error(model, err)

    DeleteCancelled ->
      #(reset_delete_fields(model), emit_close_requested())

    CloseRequested ->
      #(model, emit_close_requested())
  }
}

fn parse_optional_int(value: String) -> Option(Int) {
  case value {
    "" | "null" | "undefined" -> option.None
    _ ->
      int.parse(value)
      |> result.map(option.Some)
      |> result.unwrap(option.None)
  }
}

fn handle_mode_received(model: Model, mode: DialogMode) -> #(Model, Effect(Msg)) {
  case mode {
    ModeCreate ->
      #(
        Model(
          ..model,
          mode: option.Some(ModeCreate),
          create_name: "",
          create_description: "",
          create_type_id: option.None,
          create_priority: "3",
          create_in_flight: False,
          create_error: option.None,
        ),
        effect.none(),
      )

    ModeEdit(template) ->
      #(
        Model(
          ..model,
          mode: option.Some(ModeEdit(template)),
          edit_name: template.name,
          edit_description: option.unwrap(template.description, ""),
          edit_type_id: option.Some(template.type_id),
          edit_priority: int.to_string(template.priority),
          edit_in_flight: False,
          edit_error: option.None,
        ),
        effect.none(),
      )

    ModeDelete(template) ->
      #(
        Model(
          ..model,
          mode: option.Some(ModeDelete(template)),
          delete_in_flight: False,
          delete_error: option.None,
        ),
        effect.none(),
      )
  }
}

fn handle_create_submitted(model: Model) -> #(Model, Effect(Msg)) {
  case model.create_in_flight {
    True -> #(model, effect.none())
    False ->
      case model.create_name, model.create_type_id {
        "", _ ->
          #(
            Model(..model, create_error: option.Some(t(model.locale, i18n_text.NameRequired))),
            effect.none(),
          )
        _, option.None ->
          #(
            Model(..model, create_error: option.Some(t(model.locale, i18n_text.TypeRequired))),
            effect.none(),
          )
        name, option.Some(type_id) -> {
          let priority = int.parse(model.create_priority) |> result.unwrap(3)
          // Templates are now project-scoped only
          case model.project_id {
            option.Some(project_id) ->
              #(
                Model(..model, create_in_flight: True, create_error: option.None),
                api_workflows.create_project_template(
                  project_id,
                  name,
                  model.create_description,
                  type_id,
                  priority,
                  CreateResult,
                ),
              )
            option.None ->
              #(
                Model(..model, create_error: option.Some(t(model.locale, i18n_text.SelectProjectFirst))),
                effect.none(),
              )
          }
        }
      }
  }
}

fn handle_create_success(model: Model, template: TaskTemplate) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      mode: option.None,
      create_name: "",
      create_description: "",
      create_type_id: option.None,
      create_priority: "3",
      create_in_flight: False,
      create_error: option.None,
    ),
    emit_template_created(template),
  )
}

fn handle_edit_submitted(model: Model) -> #(Model, Effect(Msg)) {
  case model.edit_in_flight {
    True -> #(model, effect.none())
    False ->
      case model.edit_name, model.edit_type_id {
        "", _ ->
          #(
            Model(..model, edit_error: option.Some(t(model.locale, i18n_text.NameRequired))),
            effect.none(),
          )
        _, option.None ->
          #(
            Model(..model, edit_error: option.Some(t(model.locale, i18n_text.TypeRequired))),
            effect.none(),
          )
        name, option.Some(type_id) ->
          case model.mode {
            option.Some(ModeEdit(template)) -> {
              let priority = int.parse(model.edit_priority) |> result.unwrap(3)
              #(
                Model(..model, edit_in_flight: True, edit_error: option.None),
                api_workflows.update_template(
                  template.id,
                  name,
                  model.edit_description,
                  type_id,
                  priority,
                  EditResult,
                ),
              )
            }
            _ ->
              #(model, effect.none())
          }
      }
  }
}

fn handle_edit_success(model: Model, template: TaskTemplate) -> #(Model, Effect(Msg)) {
  #(
    reset_edit_fields(model),
    emit_template_updated(template),
  )
}

fn handle_delete_confirmed(model: Model) -> #(Model, Effect(Msg)) {
  case model.delete_in_flight {
    True -> #(model, effect.none())
    False ->
      case model.mode {
        option.Some(ModeDelete(template)) ->
          #(
            Model(..model, delete_in_flight: True, delete_error: option.None),
            api_workflows.delete_template(template.id, DeleteResult),
          )
        _ ->
          #(model, effect.none())
      }
  }
}

fn handle_delete_success(model: Model) -> #(Model, Effect(Msg)) {
  let template_id = case model.mode {
    option.Some(ModeDelete(template)) -> template.id
    _ -> 0
  }
  #(
    reset_delete_fields(model),
    emit_template_deleted(template_id),
  )
}

fn handle_delete_error(model: Model, err: ApiError) -> #(Model, Effect(Msg)) {
  #(
    Model(..model, delete_in_flight: False, delete_error: option.Some(err.message)),
    effect.none(),
  )
}

fn reset_edit_fields(model: Model) -> Model {
  Model(
    ..model,
    mode: option.None,
    edit_name: "",
    edit_description: "",
    edit_type_id: option.None,
    edit_priority: "3",
    edit_in_flight: False,
    edit_error: option.None,
  )
}

fn reset_delete_fields(model: Model) -> Model {
  Model(
    ..model,
    mode: option.None,
    delete_in_flight: False,
    delete_error: option.None,
  )
}

// =============================================================================
// Effects - Custom Events
// =============================================================================

fn emit_template_created(template: TaskTemplate) -> Effect(Msg) {
  effect.from(fn(_dispatch) {
    emit_custom_event("task-template-created", template_to_json(template))
  })
}

fn emit_template_updated(template: TaskTemplate) -> Effect(Msg) {
  effect.from(fn(_dispatch) {
    emit_custom_event("task-template-updated", template_to_json(template))
  })
}

fn emit_template_deleted(template_id: Int) -> Effect(Msg) {
  effect.from(fn(_dispatch) {
    emit_custom_event("task-template-deleted", json.object([#("id", json.int(template_id))]))
  })
}

fn emit_close_requested() -> Effect(Msg) {
  effect.from(fn(_dispatch) {
    emit_custom_event("close-requested", json.null())
  })
}

@external(javascript, "../component.ffi.mjs", "emit_custom_event")
fn emit_custom_event(_name: String, _detail: json.Json) -> Nil {
  Nil
}

fn template_to_json(template: TaskTemplate) -> json.Json {
  let project_id_field = case template.project_id {
    option.Some(id) -> [#("project_id", json.int(id))]
    option.None -> [#("project_id", json.null())]
  }
  let description_field = case template.description {
    option.Some(desc) -> [#("description", json.string(desc))]
    option.None -> [#("description", json.null())]
  }
  json.object(
    [
      #("id", json.int(template.id)),
      #("org_id", json.int(template.org_id)),
      #("name", json.string(template.name)),
      #("type_id", json.int(template.type_id)),
      #("type_name", json.string(template.type_name)),
      #("priority", json.int(template.priority)),
      #("created_by", json.int(template.created_by)),
      #("created_at", json.string(template.created_at)),
    ]
    |> append_fields(project_id_field)
    |> append_fields(description_field)
  )
}

fn append_fields(base: List(#(String, json.Json)), fields: List(#(String, json.Json))) -> List(#(String, json.Json)) {
  case fields {
    [] -> base
    [field, ..rest] -> append_fields([field, ..base], rest)
  }
}

// =============================================================================
// View
// =============================================================================

fn view(model: Model) -> Element(Msg) {
  case model.mode {
    option.None -> element.none()
    option.Some(ModeCreate) -> view_create_dialog(model)
    option.Some(ModeEdit(_template)) -> view_edit_dialog(model)
    option.Some(ModeDelete(template)) -> view_delete_dialog(model, template)
  }
}

fn view_create_dialog(model: Model) -> Element(Msg) {
  div([attribute.class("dialog-overlay")], [
    div(
      [
        attribute.class("dialog dialog-md"),
        attribute.attribute("role", "dialog"),
        attribute.attribute("aria-modal", "true"),
      ],
      [
        // Header
        view_header(model, i18n_text.CreateTaskTemplate, "\u{1F4DD}"),
        // Error
        view_error(model.create_error),
        // Body
        div([attribute.class("dialog-body")], [
          form(
            [
              event.on_submit(fn(_) { CreateSubmitted }),
              attribute.id("template-create-form"),
            ],
            [
              // Name field
              div([attribute.class("field")], [
                label([], [text(t(model.locale, i18n_text.TaskTemplateName))]),
                input([
                  attribute.type_("text"),
                  attribute.value(model.create_name),
                  event.on_input(CreateNameChanged),
                  attribute.required(True),
                  attribute.attribute("aria-label", "Template name"),
                ]),
              ]),
              // Description field (textarea with variables hint)
              div([attribute.class("field")], [
                label([], [text(t(model.locale, i18n_text.TaskTemplateDescription))]),
                textarea(
                  [
                    attribute.rows(4),
                    attribute.value(model.create_description),
                    event.on_input(CreateDescriptionChanged),
                    attribute.attribute("aria-label", "Template description"),
                  ],
                  model.create_description,
                ),
                div([attribute.class("field-variables-hint")], [
                  span([attribute.class("field-variables-label")], [
                    text(t(model.locale, i18n_text.AvailableVariables) <> ": "),
                  ]),
                  span([attribute.class("field-variables-list")], [
                    text("{{father}}, {{from_state}}, {{to_state}}, {{project}}, {{user}}"),
                  ]),
                ]),
              ]),
              // Task Type selector
              div([attribute.class("field")], [
                label([], [text(t(model.locale, i18n_text.TaskTemplateType))]),
                view_task_type_selector(model.locale, model.task_types, model.create_type_id, CreateTypeIdChanged),
              ]),
              // Priority selector
              div([attribute.class("field")], [
                label([], [text(t(model.locale, i18n_text.TaskTemplatePriority))]),
                view_priority_selector(model.create_priority, CreatePriorityChanged),
              ]),
            ],
          ),
        ]),
        // Footer
        div([attribute.class("dialog-footer")], [
          view_cancel_button(model.locale, CloseRequested),
          button(
            [
              attribute.type_("submit"),
              attribute.form("template-create-form"),
              attribute.disabled(model.create_in_flight),
              attribute.class(case model.create_in_flight {
                True -> "btn-loading"
                False -> ""
              }),
            ],
            [
              text(case model.create_in_flight {
                True -> t(model.locale, i18n_text.Creating)
                False -> t(model.locale, i18n_text.Create)
              }),
            ],
          ),
        ]),
      ],
    ),
  ])
}

fn view_edit_dialog(model: Model) -> Element(Msg) {
  div([attribute.class("dialog-overlay")], [
    div(
      [
        attribute.class("dialog dialog-md"),
        attribute.attribute("role", "dialog"),
        attribute.attribute("aria-modal", "true"),
      ],
      [
        // Header
        view_header(model, i18n_text.EditTaskTemplate, "\u{270F}"),
        // Error
        view_error(model.edit_error),
        // Body
        div([attribute.class("dialog-body")], [
          form(
            [
              event.on_submit(fn(_) { EditSubmitted }),
              attribute.id("template-edit-form"),
            ],
            [
              // Name field
              div([attribute.class("field")], [
                label([], [text(t(model.locale, i18n_text.TaskTemplateName))]),
                input([
                  attribute.type_("text"),
                  attribute.value(model.edit_name),
                  event.on_input(EditNameChanged),
                  attribute.required(True),
                ]),
              ]),
              // Description field (textarea with variables hint)
              div([attribute.class("field")], [
                label([], [text(t(model.locale, i18n_text.TaskTemplateDescription))]),
                textarea(
                  [
                    attribute.rows(4),
                    attribute.value(model.edit_description),
                    event.on_input(EditDescriptionChanged),
                  ],
                  model.edit_description,
                ),
                div([attribute.class("field-variables-hint")], [
                  span([attribute.class("field-variables-label")], [
                    text(t(model.locale, i18n_text.AvailableVariables) <> ": "),
                  ]),
                  span([attribute.class("field-variables-list")], [
                    text("{{father}}, {{from_state}}, {{to_state}}, {{project}}, {{user}}"),
                  ]),
                ]),
              ]),
              // Task Type selector
              div([attribute.class("field")], [
                label([], [text(t(model.locale, i18n_text.TaskTemplateType))]),
                view_task_type_selector(model.locale, model.task_types, model.edit_type_id, EditTypeIdChanged),
              ]),
              // Priority selector
              div([attribute.class("field")], [
                label([], [text(t(model.locale, i18n_text.TaskTemplatePriority))]),
                view_priority_selector(model.edit_priority, EditPriorityChanged),
              ]),
            ],
          ),
        ]),
        // Footer
        div([attribute.class("dialog-footer")], [
          view_cancel_button(model.locale, EditCancelled),
          button(
            [
              attribute.type_("submit"),
              attribute.form("template-edit-form"),
              attribute.disabled(model.edit_in_flight),
              attribute.class(case model.edit_in_flight {
                True -> "btn-loading"
                False -> ""
              }),
            ],
            [
              text(case model.edit_in_flight {
                True -> t(model.locale, i18n_text.Working)
                False -> t(model.locale, i18n_text.Save)
              }),
            ],
          ),
        ]),
      ],
    ),
  ])
}

fn view_delete_dialog(model: Model, template: TaskTemplate) -> Element(Msg) {
  div([attribute.class("dialog-overlay")], [
    div(
      [
        attribute.class("dialog dialog-sm"),
        attribute.attribute("role", "dialog"),
        attribute.attribute("aria-modal", "true"),
      ],
      [
        // Header
        view_header(model, i18n_text.DeleteTaskTemplate, "\u{1F5D1}"),
        // Error
        view_error(model.delete_error),
        // Body
        div([attribute.class("dialog-body")], [
          p([], [
            text(t(model.locale, i18n_text.TaskTemplateDeleteConfirm(template.name))),
          ]),
        ]),
        // Footer
        div([attribute.class("dialog-footer")], [
          view_cancel_button(model.locale, DeleteCancelled),
          button(
            [
              event.on_click(DeleteConfirmed),
              attribute.disabled(model.delete_in_flight),
              attribute.class("btn-danger"),
            ],
            [
              text(case model.delete_in_flight {
                True -> t(model.locale, i18n_text.Removing)
                False -> t(model.locale, i18n_text.DeleteTaskTemplate)
              }),
            ],
          ),
        ]),
      ],
    ),
  ])
}

fn view_header(model: Model, title_key: i18n_text.Text, icon: String) -> Element(Msg) {
  div([attribute.class("dialog-header")], [
    div([attribute.class("dialog-title")], [
      span([attribute.class("dialog-icon")], [text(icon)]),
      h3([], [text(t(model.locale, title_key))]),
    ]),
    button(
      [
        attribute.class("btn-icon dialog-close"),
        attribute.type_("button"),
        event.on_click(CloseRequested),
        attribute.attribute("aria-label", "Close"),
      ],
      [text("\u{2715}")],
    ),
  ])
}

fn view_error(error: Option(String)) -> Element(Msg) {
  case error {
    option.Some(msg) ->
      div([attribute.class("dialog-error")], [
        span([], [text("\u{26A0}")]),
        text(" " <> msg),
      ])
    option.None -> element.none()
  }
}

fn view_cancel_button(locale: Locale, on_click_msg: Msg) -> Element(Msg) {
  button(
    [attribute.type_("button"), event.on_click(on_click_msg)],
    [text(t(locale, i18n_text.Cancel))],
  )
}

fn view_task_type_selector(
  locale: Locale,
  task_types: List(TaskType),
  selected_id: Option(Int),
  on_change: fn(String) -> Msg,
) -> Element(Msg) {
  let selected_value = case selected_id {
    option.Some(id) -> int.to_string(id)
    option.None -> ""
  }
  select(
    [
      event.on_input(on_change),
      attribute.value(selected_value),
      attribute.required(True),
    ],
    [
      html_option([attribute.value("")], t(locale, i18n_text.SelectTaskType)),
      ..list.map(task_types, fn(tt) {
        html_option(
          [
            attribute.value(int.to_string(tt.id)),
            attribute.selected(option.Some(tt.id) == selected_id),
          ],
          tt.name,
        )
      })
    ],
  )
}

fn view_priority_selector(
  selected_priority: String,
  on_change: fn(String) -> Msg,
) -> Element(Msg) {
  let priorities = [
    #("1", "1 - Highest"),
    #("2", "2 - High"),
    #("3", "3 - Medium"),
    #("4", "4 - Low"),
    #("5", "5 - Lowest"),
  ]
  select(
    [
      event.on_input(on_change),
      attribute.value(selected_priority),
    ],
    list.map(priorities, fn(p) {
      let #(value, label_text) = p
      html_option(
        [
          attribute.value(value),
          attribute.selected(value == selected_priority),
        ],
        label_text,
      )
    }),
  )
}

// =============================================================================
// i18n Helper
// =============================================================================

fn t(loc: Locale, key: i18n_text.Text) -> String {
  case loc {
    En -> i18n_en.translate(key)
    Es -> i18n_es.translate(key)
  }
}
