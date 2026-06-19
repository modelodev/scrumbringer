//// Rule CRUD Dialog Component.
////
//// ## Mission
////
//// Encapsulated Lustre Component for rule create, edit, and delete dialogs.
////
//// ## Responsibilities
////
//// - Handle create dialog: name, goal, resource_type, task_type_id (conditional), to_state, active
//// - Handle edit dialog: prefill from rule, submit updates
//// - Handle delete confirmation dialog
//// - Emit events to parent for rule-created, rule-updated, rule-deleted
//// - Conditional field visibility: task_type_id only when resource_type == "task"
//// - Dynamic state options based on resource_type
////
//// ## Relations
////
//// - Parent: features/admin/view.gleam renders this component
//// - API: api/workflows/rules.gleam for CRUD operations

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
import lustre/element/html.{form, input, option as html_option, select, text}
import lustre/event

import domain/api_error.{type ApiError, type ApiResult}
import domain/card.{
  Active, Closed, Draft, state_to_string as card_state_to_string,
}
import domain/task/task_codec
import domain/task_status.{
  Available, Claimed, Done, Taken, task_status_to_string,
}
import domain/task_type.{type TaskType}
import domain/workflow.{
  type Rule, rule_resource_type, rule_task_type_id, rule_to_state_string,
}
import domain/workflow/workflow_codec

import scrumbringer_client/api/workflows/rules as api_rules
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
  crud_dialog_base.DialogLifecycle(Rule)

/// Internal component model - encapsulates all 21 rule CRUD fields.
pub type Model {
  Model(
    // Attributes from parent
    locale: Locale,
    workflow_id: Option(Int),
    mode: DialogMode,
    task_types: List(TaskType),
    // Create dialog fields
    create_name: String,
    create_goal: String,
    create_resource_type: String,
    create_task_type_id: Option(Int),
    create_to_state: String,
    create_active: Bool,
    create_in_flight: Bool,
    create_error: Option(String),
    // Edit dialog fields
    edit_name: String,
    edit_goal: String,
    edit_resource_type: String,
    edit_task_type_id: Option(Int),
    edit_to_state: String,
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
  WorkflowIdReceived(Option(Int))
  ModeReceived(DialogMode)
  TaskTypesReceived(List(TaskType))
  // Create form
  CreateNameChanged(String)
  CreateGoalChanged(String)
  CreateResourceTypeChanged(String)
  CreateTaskTypeIdChanged(String)
  CreateToStateChanged(String)
  CreateActiveChanged(Bool)
  CreateSubmitted
  CreateResult(ApiResult(Rule))
  // Edit form
  EditNameChanged(String)
  EditGoalChanged(String)
  EditResourceTypeChanged(String)
  EditTaskTypeIdChanged(String)
  EditToStateChanged(String)
  EditActiveChanged(Bool)
  EditSubmitted
  EditResult(ApiResult(Rule))
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

/// Register the rule-crud-dialog as a custom element.
/// Call this once at app init. Returns Result to handle registration errors.
pub fn register() -> Result(Nil, lustre.Error) {
  lustre.component(init, update, view, on_attribute_change())
  |> lustre.register("rule-crud-dialog")
}

/// Build attribute/property change handlers.
fn on_attribute_change() -> List(component.Option(Msg)) {
  [
    component.on_attribute_change("locale", decode_locale),
    component.on_attribute_change("workflow-id", decode_workflow_id),
    component.on_attribute_change("mode", decode_mode),
    component.on_property_change("rule", rule_property_decoder()),
    component.on_property_change("task-types", task_types_property_decoder()),
    component.adopt_styles(True),
  ]
}

fn decode_locale(value: String) -> Result(Msg, Nil) {
  crud_dialog_base.decode_locale(value, LocaleReceived)
}

fn decode_workflow_id(value: String) -> Result(Msg, Nil) {
  crud_dialog_base.decode_optional_int_attribute(value, WorkflowIdReceived)
}

fn decode_mode(value: String) -> Result(Msg, Nil) {
  // edit and delete modes need rule data from property
  crud_dialog_base.decode_create_mode(
    value,
    crud_dialog_base.Creating,
    ModeReceived,
  )
}

fn rule_property_decoder() -> Decoder(Msg) {
  use rule <- decode.then(workflow_codec.rule_decoder())
  use mode <- decode.field("_mode", decode.string)
  crud_dialog_base.decode_entity_mode(
    mode,
    rule,
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
    workflow_id: option.None,
    mode: crud_dialog_base.Closed,
    task_types: [],
    create_name: "",
    create_goal: "",
    create_resource_type: "task",
    create_task_type_id: option.None,
    create_to_state: "completed",
    create_active: True,
    create_in_flight: False,
    create_error: option.None,
    edit_name: "",
    edit_goal: "",
    edit_resource_type: "task",
    edit_task_type_id: option.None,
    edit_to_state: "completed",
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

    WorkflowIdReceived(id) -> #(Model(..model, workflow_id: id), effect.none())

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

    CreateGoalChanged(goal) -> #(
      Model(..model, create_goal: goal),
      effect.none(),
    )

    CreateResourceTypeChanged(resource_type) ->
      handle_create_resource_type_changed(model, resource_type)

    CreateTaskTypeIdChanged(type_id_str) -> #(
      Model(
        ..model,
        create_task_type_id: crud_dialog_base.optional_int_or_none(type_id_str),
      ),
      effect.none(),
    )

    CreateToStateChanged(to_state) -> #(
      Model(..model, create_to_state: to_state),
      effect.none(),
    )

    CreateActiveChanged(active) -> #(
      Model(..model, create_active: active),
      effect.none(),
    )

    CreateSubmitted -> handle_create_submitted(model)

    CreateResult(Ok(rule)) -> handle_create_success(model, rule)

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

    EditGoalChanged(goal) -> #(Model(..model, edit_goal: goal), effect.none())

    EditResourceTypeChanged(resource_type) ->
      handle_edit_resource_type_changed(model, resource_type)

    EditTaskTypeIdChanged(type_id_str) -> #(
      Model(
        ..model,
        edit_task_type_id: crud_dialog_base.optional_int_or_none(type_id_str),
      ),
      effect.none(),
    )

    EditToStateChanged(to_state) -> #(
      Model(..model, edit_to_state: to_state),
      effect.none(),
    )

    EditActiveChanged(active) -> #(
      Model(..model, edit_active: active),
      effect.none(),
    )

    EditSubmitted -> handle_edit_submitted(model)

    EditResult(Ok(rule)) -> handle_edit_success(model, rule)

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
        create_goal: "",
        create_resource_type: "task",
        create_task_type_id: option.None,
        create_to_state: "completed",
        create_active: True,
        create_in_flight: False,
        create_error: option.None,
      ),
      effect.none(),
    )

    crud_dialog_base.Editing(rule) -> #(
      Model(
        ..model,
        mode: crud_dialog_base.Editing(rule),
        edit_name: rule.name,
        edit_goal: crud_dialog_base.optional_text_input_value(rule.goal),
        edit_resource_type: rule_resource_type(rule),
        edit_task_type_id: rule_task_type_id(rule),
        edit_to_state: rule_to_state_string(rule),
        edit_active: rule.active,
        edit_in_flight: False,
        edit_error: option.None,
      ),
      effect.none(),
    )

    crud_dialog_base.Deleting(rule) -> #(
      Model(
        ..model,
        mode: crud_dialog_base.Deleting(rule),
        delete_in_flight: False,
        delete_error: option.None,
      ),
      effect.none(),
    )
  }
}

