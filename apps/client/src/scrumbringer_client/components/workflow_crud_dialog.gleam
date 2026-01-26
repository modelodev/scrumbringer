//// Workflow CRUD Dialog Component.
////
//// ## Mission
////
//// Encapsulated Lustre Component for workflow create, edit, and delete dialogs.
////
//// ## Responsibilities
////
//// - Handle create dialog: name, description, active fields
//// - Handle edit dialog: prefill from workflow, submit updates
//// - Handle delete confirmation dialog
//// - Emit events to parent for workflow-created, workflow-updated, workflow-deleted
//// - Support both org-scoped and project-scoped workflows
////
//// ## Relations
////
//// - Parent: features/admin/view.gleam renders this component
//// - API: api/workflows.gleam for CRUD operations

import gleam/dynamic/decode.{type Decoder}
import gleam/json
import gleam/option.{type Option}

import lustre
import lustre/attribute
import lustre/component
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html.{button, div, form, h3, input, label, p, span, text}
import lustre/event

import domain/api_error.{type ApiError}
import domain/workflow.{type Workflow, Workflow}

import scrumbringer_client/api/core.{type ApiResult}
import scrumbringer_client/api/workflows as api_workflows
import scrumbringer_client/components/crud_dialog_base
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
  ModeEdit(Workflow)
  ModeDelete(Workflow)
}

