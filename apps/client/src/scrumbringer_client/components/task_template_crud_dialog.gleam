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

import lustre
import lustre/attribute
import lustre/component
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html.{
  div, form, input, option as html_option, select, span, text, textarea,
}
import lustre/event

import domain/api_error.{type ApiError, type ApiResult}
import domain/task/codec as task_codec
import domain/task_type.{type TaskType}
import domain/workflow.{type TaskTemplate}
import domain/workflow/codec as workflow_codec

import scrumbringer_client/api/workflows/task_templates as api_task_templates
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
  crud_dialog_base.DialogLifecycle(TaskTemplate)

pub type TaskTemplateFormError {
  InvalidPriority(String)
}

/// Internal component model - encapsulates all 17 task template CRUD fields.
pub type Model {
  Model(
    // Attributes from parent
    locale: Locale,
    project_id: Option(Int),
    mode: DialogMode,
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
  crud_dialog_base.decode_locale(value, LocaleReceived)
}

fn decode_project_id(value: String) -> Result(Msg, Nil) {
  crud_dialog_base.decode_optional_int_attribute(value, ProjectIdReceived)
}

fn decode_mode(value: String) -> Result(Msg, Nil) {
  // edit and delete modes need template data from property
  crud_dialog_base.decode_create_mode(
    value,
    crud_dialog_base.Creating,
    ModeReceived,
  )
}

fn template_property_decoder() -> Decoder(Msg) {
  use template <- decode.then(workflow_codec.task_template_decoder())
  use mode <- decode.field("_mode", decode.string)
  crud_dialog_base.decode_entity_mode(
    mode,
    template,
    crud_dialog_base.Editing,
    crud_dialog_base.Deleting,
    ModeReceived,
  )
}

fn task_types_property_decoder() -> Decoder(Msg) {
  use types <- decode.then(decode.list(task_codec.task_type_decoder()))
  decode.success(TaskTypesReceived(types))
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
    LocaleReceived(loc) -> #(Model(..model, locale: loc), effect.none())

    ProjectIdReceived(id) -> #(Model(..model, project_id: id), effect.none())

    ModeReceived(mode) -> handle_mode_received(model, mode)

    TaskTypesReceived(types) -> #(
      Model(..model, task_types: types),
      effect.none(),
    )

    // Create form handlers
    CreateNameChanged(name) -> #(
      Model(..model, create_name: name),
      effect.none(),
    )

    CreateDescriptionChanged(desc) -> #(
      Model(..model, create_description: desc),
      effect.none(),
    )

    CreateTypeIdChanged(type_id_str) -> #(
      Model(
        ..model,
        create_type_id: crud_dialog_base.optional_int_or_none(type_id_str),
      ),
      effect.none(),
    )

    CreatePriorityChanged(priority) -> #(
      Model(..model, create_priority: priority),
      effect.none(),
    )

    CreateSubmitted -> handle_create_submitted(model)

    CreateResult(Ok(template)) -> handle_create_success(model, template)

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

    EditTypeIdChanged(type_id_str) -> #(
      Model(
        ..model,
        edit_type_id: crud_dialog_base.optional_int_or_none(type_id_str),
      ),
      effect.none(),
    )

    EditPriorityChanged(priority) -> #(
      Model(..model, edit_priority: priority),
      effect.none(),
    )

    EditSubmitted -> handle_edit_submitted(model)

    EditResult(Ok(template)) -> handle_edit_success(model, template)

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

pub fn parse_priority(value: String) -> Result(Int, TaskTemplateFormError) {
  case int.parse(value) {
    Ok(priority) if priority >= 1 && priority <= 5 -> Ok(priority)
    _ -> Error(InvalidPriority(value))
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
        create_type_id: option.None,
        create_priority: "3",
        create_in_flight: False,
        create_error: option.None,
      ),
      effect.none(),
    )

    crud_dialog_base.Editing(template) -> #(
      Model(
        ..model,
        mode: crud_dialog_base.Editing(template),
        edit_name: template.name,
        edit_description: crud_dialog_base.optional_text_input_value(
          template.description,
        ),
        edit_type_id: option.Some(template.type_id),
        edit_priority: int.to_string(template.priority),
        edit_in_flight: False,
        edit_error: option.None,
      ),
      effect.none(),
    )

    crud_dialog_base.Deleting(template) -> #(
      Model(
        ..model,
        mode: crud_dialog_base.Deleting(template),
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
    submit_template_create,
  )
}

fn submit_template_create(model: Model) -> #(Model, Effect(Msg)) {
  case crud_dialog_base.required_text(model.create_name), model.create_type_id {
    Error(_), _ -> #(
      Model(
        ..model,
        create_error: option.Some(t(model.locale, i18n_text.NameRequired)),
      ),
      effect.none(),
    )
    _, option.None -> #(
      Model(
        ..model,
        create_error: option.Some(t(model.locale, i18n_text.TypeRequired)),
      ),
      effect.none(),
    )
    Ok(name), option.Some(type_id) ->
      submit_template_with_type(model, name, type_id)
  }
}