/// Handle resource type change in create form.
/// Resets task_type_id and to_state to valid defaults for the new resource type.
fn handle_create_resource_type_changed(
  model: Model,
  resource_type: String,
) -> #(Model, Effect(Msg)) {
  let task_type_id = case resource_type {
    "task" -> model.create_task_type_id
    _ -> option.None
  }
  let to_state = default_state_for_resource_type(resource_type)
  #(
    Model(
      ..model,
      create_resource_type: resource_type,
      create_task_type_id: task_type_id,
      create_to_state: to_state,
    ),
    effect.none(),
  )
}

/// Handle resource type change in edit form.
/// Resets task_type_id and to_state to valid defaults for the new resource type.
fn handle_edit_resource_type_changed(
  model: Model,
  resource_type: String,
) -> #(Model, Effect(Msg)) {
  let task_type_id = case resource_type {
    "task" -> model.edit_task_type_id
    _ -> option.None
  }
  let to_state = default_state_for_resource_type(resource_type)
  #(
    Model(
      ..model,
      edit_resource_type: resource_type,
      edit_task_type_id: task_type_id,
      edit_to_state: to_state,
    ),
    effect.none(),
  )
}

/// Get default state for a resource type.
fn default_state_for_resource_type(resource_type: String) -> String {
  case resource_type {
    "task" -> "available"
    _ -> "pendiente"
  }
}

fn handle_create_submitted(model: Model) -> #(Model, Effect(Msg)) {
  crud_dialog_base.submit_if_idle(model, model.create_in_flight, submit_create)
}