/// Internal component model - encapsulates all 15 workflow CRUD fields.
pub type Model {
  Model(
    // Attributes from parent
    locale: Locale,
    project_id: Option(Int),
    mode: Option(DialogMode),
    // Create dialog fields
    create_name: String,
    create_description: String,
    create_active: Bool,
    create_in_flight: Bool,
    create_error: Option(String),
    // Edit dialog fields
    edit_name: String,
    edit_description: String,
    edit_active: Bool,
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
  // Create form
  CreateNameChanged(String)
  CreateDescriptionChanged(String)
  CreateActiveToggled
  CreateSubmitted
  CreateResult(ApiResult(Workflow))
  // Edit form
  EditNameChanged(String)
  EditDescriptionChanged(String)
  EditActiveToggled
  EditSubmitted
  EditResult(ApiResult(Workflow))
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

/// Register the workflow-crud-dialog as a custom element.
/// Call this once at app init. Returns Result to handle registration errors.
pub fn register() -> Result(Nil, lustre.Error) {
  lustre.component(init, update, view, on_attribute_change())
  |> lustre.register("workflow-crud-dialog")
}

/// Build attribute/property change handlers.
fn on_attribute_change() -> List(component.Option(Msg)) {
  [
    component.on_attribute_change("locale", decode_locale),
    component.on_attribute_change("project-id", decode_project_id),
    component.on_attribute_change("mode", decode_mode),
    component.on_property_change("workflow", workflow_property_decoder()),
    component.adopt_styles(True),
  ]
}

fn decode_locale(value: String) -> Result(Msg, Nil) {
  crud_dialog_base.decode_locale(value, LocaleReceived)
}

fn decode_project_id(value: String) -> Result(Msg, Nil) {
  crud_dialog_base.decode_optional_int_attribute(value, ProjectIdReceived)
}

fn decode_mode(value: String) -> Result(Msg, Nil) {
  // edit and delete modes need workflow data from property
  crud_dialog_base.decode_create_mode(value, ModeCreate, ModeReceived)
}

fn workflow_property_decoder() -> Decoder(Msg) {
  use id <- decode.field("id", decode.int)
  use org_id <- decode.field("org_id", decode.int)
  use project_id <- decode.field("project_id", decode.optional(decode.int))
  use name <- decode.field("name", decode.string)
  use description <- decode.field("description", decode.optional(decode.string))
  use active <- decode.field("active", decode.bool)
  use rule_count <- decode.field("rule_count", decode.int)
  use created_by <- decode.field("created_by", decode.int)
  use created_at <- decode.field("created_at", decode.string)
  use mode <- decode.field("_mode", decode.string)
  let workflow =
    Workflow(
      id: id,
      org_id: org_id,
      project_id: project_id,
      name: name,
      description: description,
      active: active,
      rule_count: rule_count,
      created_by: created_by,
      created_at: created_at,
    )
  case mode {
    "edit" -> decode.success(ModeReceived(ModeEdit(workflow)))
    "delete" -> decode.success(ModeReceived(ModeDelete(workflow)))
    _ -> decode.success(ModeReceived(ModeEdit(workflow)))
  }
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
    create_name: "",
    create_description: "",
    create_active: True,
    create_in_flight: False,
    create_error: option.None,
    edit_name: "",
    edit_description: "",
    edit_active: True,
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
    LocaleReceived(loc) -> #(Model(..model, locale: loc), effect.none())

    ProjectIdReceived(id) -> #(Model(..model, project_id: id), effect.none())

    ModeReceived(mode) -> handle_mode_received(model, mode)

    // Create form handlers
    CreateNameChanged(name) -> #(
      Model(..model, create_name: name),
      effect.none(),
    )

    CreateDescriptionChanged(desc) -> #(
      Model(..model, create_description: desc),
      effect.none(),
    )

    CreateActiveToggled -> #(
      Model(..model, create_active: !model.create_active),
      effect.none(),
    )

    CreateSubmitted -> handle_create_submitted(model)

    CreateResult(Ok(workflow)) -> handle_create_success(model, workflow)

    CreateResult(Error(err)) -> #(
      Model(
        ..model,
        create_in_flight: False,
        create_error: option.Some(err.message),
      ),
      effect.none(),
    )

    // Edit form handlers
    EditNameChanged(name) -> #(Model(..model, edit_name: name), effect.none())

    EditDescriptionChanged(desc) -> #(
      Model(..model, edit_description: desc),
      effect.none(),
    )

    EditActiveToggled -> #(
      Model(..model, edit_active: !model.edit_active),
      effect.none(),
    )

    EditSubmitted -> handle_edit_submitted(model)

    EditResult(Ok(workflow)) -> handle_edit_success(model, workflow)

    EditResult(Error(err)) -> #(
      Model(
        ..model,
        edit_in_flight: False,
        edit_error: option.Some(err.message),
      ),
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
        mode: option.Some(ModeCreate),
        create_name: "",
        create_description: "",
        create_active: True,
        create_in_flight: False,
        create_error: option.None,
      ),
      effect.none(),
    )

    ModeEdit(workflow) -> #(
      Model(
        ..model,
        mode: option.Some(ModeEdit(workflow)),
        edit_name: workflow.name,
        edit_description: option.unwrap(workflow.description, ""),
        edit_active: workflow.active,
        edit_in_flight: False,
        edit_error: option.None,
      ),
      effect.none(),
    )

    ModeDelete(workflow) -> #(
      Model(
        ..model,
        mode: option.Some(ModeDelete(workflow)),
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
      case model.create_name {
        "" -> #(
          Model(
            ..model,
            create_error: option.Some(t(model.locale, i18n_text.NameRequired)),
          ),
          effect.none(),
        )
        name ->
          // Workflows are now project-scoped only
          case model.project_id {
            option.Some(project_id) -> #(
              Model(..model, create_in_flight: True, create_error: option.None),
              api_workflows.create_project_workflow(
                project_id,
                name,
                model.create_description,
                model.create_active,
                CreateResult,
              ),
            )
            option.None -> #(
              Model(
                ..model,
                create_error: option.Some(t(
                  model.locale,
                  i18n_text.SelectProjectFirst,
                )),
              ),
              effect.none(),
            )
          }
      }
  }
}

fn handle_create_success(
  model: Model,
  workflow: Workflow,
) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      mode: option.None,
      create_name: "",
      create_description: "",
      create_active: True,
      create_in_flight: False,
      create_error: option.None,
    ),
    emit_workflow_created(workflow),
  )
}