fn submit_template_with_type(
  model: Model,
  name: String,
  type_id: Int,
) -> #(Model, Effect(Msg)) {
  case parse_priority(model.create_priority), model.project_id {
    Error(_), _ -> #(
      Model(
        ..model,
        create_error: option.Some(t(model.locale, i18n_text.PriorityMustBe1To5)),
      ),
      effect.none(),
    )
    _, option.None -> #(
      Model(
        ..model,
        create_error: option.Some(t(model.locale, i18n_text.SelectProjectFirst)),
      ),
      effect.none(),
    )
    Ok(priority), option.Some(project_id) -> #(
      Model(..model, create_in_flight: True, create_error: option.None),
      api_task_templates.create_project_template(
        project_id,
        name,
        model.create_description,
        type_id,
        priority,
        CreateResult,
      ),
    )
  }
}

fn handle_create_success(
  model: Model,
  template: TaskTemplate,
) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      mode: crud_dialog_base.Closed,
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
  crud_dialog_base.submit_if_idle(model, model.edit_in_flight, submit_edit)
}

fn submit_edit(model: Model) -> #(Model, Effect(Msg)) {
  case crud_dialog_base.required_text(model.edit_name), model.edit_type_id {
    Error(_), _ -> #(
      Model(
        ..model,
        edit_error: option.Some(t(model.locale, i18n_text.NameRequired)),
      ),
      effect.none(),
    )
    _, option.None -> #(
      Model(
        ..model,
        edit_error: option.Some(t(model.locale, i18n_text.TypeRequired)),
      ),
      effect.none(),
    )
    Ok(name), option.Some(type_id) ->
      submit_edit_with_fields(model, name, type_id)
  }
}

fn submit_edit_with_fields(
  model: Model,
  name: String,
  type_id: Int,
) -> #(Model, Effect(Msg)) {
  case model.mode {
    crud_dialog_base.Editing(template) ->
      case parse_priority(model.edit_priority) {
        Error(_) -> #(
          Model(
            ..model,
            edit_error: option.Some(t(
              model.locale,
              i18n_text.PriorityMustBe1To5,
            )),
          ),
          effect.none(),
        )
        Ok(priority) -> #(
          Model(..model, edit_in_flight: True, edit_error: option.None),
          api_task_templates.update_template(
            template.id,
            name,
            model.edit_description,
            type_id,
            priority,
            EditResult,
          ),
        )
      }
    _ -> #(model, effect.none())
  }
}

fn handle_edit_success(
  model: Model,
  template: TaskTemplate,
) -> #(Model, Effect(Msg)) {
  #(reset_edit_fields(model), emit_template_updated(template))
}

fn handle_delete_confirmed(model: Model) -> #(Model, Effect(Msg)) {
  crud_dialog_base.submit_if_idle(model, model.delete_in_flight, submit_delete)
}

fn submit_delete(model: Model) -> #(Model, Effect(Msg)) {
  case model.mode {
    crud_dialog_base.Deleting(template) -> #(
      Model(..model, delete_in_flight: True, delete_error: option.None),
      api_task_templates.delete_template(template.id, DeleteResult),
    )
    _ -> #(model, effect.none())
  }
}

