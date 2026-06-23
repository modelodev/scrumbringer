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
import lustre/element/html.{form, input, text}
import lustre/event

import domain/api_error.{type ApiError, type ApiResult}
import domain/workflow.{type Workflow}
import domain/workflow/workflow_codec

import scrumbringer_client/api/workflows as api_workflows
import scrumbringer_client/components/crud_dialog_base
import scrumbringer_client/i18n/en as i18n_en
import scrumbringer_client/i18n/es as i18n_es
import scrumbringer_client/i18n/locale.{type Locale, En, Es}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/form_field
import scrumbringer_client/ui/modal_header

// =============================================================================
// Internal Types
// =============================================================================

/// Dialog mode determines which view to show.
pub type DialogMode =
  crud_dialog_base.DialogLifecycle(Workflow)

/// Internal component model - encapsulates all 15 workflow CRUD fields.
pub type Model {
  Model(
    // Attributes from parent
    locale: Locale,
    project_id: Option(Int),
    mode: DialogMode,
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
  crud_dialog_base.decode_create_mode(
    value,
    crud_dialog_base.Creating,
    ModeReceived,
  )
}

fn workflow_property_decoder() -> Decoder(Msg) {
  use workflow <- decode.then(workflow_codec.workflow_decoder())
  use mode <- decode.field("_mode", decode.string)
  crud_dialog_base.decode_entity_mode(
    mode,
    workflow,
    crud_dialog_base.Editing,
    crud_dialog_base.Deleting,
    ModeReceived,
  )
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
    mode: crud_dialog_base.Closed,
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
    crud_dialog_base.Closed -> #(
      Model(..model, mode: crud_dialog_base.Closed),
      effect.none(),
    )

    crud_dialog_base.Creating -> #(
      Model(
        ..model,
        mode: crud_dialog_base.Creating,
        create_name: "",
        create_description: "",
        create_active: True,
        create_in_flight: False,
        create_error: option.None,
      ),
      effect.none(),
    )

    crud_dialog_base.Editing(workflow) -> #(
      Model(
        ..model,
        mode: crud_dialog_base.Editing(workflow),
        edit_name: workflow.name,
        edit_description: crud_dialog_base.optional_text_input_value(
          workflow.description,
        ),
        edit_active: workflow.active,
        edit_in_flight: False,
        edit_error: option.None,
      ),
      effect.none(),
    )

    crud_dialog_base.Deleting(workflow) -> #(
      Model(
        ..model,
        mode: crud_dialog_base.Deleting(workflow),
        delete_in_flight: False,
        delete_error: option.None,
      ),
      effect.none(),
    )
  }
}

fn handle_create_submitted(model: Model) -> #(Model, Effect(Msg)) {
  crud_dialog_base.submit_if_idle(
    model,
    model.create_in_flight,
    submit_workflow_name,
  )
}

fn submit_workflow_name(model: Model) -> #(Model, Effect(Msg)) {
  case crud_dialog_base.required_text(model.create_name) {
    Error(_) -> #(
      Model(
        ..model,
        create_error: option.Some(t(model.locale, i18n_text.NameRequired)),
      ),
      effect.none(),
    )
    Ok(name) -> submit_workflow_with_name(model, name)
  }
}

fn submit_workflow_with_name(
  model: Model,
  name: String,
) -> #(Model, Effect(Msg)) {
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
        create_error: option.Some(t(model.locale, i18n_text.SelectProjectFirst)),
      ),
      effect.none(),
    )
  }
}

fn handle_create_success(
  model: Model,
  workflow: Workflow,
) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      mode: crud_dialog_base.Closed,
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
  crud_dialog_base.submit_if_idle(model, model.edit_in_flight, submit_edit)
}

fn submit_edit(model: Model) -> #(Model, Effect(Msg)) {
  case crud_dialog_base.required_text(model.edit_name) {
    Error(_) -> #(
      Model(
        ..model,
        edit_error: option.Some(t(model.locale, i18n_text.NameRequired)),
      ),
      effect.none(),
    )
    Ok(name) -> submit_edit_with_name(model, name)
  }
}

fn submit_edit_with_name(model: Model, name: String) -> #(Model, Effect(Msg)) {
  case model.mode {
    crud_dialog_base.Editing(workflow) -> #(
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

fn handle_edit_success(
  model: Model,
  workflow: Workflow,
) -> #(Model, Effect(Msg)) {
  #(reset_edit_fields(model), emit_workflow_updated(workflow))
}

fn handle_delete_confirmed(model: Model) -> #(Model, Effect(Msg)) {
  crud_dialog_base.submit_if_idle(model, model.delete_in_flight, submit_delete)
}

fn submit_delete(model: Model) -> #(Model, Effect(Msg)) {
  case model.mode {
    crud_dialog_base.Deleting(workflow) -> #(
      Model(..model, delete_in_flight: True, delete_error: option.None),
      api_workflows.delete_workflow(workflow.id, DeleteResult),
    )
    _ -> #(model, effect.none())
  }
}

fn handle_delete_success(model: Model) -> #(Model, Effect(Msg)) {
  let workflow_id = case model.mode {
    crud_dialog_base.Deleting(workflow) -> workflow.id
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
    mode: crud_dialog_base.Closed,
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
    mode: crud_dialog_base.Closed,
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
    |> crud_dialog_base.prepend_fields(project_id_field)
    |> crud_dialog_base.prepend_fields(description_field),
  )
}