fn handle_edit_submitted(model: Model) -> #(Model, Effect(Msg)) {
  case model.edit_in_flight {
    True -> #(model, effect.none())
    False ->
      case model.edit_name {
        "" -> #(
          Model(
            ..model,
            edit_error: option.Some(t(model.locale, i18n_text.NameRequired)),
          ),
          effect.none(),
        )
        name ->
          case model.mode {
            option.Some(ModeEdit(workflow)) -> #(
              Model(..model, edit_in_flight: True, edit_error: option.None),
              api_workflows.update_workflow(
                workflow.id,
                name,
                model.edit_description,
                model.edit_active,
                EditResult,
              ),
            )
            _ -> #(model, effect.none())
          }
      }
  }
}

fn handle_edit_success(
  model: Model,
  workflow: Workflow,
) -> #(Model, Effect(Msg)) {
  #(reset_edit_fields(model), emit_workflow_updated(workflow))
}

fn handle_delete_confirmed(model: Model) -> #(Model, Effect(Msg)) {
  case model.delete_in_flight {
    True -> #(model, effect.none())
    False ->
      case model.mode {
        option.Some(ModeDelete(workflow)) -> #(
          Model(..model, delete_in_flight: True, delete_error: option.None),
          api_workflows.delete_workflow(workflow.id, DeleteResult),
        )
        _ -> #(model, effect.none())
      }
  }
}

fn handle_delete_success(model: Model) -> #(Model, Effect(Msg)) {
  let workflow_id = case model.mode {
    option.Some(ModeDelete(workflow)) -> workflow.id
    _ -> 0
  }
  #(reset_delete_fields(model), emit_workflow_deleted(workflow_id))
}

fn handle_delete_error(model: Model, err: ApiError) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      delete_in_flight: False,
      delete_error: option.Some(err.message),
    ),
    effect.none(),
  )
}