fn handle_delete_success(model: Model) -> #(Model, Effect(Msg)) {
  let template_id = case model.mode {
    crud_dialog_base.Deleting(template) -> template.id
    _ -> 0
  }
  #(reset_delete_fields(model), emit_template_deleted(template_id))
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
    edit_type_id: option.None,
    edit_priority: "3",
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
    emit_custom_event(
      "task-template-deleted",
      json.object([#("id", json.int(template_id))]),
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
    crud_dialog_base.Closed -> element.none()
    crud_dialog_base.Creating -> view_create_dialog(model)
    crud_dialog_base.Editing(_template) -> view_edit_dialog(model)
    crud_dialog_base.Deleting(template) -> view_delete_dialog(model, template)
  }
}

fn view_template_fields(
  model: Model,
  name: String,
  description: String,
  type_id: Option(Int),
  priority: String,
  on_name_changed: fn(String) -> Msg,
  on_description_changed: fn(String) -> Msg,
  on_type_changed: fn(String) -> Msg,
  on_priority_changed: fn(String) -> Msg,
  name_aria_label: Option(String),
  description_aria_label: Option(String),
) -> List(Element(Msg)) {
  [
    form_field.view(
      t(model.locale, i18n_text.TaskTemplateName),
      input(
        [
          attribute.type_("text"),
          attribute.value(name),
          event.on_input(on_name_changed),
          attribute.required(True),
        ]
        |> maybe_add_aria_label(name_aria_label),
      ),
    ),
    form_field.view(
      t(model.locale, i18n_text.TaskTemplateDescription),
      div([], [
        textarea(
          [
            attribute.rows(4),
            attribute.value(description),
            event.on_input(on_description_changed),
          ]
            |> maybe_add_aria_label(description_aria_label),
          description,
        ),
        view_template_variables_hint(model),
      ]),
    ),
    form_field.view(
      t(model.locale, i18n_text.TaskTemplateType),
      view_task_type_selector(
        model.locale,
        model.task_types,
        type_id,
        on_type_changed,
      ),
    ),
    form_field.view(
      t(model.locale, i18n_text.TaskTemplatePriority),
      view_priority_selector(priority, on_priority_changed),
    ),
  ]
}

fn maybe_add_aria_label(
  attrs: List(attribute.Attribute(Msg)),
  label: Option(String),
) -> List(attribute.Attribute(Msg)) {
  case label {
    option.Some(value) -> [attribute.attribute("aria-label", value), ..attrs]
    option.None -> attrs
  }
}

fn view_template_variables_hint(model: Model) -> Element(Msg) {
  div([attribute.class("field-variables-hint")], [
    span([attribute.class("field-variables-label")], [
      text(t(model.locale, i18n_text.AvailableVariables) <> ": "),
    ]),
    span([attribute.class("field-variables-list")], [
      text("{{father}}, {{from_state}}, {{to_state}}, {{project}}, {{user}}"),
    ]),
  ])
}

fn view_create_dialog(model: Model) -> Element(Msg) {
  crud_dialog_base.view_dialog_shell(
    "dialog dialog-md",
    modal_header.view_dialog_with_icon(
      t(model.locale, i18n_text.CreateTaskTemplate),
      text("\u{1F4DD}"),
      CloseRequested,
    ),
    model.create_error,
    [
      form(
        [
          event.on_submit(fn(_) { CreateSubmitted }),
          attribute.id("template-create-form"),
        ],
        view_template_fields(
          model,
          model.create_name,
          model.create_description,
          model.create_type_id,
          model.create_priority,
          CreateNameChanged,
          CreateDescriptionChanged,
          CreateTypeIdChanged,
          CreatePriorityChanged,
          option.Some("Template name"),
          option.Some("Template description"),
        ),
      ),
    ],
    [
      crud_dialog_base.view_cancel_button(model.locale, CloseRequested),
      crud_dialog_base.view_submit_button(
        "template-create-form",
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
    modal_header.view_dialog_with_icon(
      t(model.locale, i18n_text.EditTaskTemplate),
      text("\u{270F}"),
      EditCancelled,
    ),
    model.edit_error,
    [
      form(
        [
          event.on_submit(fn(_) { EditSubmitted }),
          attribute.id("template-edit-form"),
        ],
        view_template_fields(
          model,
          model.edit_name,
          model.edit_description,
          model.edit_type_id,
          model.edit_priority,
          EditNameChanged,
          EditDescriptionChanged,
          EditTypeIdChanged,
          EditPriorityChanged,
          option.None,
          option.None,
        ),
      ),
    ],
    [
      crud_dialog_base.view_cancel_button(model.locale, EditCancelled),
      crud_dialog_base.view_submit_button(
        "template-edit-form",
        model.edit_in_flight,
        t(model.locale, i18n_text.Save),
        t(model.locale, i18n_text.Working),
      ),
    ],
  )
}

fn view_delete_dialog(model: Model, template: TaskTemplate) -> Element(Msg) {
  crud_dialog_base.view_delete_dialog_shell(
    model.locale,
    t(model.locale, i18n_text.DeleteTaskTemplate),
    text("\u{1F5D1}"),
    t(model.locale, i18n_text.TaskTemplateDeleteConfirm(template.name)),
    model.delete_error,
    model.delete_in_flight,
    DeleteCancelled,
    DeleteConfirmed,
    t(model.locale, i18n_text.Removing),
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

pub fn view_create_dialog_for_test(
  locale: Locale,
  task_types: List(TaskType),
) -> Element(Msg) {
  let model =
    Model(
      ..default_model(),
      locale: locale,
      mode: crud_dialog_base.Creating,
      task_types: task_types,
    )
  view_create_dialog(model)
}

pub fn view_edit_dialog_for_test(
  locale: Locale,
  template: TaskTemplate,
  task_types: List(TaskType),
) -> Element(Msg) {
  let model =
    Model(
      ..default_model(),
      locale: locale,
      mode: crud_dialog_base.Editing(template),
      task_types: task_types,
      edit_name: template.name,
      edit_description: crud_dialog_base.optional_text_input_value(
        template.description,
      ),
      edit_type_id: option.Some(template.type_id),
      edit_priority: int.to_string(template.priority),
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
