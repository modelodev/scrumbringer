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
  text,
}
import lustre/event

import domain/api_error.{type ApiError}
import domain/task_type.{type TaskType, TaskType}
import domain/workflow.{type Rule, Rule}

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
  ModeEdit(Rule)
  ModeDelete(Rule)
}

/// Internal component model - encapsulates all 21 rule CRUD fields.
pub type Model {
  Model(
    // Attributes from parent
    locale: Locale,
    workflow_id: Option(Int),
    mode: Option(DialogMode),
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
  crud_dialog_base.decode_create_mode(value, ModeCreate, ModeReceived)
}

/// Story 4.10: Added templates field (defaults to empty list for dialog).
fn rule_property_decoder() -> Decoder(Msg) {
  use id <- decode.field("id", decode.int)
  use workflow_id <- decode.field("workflow_id", decode.int)
  use name <- decode.field("name", decode.string)
  use goal <- decode.field("goal", decode.optional(decode.string))
  use resource_type <- decode.field("resource_type", decode.string)
  use task_type_id <- decode.field("task_type_id", decode.optional(decode.int))
  use to_state <- decode.field("to_state", decode.string)
  use active <- decode.field("active", decode.bool)
  use created_at <- decode.field("created_at", decode.string)
  use mode <- decode.field("_mode", decode.string)
  let rule =
    Rule(
      id: id,
      workflow_id: workflow_id,
      name: name,
      goal: goal,
      resource_type: resource_type,
      task_type_id: task_type_id,
      to_state: to_state,
      active: active,
      created_at: created_at,
      templates: [],
    )
  case mode {
    "edit" -> decode.success(ModeReceived(ModeEdit(rule)))
    "delete" -> decode.success(ModeReceived(ModeDelete(rule)))
    _ -> decode.success(ModeReceived(ModeEdit(rule)))
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
    workflow_id: option.None,
    mode: option.None,
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

// Justification: large function kept intact to preserve cohesive UI logic.
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
      Model(..model, create_task_type_id: parse_optional_int(type_id_str)),
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
      Model(..model, edit_task_type_id: parse_optional_int(type_id_str)),
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
    ModeCreate -> #(
      Model(
        ..model,
        mode: option.Some(ModeCreate),
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

    ModeEdit(rule) -> #(
      Model(
        ..model,
        mode: option.Some(ModeEdit(rule)),
        edit_name: rule.name,
        edit_goal: option.unwrap(rule.goal, ""),
        edit_resource_type: rule.resource_type,
        edit_task_type_id: rule.task_type_id,
        edit_to_state: rule.to_state,
        edit_active: rule.active,
        edit_in_flight: False,
        edit_error: option.None,
      ),
      effect.none(),
    )

    ModeDelete(rule) -> #(
      Model(
        ..model,
        mode: option.Some(ModeDelete(rule)),
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

// Justification: nested case improves clarity for branching logic.
fn handle_create_submitted(model: Model) -> #(Model, Effect(Msg)) {
  case model.create_in_flight {
    True -> #(model, effect.none())
    False ->
      case model.workflow_id, model.create_name {
        option.None, _ -> #(model, effect.none())
        _, "" -> #(
          Model(
            ..model,
            create_error: option.Some(t(model.locale, i18n_text.NameRequired)),
          ),
          effect.none(),
        )
        option.Some(workflow_id), name -> #(
          Model(..model, create_in_flight: True, create_error: option.None),
          api_workflows.create_rule(
            workflow_id,
            name,
            model.create_goal,
            model.create_resource_type,
            model.create_task_type_id,
            model.create_to_state,
            model.create_active,
            CreateResult,
          ),
        )
      }
  }
}

fn handle_create_success(model: Model, rule: Rule) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      mode: option.None,
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
  case model.edit_in_flight {
    True -> #(model, effect.none())
    False -> submit_edit_name(model)
  }
}

fn submit_edit_name(model: Model) -> #(Model, Effect(Msg)) {
  case model.edit_name {
    "" -> #(
      Model(
        ..model,
        edit_error: option.Some(t(model.locale, i18n_text.NameRequired)),
      ),
      effect.none(),
    )
    name -> submit_edit_with_name(model, name)
  }
}