fn submit_create(model: Model) -> #(Model, Effect(Msg)) {
  case model.workflow_id, crud_dialog_base.required_text(model.create_name) {
    option.None, _ -> #(model, effect.none())
    _, Error(_) -> #(
      Model(
        ..model,
        create_error: option.Some(t(model.locale, i18n_text.NameRequired)),
      ),
      effect.none(),
    )
    option.Some(workflow_id), Ok(name) ->
      case
        parse_form_target(
          model.create_resource_type,
          model.create_task_type_id,
          model.create_to_state,
        )
      {
        Ok(target) -> #(
          Model(..model, create_in_flight: True, create_error: option.None),
          api_rules.create_rule(
            workflow_id,
            name,
            model.create_goal,
            target,
            model.create_active,
            CreateResult,
          ),
        )
        Error(message) -> #(
          Model(..model, create_error: option.Some(message)),
          effect.none(),
        )
      }
  }
}

fn handle_create_success(model: Model, rule: Rule) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      mode: crud_dialog_base.Closed,
      create_name: "",
      create_goal: "",
      create_resource_type: "task",
      create_task_type_id: option.None,
      create_to_state: "completed",
      create_active: True,
      create_in_flight: False,
      create_error: option.None,
    ),
    emit_rule_created(rule),
  )
}

fn handle_edit_submitted(model: Model) -> #(Model, Effect(Msg)) {
  crud_dialog_base.submit_if_idle(model, model.edit_in_flight, submit_edit_name)
}

fn submit_edit_name(model: Model) -> #(Model, Effect(Msg)) {
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
    crud_dialog_base.Editing(rule) ->
      case
        parse_form_target(
          model.edit_resource_type,
          model.edit_task_type_id,
          model.edit_to_state,
        )
      {
        Ok(target) -> #(
          Model(..model, edit_in_flight: True, edit_error: option.None),
          api_rules.update_rule(
            rule.id,
            name,
            model.edit_goal,
            target,
            model.edit_active,
            EditResult,
          ),
        )
        Error(message) -> #(
          Model(..model, edit_error: option.Some(message)),
          effect.none(),
        )
      }
    _ -> #(model, effect.none())
  }
}

fn parse_form_target(
  resource_type: String,
  task_type_id: Option(Int),
  to_state: String,
) -> Result(workflow.RuleTarget, String) {
  case workflow.parse_rule_target(resource_type, task_type_id, to_state) {
    Ok(target) -> Ok(target)
    Error(_) -> Error("Invalid rule target")
  }
}

fn handle_edit_success(model: Model, rule: Rule) -> #(Model, Effect(Msg)) {
  #(reset_edit_fields(model), emit_rule_updated(rule))
}

fn handle_delete_confirmed(model: Model) -> #(Model, Effect(Msg)) {
  crud_dialog_base.submit_if_idle(model, model.delete_in_flight, submit_delete)
}

fn submit_delete(model: Model) -> #(Model, Effect(Msg)) {
  case model.mode {
    crud_dialog_base.Deleting(rule) -> #(
      Model(..model, delete_in_flight: True, delete_error: option.None),
      api_rules.delete_rule(rule.id, DeleteResult),
    )
    _ -> #(model, effect.none())
  }
}

fn handle_delete_success(model: Model) -> #(Model, Effect(Msg)) {
  let rule_id = case model.mode {
    crud_dialog_base.Deleting(rule) -> rule.id
    _ -> 0
  }
  #(reset_delete_fields(model), emit_rule_deleted(rule_id))
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
    edit_goal: "",
    edit_resource_type: "task",
    edit_task_type_id: option.None,
    edit_to_state: "completed",
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

fn emit_rule_created(rule: Rule) -> Effect(Msg) {
  effect.from(fn(_dispatch) {
    emit_custom_event("rule-created", rule_to_json(rule))
  })
}

fn emit_rule_updated(rule: Rule) -> Effect(Msg) {
  effect.from(fn(_dispatch) {
    emit_custom_event("rule-updated", rule_to_json(rule))
  })
}