// =============================================================================
// View
// =============================================================================

fn view(model: Model) -> Element(Msg) {
  case model.mode {
    crud_dialog_base.Closed -> element.none()
    crud_dialog_base.Creating -> view_create_dialog(model)
    crud_dialog_base.Editing(_workflow) -> view_edit_dialog(model)
    crud_dialog_base.Deleting(workflow) -> view_delete_dialog(model, workflow)
  }
}

fn view_workflow_fields(
  model: Model,
  name: String,
  description: String,
  active: Bool,
  on_name_changed: fn(String) -> Msg,
  on_description_changed: fn(String) -> Msg,
  on_active_toggled: Msg,
  name_aria_label: Option(String),
  description_aria_label: Option(String),
) -> List(Element(Msg)) {
  [
    form_field.view(
      t(model.locale, i18n_text.WorkflowName),
      input(
        [
          attribute.type_("text"),
          attribute.value(name),
          event.on_input(on_name_changed),
          attribute.required(True),
        ]
        |> crud_dialog_base.with_optional_aria_label(name_aria_label),
      ),
    ),
    form_field.view(
      t(model.locale, i18n_text.WorkflowDescription),
      input(
        [
          attribute.type_("text"),
          attribute.value(description),
          event.on_input(on_description_changed),
        ]
        |> crud_dialog_base.with_optional_aria_label(description_aria_label),
      ),
    ),
    form_field.view_checkbox(
      t(model.locale, i18n_text.WorkflowActive),
      input([
        attribute.type_("checkbox"),
        attribute.checked(active),
        event.on_check(fn(_) { on_active_toggled }),
      ]),
    ),
  ]
}

fn view_create_dialog(model: Model) -> Element(Msg) {
  crud_dialog_base.view_dialog_shell(
    "dialog dialog-md",
    modal_header.view_dialog_with_icon_and_close_label(
      t(model.locale, i18n_text.CreateWorkflow),
      text("\u{2699}"),
      CloseRequested,
      t(model.locale, i18n_text.Close),
    ),
    model.create_error,
    [
      form(
        [
          event.on_submit(fn(_) { CreateSubmitted }),
          attribute.id("workflow-create-form"),
        ],
        view_workflow_fields(
          model,
          model.create_name,
          model.create_description,
          model.create_active,
          CreateNameChanged,
          CreateDescriptionChanged,
          CreateActiveToggled,
          option.Some("Engine name"),
          option.Some("Engine description"),
        ),
      ),
    ],
    [
      crud_dialog_base.view_cancel_button(model.locale, CloseRequested),
      crud_dialog_base.view_submit_button(
        "workflow-create-form",
        model.create_in_flight,
        t(model.locale, i18n_text.Create),
        t(model.locale, i18n_text.Creating),
      ),
    ],
  )
}

fn view_edit_dialog(model: Model) -> Element(Msg) {
  crud_dialog_base.view_dialog_shell(
    "dialog dialog-md",
    modal_header.view_dialog_with_icon_and_close_label(
      t(model.locale, i18n_text.EditWorkflow),
      text("\u{270F}"),
      EditCancelled,
      t(model.locale, i18n_text.Close),
    ),
    model.edit_error,
    [
      form(
        [
          event.on_submit(fn(_) { EditSubmitted }),
          attribute.id("workflow-edit-form"),
        ],
        view_workflow_fields(
          model,
          model.edit_name,
          model.edit_description,
          model.edit_active,
          EditNameChanged,
          EditDescriptionChanged,
          EditActiveToggled,
          option.None,
          option.None,
        ),
      ),
    ],
    [
      crud_dialog_base.view_cancel_button(model.locale, EditCancelled),
      crud_dialog_base.view_submit_button(
        "workflow-edit-form",
        model.edit_in_flight,
        t(model.locale, i18n_text.Save),
        t(model.locale, i18n_text.Working),
      ),
    ],
  )
}

fn view_delete_dialog(model: Model, workflow: Workflow) -> Element(Msg) {
  crud_dialog_base.view_delete_dialog_shell(
    model.locale,
    t(model.locale, i18n_text.DeleteWorkflow),
    text("\u{1F5D1}"),
    t(model.locale, i18n_text.WorkflowDeleteConfirm(workflow.name)),
    model.delete_error,
    model.delete_in_flight,
    DeleteCancelled,
    DeleteConfirmed,
    t(model.locale, i18n_text.Removing),
  )
}

pub fn view_create_dialog_for_test(locale: Locale) -> Element(Msg) {
  let model =
    Model(..default_model(), locale: locale, mode: crud_dialog_base.Creating)
  view_create_dialog(model)
}

pub fn view_edit_dialog_for_test(
  locale: Locale,
  workflow: Workflow,
) -> Element(Msg) {
  let model =
    Model(
      ..default_model(),
      locale: locale,
      mode: crud_dialog_base.Editing(workflow),
      edit_name: workflow.name,
      edit_description: crud_dialog_base.optional_text_input_value(
        workflow.description,
      ),
      edit_active: workflow.active,
    )
  view_edit_dialog(model)
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