fn reset_edit_fields(model: Model) -> Model {
  Model(
    ..model,
    mode: option.None,
    edit_name: "",
    edit_description: "",
    edit_active: True,
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

fn emit_workflow_created(workflow: Workflow) -> Effect(Msg) {
  effect.from(fn(_dispatch) {
    emit_custom_event("workflow-created", workflow_to_json(workflow))
  })
}

fn emit_workflow_updated(workflow: Workflow) -> Effect(Msg) {
  effect.from(fn(_dispatch) {
    emit_custom_event("workflow-updated", workflow_to_json(workflow))
  })
}

fn emit_workflow_deleted(workflow_id: Int) -> Effect(Msg) {
  effect.from(fn(_dispatch) {
    emit_custom_event(
      "workflow-deleted",
      json.object([#("id", json.int(workflow_id))]),
    )
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

fn workflow_to_json(workflow: Workflow) -> json.Json {
  let project_id_field = case workflow.project_id {
    option.Some(id) -> [#("project_id", json.int(id))]
    option.None -> [#("project_id", json.null())]
  }
  let description_field = case workflow.description {
    option.Some(desc) -> [#("description", json.string(desc))]
    option.None -> [#("description", json.null())]
  }
  json.object(
    [
      #("id", json.int(workflow.id)),
      #("org_id", json.int(workflow.org_id)),
      #("name", json.string(workflow.name)),
      #("active", json.bool(workflow.active)),
      #("rule_count", json.int(workflow.rule_count)),
      #("created_by", json.int(workflow.created_by)),
      #("created_at", json.string(workflow.created_at)),
    ]
    |> append_fields(project_id_field)
    |> append_fields(description_field),
  )
}

fn append_fields(
  base: List(#(String, json.Json)),
  fields: List(#(String, json.Json)),
) -> List(#(String, json.Json)) {
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
    option.Some(ModeEdit(_workflow)) -> view_edit_dialog(model)
    option.Some(ModeDelete(workflow)) -> view_delete_dialog(model, workflow)
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
        view_header(model, i18n_text.CreateWorkflow, "\u{2699}"),
        // Error
        view_error(model.create_error),
        // Body
        div([attribute.class("dialog-body")], [
          form(
            [
              event.on_submit(fn(_) { CreateSubmitted }),
              attribute.id("workflow-create-form"),
            ],
            [
              // Name field
              div([attribute.class("field")], [
                label([], [text(t(model.locale, i18n_text.WorkflowName))]),
                input([
                  attribute.type_("text"),
                  attribute.value(model.create_name),
                  event.on_input(CreateNameChanged),
                  attribute.required(True),
                  attribute.attribute("aria-label", "Workflow name"),
                ]),
              ]),
              // Description field
              div([attribute.class("field")], [
                label([], [text(t(model.locale, i18n_text.WorkflowDescription))]),
                input([
                  attribute.type_("text"),
                  attribute.value(model.create_description),
                  event.on_input(CreateDescriptionChanged),
                  attribute.attribute("aria-label", "Workflow description"),
                ]),
              ]),
              // Active checkbox
              div([attribute.class("field field-checkbox")], [
                label([attribute.class("checkbox-label")], [
                  input([
                    attribute.type_("checkbox"),
                    attribute.checked(model.create_active),
                    event.on_check(fn(_) { CreateActiveToggled }),
                  ]),
                  text(" " <> t(model.locale, i18n_text.WorkflowActive)),
                ]),
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
              attribute.form("workflow-create-form"),
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
        view_header(model, i18n_text.EditWorkflow, "\u{270F}"),
        // Error
        view_error(model.edit_error),
        // Body
        div([attribute.class("dialog-body")], [
          form(
            [
              event.on_submit(fn(_) { EditSubmitted }),
              attribute.id("workflow-edit-form"),
            ],
            [
              // Name field
              div([attribute.class("field")], [
                label([], [text(t(model.locale, i18n_text.WorkflowName))]),
                input([
                  attribute.type_("text"),
                  attribute.value(model.edit_name),
                  event.on_input(EditNameChanged),
                  attribute.required(True),
                ]),
              ]),
              // Description field
              div([attribute.class("field")], [
                label([], [text(t(model.locale, i18n_text.WorkflowDescription))]),
                input([
                  attribute.type_("text"),
                  attribute.value(model.edit_description),
                  event.on_input(EditDescriptionChanged),
                ]),
              ]),
              // Active checkbox
              div([attribute.class("field field-checkbox")], [
                label([attribute.class("checkbox-label")], [
                  input([
                    attribute.type_("checkbox"),
                    attribute.checked(model.edit_active),
                    event.on_check(fn(_) { EditActiveToggled }),
                  ]),
                  text(" " <> t(model.locale, i18n_text.WorkflowActive)),
                ]),
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
              attribute.form("workflow-edit-form"),
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

fn view_delete_dialog(model: Model, workflow: Workflow) -> Element(Msg) {
  div([attribute.class("dialog-overlay")], [
    div(
      [
        attribute.class("dialog dialog-sm"),
        attribute.attribute("role", "dialog"),
        attribute.attribute("aria-modal", "true"),
      ],
      [
        // Header
        view_header(model, i18n_text.DeleteWorkflow, "\u{1F5D1}"),
        // Error
        view_error(model.delete_error),
        // Body
        div([attribute.class("dialog-body")], [
          p([], [
            text(t(model.locale, i18n_text.WorkflowDeleteConfirm(workflow.name))),
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
                False -> t(model.locale, i18n_text.DeleteWorkflow)
              }),
            ],
          ),
        ]),
      ],
    ),
  ])
}

fn view_header(
  model: Model,
  title_key: i18n_text.Text,
  icon: String,
) -> Element(Msg) {
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
  button([attribute.type_("button"), event.on_click(on_click_msg)], [
    text(t(locale, i18n_text.Cancel)),
  ])
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