fn submit_edit_with_name(model: Model, name: String) -> #(Model, Effect(Msg)) {
  case model.mode {
    option.Some(ModeEdit(rule)) -> #(
      Model(..model, edit_in_flight: True, edit_error: option.None),
      api_workflows.update_rule(
        rule.id,
        name,
        model.edit_goal,
        model.edit_resource_type,
        model.edit_task_type_id,
        model.edit_to_state,
        model.edit_active,
        EditResult,
      ),
    )
    _ -> #(model, effect.none())
  }
}

fn handle_edit_success(model: Model, rule: Rule) -> #(Model, Effect(Msg)) {
  #(reset_edit_fields(model), emit_rule_updated(rule))
}

// Justification: nested case improves clarity for branching logic.
fn handle_delete_confirmed(model: Model) -> #(Model, Effect(Msg)) {
  case model.delete_in_flight {
    True -> #(model, effect.none())
    False ->
      case model.mode {
        option.Some(ModeDelete(rule)) -> #(
          Model(..model, delete_in_flight: True, delete_error: option.None),
          api_workflows.delete_rule(rule.id, DeleteResult),
        )
        _ -> #(model, effect.none())
      }
  }
}

fn handle_delete_success(model: Model) -> #(Model, Effect(Msg)) {
  let rule_id = case model.mode {
    option.Some(ModeDelete(rule)) -> rule.id
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
    mode: option.None,
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
    mode: option.None,
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
  let goal_field = case rule.goal {
    option.Some(g) -> [#("goal", json.string(g))]
    option.None -> [#("goal", json.null())]
  }
  let task_type_field = case rule.task_type_id {
    option.Some(id) -> [#("task_type_id", json.int(id))]
    option.None -> [#("task_type_id", json.null())]
  }
  json.object(
    [
      #("id", json.int(rule.id)),
      #("workflow_id", json.int(rule.workflow_id)),
      #("name", json.string(rule.name)),
      #("resource_type", json.string(rule.resource_type)),
      #("to_state", json.string(rule.to_state)),
      #("active", json.bool(rule.active)),
      #("created_at", json.string(rule.created_at)),
    ]
    |> append_fields(goal_field)
    |> append_fields(task_type_field),
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
    option.Some(ModeEdit(_rule)) -> view_edit_dialog(model)
    option.Some(ModeDelete(rule)) -> view_delete_dialog(model, rule)
  }
}

// Justification: large function kept intact to preserve cohesive UI logic.
fn view_create_dialog(model: Model) -> Element(Msg) {
  div([attribute.class("dialog-overlay")], [
    div(
      [
        attribute.class("dialog dialog-lg"),
        attribute.attribute("role", "dialog"),
        attribute.attribute("aria-modal", "true"),
      ],
      [
        // Header
        view_header(model, i18n_text.CreateRule, "\u{1F4DC}"),
        // Error
        view_error(model.create_error),
        // Body
        div([attribute.class("dialog-body")], [
          form(
            [
              event.on_submit(fn(_) { CreateSubmitted }),
              attribute.id("rule-create-form"),
            ],
            [
              // Name field
              div([attribute.class("field")], [
                label([], [text(t(model.locale, i18n_text.RuleName))]),
                input([
                  attribute.type_("text"),
                  attribute.value(model.create_name),
                  event.on_input(CreateNameChanged),
                  attribute.required(True),
                  attribute.attribute("aria-label", "Rule name"),
                ]),
              ]),
              // Goal field
              div([attribute.class("field")], [
                label([], [text(t(model.locale, i18n_text.RuleGoal))]),
                input([
                  attribute.type_("text"),
                  attribute.value(model.create_goal),
                  event.on_input(CreateGoalChanged),
                  attribute.attribute("aria-label", "Rule goal"),
                ]),
              ]),
              // Resource type selector
              div([attribute.class("field")], [
                label([], [text(t(model.locale, i18n_text.RuleResourceType))]),
                view_resource_type_selector(
                  model.locale,
                  model.create_resource_type,
                  CreateResourceTypeChanged,
                ),
              ]),
              // Task type selector (conditional - only when resource_type == "task")
              view_conditional_task_type_field(
                model,
                model.create_resource_type,
                model.create_task_type_id,
                CreateTaskTypeIdChanged,
              ),
              // To state selector (dynamic options based on resource_type)
              div([attribute.class("field")], [
                label([], [text(t(model.locale, i18n_text.RuleToState))]),
                view_state_selector(
                  model.locale,
                  model.create_resource_type,
                  model.create_to_state,
                  CreateToStateChanged,
                ),
              ]),
              // Active checkbox
              div([attribute.class("field")], [
                label([], [
                  input([
                    attribute.type_("checkbox"),
                    attribute.checked(model.create_active),
                    event.on_check(CreateActiveChanged),
                  ]),
                  text(" " <> t(model.locale, i18n_text.RuleActive)),
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
              attribute.form("rule-create-form"),
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

// Justification: large function kept intact to preserve cohesive UI logic.
fn view_edit_dialog(model: Model) -> Element(Msg) {
  div([attribute.class("dialog-overlay")], [
    div(
      [
        attribute.class("dialog dialog-lg"),
        attribute.attribute("role", "dialog"),
        attribute.attribute("aria-modal", "true"),
      ],
      [
        // Header
        view_header(model, i18n_text.EditRule, "\u{270F}"),
        // Error
        view_error(model.edit_error),
        // Body
        div([attribute.class("dialog-body")], [
          form(
            [
              event.on_submit(fn(_) { EditSubmitted }),
              attribute.id("rule-edit-form"),
            ],
            [
              // Name field
              div([attribute.class("field")], [
                label([], [text(t(model.locale, i18n_text.RuleName))]),
                input([
                  attribute.type_("text"),
                  attribute.value(model.edit_name),
                  event.on_input(EditNameChanged),
                  attribute.required(True),
                ]),
              ]),
              // Goal field
              div([attribute.class("field")], [
                label([], [text(t(model.locale, i18n_text.RuleGoal))]),
                input([
                  attribute.type_("text"),
                  attribute.value(model.edit_goal),
                  event.on_input(EditGoalChanged),
                ]),
              ]),
              // Resource type selector
              div([attribute.class("field")], [
                label([], [text(t(model.locale, i18n_text.RuleResourceType))]),
                view_resource_type_selector(
                  model.locale,
                  model.edit_resource_type,
                  EditResourceTypeChanged,
                ),
              ]),
              // Task type selector (conditional)
              view_conditional_task_type_field(
                model,
                model.edit_resource_type,
                model.edit_task_type_id,
                EditTaskTypeIdChanged,
              ),
              // To state selector (dynamic options)
              div([attribute.class("field")], [
                label([], [text(t(model.locale, i18n_text.RuleToState))]),
                view_state_selector(
                  model.locale,
                  model.edit_resource_type,
                  model.edit_to_state,
                  EditToStateChanged,
                ),
              ]),
              // Active checkbox
              div([attribute.class("field")], [
                label([], [
                  input([
                    attribute.type_("checkbox"),
                    attribute.checked(model.edit_active),
                    event.on_check(EditActiveChanged),
                  ]),
                  text(" " <> t(model.locale, i18n_text.RuleActive)),
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
              attribute.form("rule-edit-form"),
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

fn view_delete_dialog(model: Model, rule: Rule) -> Element(Msg) {
  div([attribute.class("dialog-overlay")], [
    div(
      [
        attribute.class("dialog dialog-sm"),
        attribute.attribute("role", "dialog"),
        attribute.attribute("aria-modal", "true"),
      ],
      [
        // Header
        view_header(model, i18n_text.DeleteRule, "\u{1F5D1}"),
        // Error
        view_error(model.delete_error),
        // Body
        div([attribute.class("dialog-body")], [
          p([], [
            text(t(model.locale, i18n_text.RuleDeleteConfirm(rule.name))),
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
                False -> t(model.locale, i18n_text.DeleteRule)
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
      div([attribute.class("field")], [
        label([], [text(t(model.locale, i18n_text.RuleTaskType))]),
        view_task_type_selector(model.task_types, selected_id, on_change),
      ])
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
      #("available", t(locale, i18n_text.TaskStateAvailable)),
      #("claimed", t(locale, i18n_text.TaskStateClaimed)),
      #("completed", t(locale, i18n_text.TaskStateCompleted)),
    ]
    _ -> [
      #("pendiente", t(locale, i18n_text.CardStatePendiente)),
      #("en_curso", t(locale, i18n_text.CardStateEnCurso)),
      #("cerrada", t(locale, i18n_text.CardStateCerrada)),
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