fn emit_rule_deleted(rule_id: Int) -> Effect(Msg) {
  effect.from(fn(_dispatch) {
    emit_custom_event("rule-deleted", json.object([#("id", json.int(rule_id))]))
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

fn rule_to_json(rule: Rule) -> json.Json {
  let task_type_id = rule_task_type_id(rule)
  let goal_field = case rule.goal {
    option.Some(g) -> [#("goal", json.string(g))]
    option.None -> [#("goal", json.null())]
  }
  let task_type_field = case task_type_id {
    option.Some(id) -> [#("task_type_id", json.int(id))]
    option.None -> [#("task_type_id", json.null())]
  }
  json.object(
    [
      #("id", json.int(rule.id)),
      #("workflow_id", json.int(rule.workflow_id)),
      #("name", json.string(rule.name)),
      #("resource_type", json.string(rule_resource_type(rule))),
      #("to_state", json.string(rule_to_state_string(rule))),
      #("active", json.bool(rule.active)),
      #("created_at", json.string(rule.created_at)),
    ]
    |> crud_dialog_base.prepend_fields(goal_field)
    |> crud_dialog_base.prepend_fields(task_type_field),
  )
}

// =============================================================================
// View
// =============================================================================

fn view(model: Model) -> Element(Msg) {
  case model.mode {
    crud_dialog_base.Closed -> element.none()
    crud_dialog_base.Creating -> view_create_dialog(model)
    crud_dialog_base.Editing(_rule) -> view_edit_dialog(model)
    crud_dialog_base.Deleting(rule) -> view_delete_dialog(model, rule)
  }
}

fn view_rule_fields(
  model: Model,
  name: String,
  goal: String,
  resource_type: String,
  task_type_id: Option(Int),
  to_state: String,
  active: Bool,
  on_name_changed: fn(String) -> Msg,
  on_goal_changed: fn(String) -> Msg,
  on_resource_type_changed: fn(String) -> Msg,
  on_task_type_changed: fn(String) -> Msg,
  on_to_state_changed: fn(String) -> Msg,
  on_active_changed: fn(Bool) -> Msg,
  name_aria_label: Option(String),
  goal_aria_label: Option(String),
) -> List(Element(Msg)) {
  [
    form_field.view(
      t(model.locale, i18n_text.RuleName),
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
      t(model.locale, i18n_text.RuleGoal),
      input(
        [
          attribute.type_("text"),
          attribute.value(goal),
          event.on_input(on_goal_changed),
        ]
        |> crud_dialog_base.with_optional_aria_label(goal_aria_label),
      ),
    ),
    form_field.view(
      t(model.locale, i18n_text.RuleResourceType),
      view_resource_type_selector(
        model.locale,
        resource_type,
        on_resource_type_changed,
      ),
    ),
    view_conditional_task_type_field(
      model,
      resource_type,
      task_type_id,
      on_task_type_changed,
    ),
    form_field.view(
      t(model.locale, i18n_text.RuleToState),
      view_state_selector(
        model.locale,
        resource_type,
        to_state,
        on_to_state_changed,
      ),
    ),
    form_field.view_checkbox(
      t(model.locale, i18n_text.RuleActive),
      input([
        attribute.type_("checkbox"),
        attribute.checked(active),
        event.on_check(on_active_changed),
      ]),
    ),
  ]
}

fn view_create_dialog(model: Model) -> Element(Msg) {
  crud_dialog_base.view_dialog_shell(
    "dialog dialog-lg",
    modal_header.view_dialog_with_icon_and_close_label(
      t(model.locale, i18n_text.CreateRule),
      text("\u{1F4DC}"),
      CloseRequested,
      t(model.locale, i18n_text.Close),
    ),
    model.create_error,
    [
      form(
        [
          event.on_submit(fn(_) { CreateSubmitted }),
          attribute.id("rule-create-form"),
        ],
        view_rule_fields(
          model,
          model.create_name,
          model.create_goal,
          model.create_resource_type,
          model.create_task_type_id,
          model.create_to_state,
          model.create_active,
          CreateNameChanged,
          CreateGoalChanged,
          CreateResourceTypeChanged,
          CreateTaskTypeIdChanged,
          CreateToStateChanged,
          CreateActiveChanged,
          option.Some("Rule name"),
          option.Some("Rule goal"),
        ),
      ),
    ],
    [
      crud_dialog_base.view_cancel_button(model.locale, CloseRequested),
      crud_dialog_base.view_submit_button(
        "rule-create-form",
        model.create_in_flight,
        t(model.locale, i18n_text.Create),
        t(model.locale, i18n_text.Creating),
      ),
    ],
  )
}

fn view_edit_dialog(model: Model) -> Element(Msg) {
  crud_dialog_base.view_dialog_shell(
    "dialog dialog-lg",
    modal_header.view_dialog_with_icon_and_close_label(
      t(model.locale, i18n_text.EditRule),
      text("\u{270F}"),
      EditCancelled,
      t(model.locale, i18n_text.Close),
    ),
    model.edit_error,
    [
      form(
        [
          event.on_submit(fn(_) { EditSubmitted }),
          attribute.id("rule-edit-form"),
        ],
        view_rule_fields(
          model,
          model.edit_name,
          model.edit_goal,
          model.edit_resource_type,
          model.edit_task_type_id,
          model.edit_to_state,
          model.edit_active,
          EditNameChanged,
          EditGoalChanged,
          EditResourceTypeChanged,
          EditTaskTypeIdChanged,
          EditToStateChanged,
          EditActiveChanged,
          option.None,
          option.None,
        ),
      ),
    ],
    [
      crud_dialog_base.view_cancel_button(model.locale, EditCancelled),
      crud_dialog_base.view_submit_button(
        "rule-edit-form",
        model.edit_in_flight,
        t(model.locale, i18n_text.Save),
        t(model.locale, i18n_text.Working),
      ),
    ],
  )
}

fn view_delete_dialog(model: Model, rule: Rule) -> Element(Msg) {
  crud_dialog_base.view_delete_dialog_shell(
    model.locale,
    t(model.locale, i18n_text.DeleteRule),
    text("\u{1F5D1}"),
    t(model.locale, i18n_text.RuleDeleteConfirm(rule.name)),
    model.delete_error,
    model.delete_in_flight,
    DeleteCancelled,
    DeleteConfirmed,
    t(model.locale, i18n_text.Removing),
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
  rule: Rule,
  task_types: List(TaskType),
) -> Element(Msg) {
  let model =
    Model(
      ..default_model(),
      locale: locale,
      mode: crud_dialog_base.Editing(rule),
      task_types: task_types,
      edit_name: rule.name,
      edit_goal: crud_dialog_base.optional_text_input_value(rule.goal),
      edit_resource_type: rule_resource_type(rule),
      edit_task_type_id: rule_task_type_id(rule),
      edit_to_state: rule_to_state_string(rule),
      edit_active: rule.active,
    )
  view_edit_dialog(model)
}

/// Resource type selector (task or card).
fn view_resource_type_selector(
  locale: Locale,
  selected: String,
  on_change: fn(String) -> Msg,
) -> Element(Msg) {
  select(
    [
      attribute.value(selected),
      event.on_input(on_change),
    ],
    [
      html_option(
        [attribute.value("task")],
        t(locale, i18n_text.RuleResourceTypeTask),
      ),
      html_option(
        [attribute.value("card")],
        t(locale, i18n_text.RuleResourceTypeCard),
      ),
    ],
  )
}

/// Conditional task type field - only visible when resource_type == "task".
fn view_conditional_task_type_field(
  model: Model,
  resource_type: String,
  selected_id: Option(Int),
  on_change: fn(String) -> Msg,
) -> Element(Msg) {
  case resource_type {
    "task" ->
      form_field.view(
        t(model.locale, i18n_text.RuleTaskType),
        view_task_type_selector(model.task_types, selected_id, on_change),
      )
    _ -> element.none()
  }
}

/// Task type selector dropdown.
fn view_task_type_selector(
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
    ],
    [
      html_option([attribute.value("")], "-- Select type --"),
      ..list.map(task_types, fn(tt) {
        html_option(
          [
            attribute.value(int.to_string(tt.id)),
            attribute.selected(option.Some(tt.id) == selected_id),
          ],
          // Only show name - icons can't be displayed in <select> options
          tt.name,
        )
      })
    ],
  )
}

/// State selector with dynamic options based on resource type.
fn view_state_selector(
  locale: Locale,
  resource_type: String,
  selected: String,
  on_change: fn(String) -> Msg,
) -> Element(Msg) {
  let options = state_options_for_resource_type(locale, resource_type)
  select(
    [
      attribute.value(selected),
      event.on_input(on_change),
    ],
    list.map(options, fn(opt) {
      let #(value, label_text) = opt
      html_option(
        [
          attribute.value(value),
          attribute.selected(value == selected),
        ],
        label_text,
      )
    }),
  )
}

/// Get state options based on resource type.
/// Task: available, claimed, completed
/// Card: pendiente, en_curso, cerrada
pub fn state_options_for_resource_type(
  locale: Locale,
  resource_type: String,
) -> List(#(String, String)) {
  case resource_type {
    "task" -> [
      #(
        task_status_to_string(Available),
        t(locale, i18n_text.TaskStateAvailable),
      ),
      #(
        task_status_to_string(Claimed(Taken)),
        t(locale, i18n_text.TaskStateClaimed),
      ),
      #(task_status_to_string(Done), t(locale, i18n_text.TaskStateDone)),
    ]
    _ -> [
      #(card_state_to_string(Draft), t(locale, i18n_text.CardPhaseDraft)),
      #(card_state_to_string(Active), t(locale, i18n_text.CardPhaseActive)),
      #(card_state_to_string(Closed), t(locale, i18n_text.CardPhaseClosed)),
    ]
  }
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
