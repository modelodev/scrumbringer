//// Admin automation update handlers.
////
//// ## Mission
////
//// Handles automation engine and rule CRUD operations in the admin panel.
////
//// ## Responsibilities
////
//// - Automation engine list fetch and CRUD
//// - Rule list fetch and CRUD for the selected engine
//// - Rule expansion and builder state
////
//// ## Relations
////
//// - **update.gleam**: Main update module that delegates to handlers here
//// - **view.gleam**: Renders the automations UI using model state

import gleam/int
import gleam/option as opt
import gleam/result
import gleam/set
import gleam/string

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError, type ApiResult}
import domain/automation
import domain/remote.{Failed, Loaded, Loading, NotAsked}
import domain/task_type.{type TaskType}
import domain/workflow.{type Rule, type Workflow}
import scrumbringer_client/client_state/admin/rules as admin_rules
import scrumbringer_client/client_state/admin/workflows as admin_workflows
import scrumbringer_client/features/admin/scoped_remote_list
import scrumbringer_client/features/pool/msg as pool_messages

import scrumbringer_client/api/tasks/task_types as task_types_api
import scrumbringer_client/api/workflows as api_workflows
import scrumbringer_client/api/workflows/rule_metrics as api_rule_metrics
import scrumbringer_client/api/workflows/rules as api_rules

type EngineCrudSuccess {
  EngineCreated
  EngineUpdated
  EngineDeleted
}

pub type EngineFeedbackContext(parent_msg) {
  EngineFeedbackContext(
    engine_created: String,
    engine_updated: String,
    engine_deleted: String,
    on_success_toast: fn(String) -> Effect(parent_msg),
    on_engine_saved: fn(ApiResult(Workflow)) -> parent_msg,
    on_engine_deleted: fn(Int, ApiResult(Nil)) -> parent_msg,
  )
}

type RuleSuccess {
  RuleCreated
  RuleUpdated
  RuleDeleted
}

pub type RuleFeedbackContext(parent_msg) {
  RuleFeedbackContext(
    rule_created: String,
    rule_updated: String,
    rule_deleted: String,
    on_success_toast: fn(String) -> Effect(parent_msg),
    on_rule_saved: fn(ApiResult(Rule)) -> parent_msg,
    on_rule_deleted: fn(Int, ApiResult(Nil)) -> parent_msg,
  )
}

pub type RulesContext(parent_msg) {
  RulesContext(
    selected_project_id: opt.Option(Int),
    on_rules_fetched: fn(ApiResult(List(Rule))) -> parent_msg,
    on_rule_metrics_fetched: fn(ApiResult(api_rule_metrics.WorkflowMetrics)) ->
      parent_msg,
    on_task_types_fetched: fn(ApiResult(List(TaskType))) -> parent_msg,
  )
}

pub type RulesAuthPolicy {
  NoRulesAuthCheck
  CheckRulesAuth(ApiError)
}

pub type RulesUpdate(parent_msg) {
  RulesUpdate(admin_rules.Model, Effect(parent_msg), RulesAuthPolicy)
}

pub fn try_rules_update(
  state: admin_rules.Model,
  inner: pool_messages.Msg,
  context: RulesContext(parent_msg),
  feedback: RuleFeedbackContext(parent_msg),
) -> opt.Option(RulesUpdate(parent_msg)) {
  case inner {
    pool_messages.WorkflowRulesClicked(workflow_id) ->
      workflow_rules_clicked(state, workflow_id, context)
      |> without_rules_auth_check

    pool_messages.RulesFetched(Ok(rules)) ->
      #(rules_fetched_ok(state, rules), effect.none())
      |> without_rules_auth_check

    pool_messages.RulesFetched(Error(err)) ->
      #(rules_fetched_error(state, err), effect.none())
      |> with_rules_auth_check(err)

    pool_messages.RulesBackClicked ->
      #(rules_back_clicked(state), effect.none())
      |> without_rules_auth_check

    pool_messages.RuleMetricsFetched(Ok(metrics)) ->
      #(rule_metrics_fetched_ok(state, metrics), effect.none())
      |> without_rules_auth_check

    pool_messages.RuleMetricsFetched(Error(err)) ->
      #(rule_metrics_fetched_error(state, err), effect.none())
      |> with_rules_auth_check(err)

    pool_messages.OpenRuleDialog(mode) ->
      #(open_rule_dialog(state, mode), effect.none())
      |> without_rules_auth_check

    pool_messages.CloseRuleDialog ->
      #(close_rule_dialog(state), effect.none())
      |> without_rules_auth_check

    pool_messages.RuleNameChanged(value) ->
      #(admin_rules.Model(..state, rule_form_name: value), effect.none())
      |> without_rules_auth_check

    pool_messages.RuleGoalChanged(value) ->
      #(admin_rules.Model(..state, rule_form_goal: value), effect.none())
      |> without_rules_auth_check

    pool_messages.RuleSubjectChanged(value) ->
      #(rule_subject_changed(state, value), effect.none())
      |> without_rules_auth_check

    pool_messages.RuleTaskTypeChanged(value) ->
      #(
        admin_rules.Model(..state, rule_form_task_type_id: value),
        effect.none(),
      )
      |> without_rules_auth_check

    pool_messages.RuleEventChanged(value) ->
      #(admin_rules.Model(..state, rule_form_event: value), effect.none())
      |> without_rules_auth_check

    pool_messages.RuleCardScopeChanged(value) ->
      #(admin_rules.Model(..state, rule_form_card_scope: value), effect.none())
      |> without_rules_auth_check

    pool_messages.RuleTemplateSearchChanged(value) ->
      #(
        admin_rules.Model(..state, rule_form_template_search: value),
        effect.none(),
      )
      |> without_rules_auth_check

    pool_messages.RuleTemplateChanged(value) ->
      #(admin_rules.Model(..state, rule_form_template_id: value), effect.none())
      |> without_rules_auth_check

    pool_messages.RuleActiveChanged(value) ->
      #(admin_rules.Model(..state, rule_form_active: value), effect.none())
      |> without_rules_auth_check

    pool_messages.RuleFormSubmitted ->
      submit_rule_form(state, feedback)
      |> without_rules_auth_check

    pool_messages.RuleSaved(Ok(rule)) ->
      #(
        rule_saved(state, rule),
        rule_success_effect(success_for_rule_saved(state), feedback),
      )
      |> without_rules_auth_check

    pool_messages.RuleSaved(Error(err)) ->
      #(rule_form_error(state, err.message), effect.none())
      |> with_rules_auth_check(err)

    pool_messages.RuleDeleteConfirmed ->
      confirm_rule_delete(state, feedback)
      |> without_rules_auth_check

    pool_messages.RuleDeleteFinished(rule_id, Ok(_)) ->
      #(
        rule_deleted(state, rule_id),
        rule_success_effect(RuleDeleted, feedback),
      )
      |> without_rules_auth_check

    pool_messages.RuleDeleteFinished(_rule_id, Error(err)) ->
      #(rule_form_error(state, err.message), effect.none())
      |> with_rules_auth_check(err)

    pool_messages.RuleExpandToggled(rule_id) ->
      #(rule_expand_toggled(state, rule_id), effect.none())
      |> without_rules_auth_check

    _ -> opt.None
  }
}

fn workflow_rules_clicked(
  state: admin_rules.Model,
  workflow_id: Int,
  context: RulesContext(parent_msg),
) -> #(admin_rules.Model, Effect(parent_msg)) {
  let state = workflow_rules_opened(state, workflow_id)
  let task_types_effect = case context.selected_project_id {
    opt.Some(project_id) ->
      task_types_api.list_task_types(project_id, context.on_task_types_fetched)
    opt.None -> effect.none()
  }

  #(
    state,
    effect.batch([
      api_rules.list_rules(workflow_id, context.on_rules_fetched),
      api_rule_metrics.get_workflow_metrics(
        workflow_id,
        context.on_rule_metrics_fetched,
      ),
      task_types_effect,
    ]),
  )
}

fn without_rules_auth_check(
  result: #(admin_rules.Model, Effect(parent_msg)),
) -> opt.Option(RulesUpdate(parent_msg)) {
  let #(state, fx) = result
  opt.Some(RulesUpdate(state, fx, NoRulesAuthCheck))
}

fn with_rules_auth_check(
  result: #(admin_rules.Model, Effect(parent_msg)),
  err: ApiError,
) -> opt.Option(RulesUpdate(parent_msg)) {
  let #(state, fx) = result
  opt.Some(RulesUpdate(state, fx, CheckRulesAuth(err)))
}

fn rule_expand_toggled(
  state: admin_rules.Model,
  rule_id: Int,
) -> admin_rules.Model {
  let expanded = case set.contains(state.rules_expanded, rule_id) {
    True -> set.delete(state.rules_expanded, rule_id)
    False -> set.insert(state.rules_expanded, rule_id)
  }

  admin_rules.Model(..state, rules_expanded: expanded)
}

pub type EngineAuthPolicy {
  NoEngineAuthCheck
  CheckEngineAuth(ApiError)
}

pub type EngineUpdate(parent_msg) {
  EngineUpdate(admin_workflows.Model, Effect(parent_msg), EngineAuthPolicy)
}

pub fn try_engines_update(
  state: admin_workflows.Model,
  inner: pool_messages.Msg,
  feedback: EngineFeedbackContext(parent_msg),
) -> opt.Option(EngineUpdate(parent_msg)) {
  case inner {
    pool_messages.WorkflowsProjectFetched(Ok(workflows)) ->
      engines_project_fetched_ok(state, workflows)
      |> without_engine_auth_check

    pool_messages.WorkflowsProjectFetched(Error(err)) ->
      engines_project_fetched_error(state, err)
      |> with_engine_auth_check(err)

    pool_messages.WorkflowsSearchChanged(query) ->
      admin_workflows.Model(..state, engine_search: query)
      |> without_engine_auth_check

    pool_messages.WorkflowsStatusFilterChanged(status) ->
      admin_workflows.Model(..state, engine_status_filter: status)
      |> without_engine_auth_check

    pool_messages.OpenWorkflowDialog(mode) ->
      open_engine_dialog(state, mode)
      |> without_engine_auth_check

    pool_messages.CloseWorkflowDialog ->
      close_engine_dialog(state)
      |> without_engine_auth_check

    pool_messages.WorkflowNameChanged(value) ->
      admin_workflows.Model(..state, engine_form_name: value)
      |> without_engine_auth_check

    pool_messages.WorkflowDescriptionChanged(value) ->
      admin_workflows.Model(..state, engine_form_description: value)
      |> without_engine_auth_check

    pool_messages.WorkflowActiveChanged(value) ->
      admin_workflows.Model(..state, engine_form_active: value)
      |> without_engine_auth_check

    pool_messages.WorkflowFormSubmitted(project_id) ->
      submit_engine_form(state, project_id, feedback)
      |> without_engine_tuple_auth_check

    pool_messages.WorkflowSaved(Ok(workflow)) ->
      engine_saved(state, workflow)
      |> with_engine_effect(engine_success_effect(
        success_for_engine_saved(state),
        feedback,
      ))

    pool_messages.WorkflowSaved(Error(err)) ->
      engine_form_error(state, err.message)
      |> with_engine_auth_check(err)

    pool_messages.WorkflowDeleteConfirmed ->
      confirm_engine_delete(state, feedback)
      |> without_engine_tuple_auth_check

    pool_messages.WorkflowDeleteFinished(workflow_id, Ok(_)) ->
      engine_deleted(state, workflow_id)
      |> with_engine_effect(engine_success_effect(EngineDeleted, feedback))

    pool_messages.WorkflowDeleteFinished(_workflow_id, Error(err)) ->
      engine_form_error(state, err.message)
      |> with_engine_auth_check(err)

    _ -> opt.None
  }
}

fn without_engine_auth_check(
  state: admin_workflows.Model,
) -> opt.Option(EngineUpdate(parent_msg)) {
  with_engine_effect(state, effect.none())
}

fn without_engine_tuple_auth_check(
  result: #(admin_workflows.Model, Effect(parent_msg)),
) -> opt.Option(EngineUpdate(parent_msg)) {
  let #(state, fx) = result
  with_engine_effect(state, fx)
}

fn with_engine_auth_check(
  state: admin_workflows.Model,
  err: ApiError,
) -> opt.Option(EngineUpdate(parent_msg)) {
  opt.Some(EngineUpdate(state, effect.none(), CheckEngineAuth(err)))
}

fn with_engine_effect(
  state: admin_workflows.Model,
  fx: Effect(parent_msg),
) -> opt.Option(EngineUpdate(parent_msg)) {
  opt.Some(EngineUpdate(state, fx, NoEngineAuthCheck))
}

fn engines_project_fetched_ok(
  state: admin_workflows.Model,
  workflows: List(Workflow),
) -> admin_workflows.Model {
  admin_workflows.Model(..state, engines_project: Loaded(workflows))
}

fn engines_project_fetched_error(
  state: admin_workflows.Model,
  err: ApiError,
) -> admin_workflows.Model {
  admin_workflows.Model(..state, engines_project: Failed(err))
}

fn open_engine_dialog(
  state: admin_workflows.Model,
  mode: admin_workflows.EngineDialogMode,
) -> admin_workflows.Model {
  case mode {
    admin_workflows.EngineDialogCreate ->
      admin_workflows.Model(
        ..state,
        engine_dialog_mode: opt.Some(mode),
        engine_form_name: "",
        engine_form_description: "",
        engine_form_active: True,
        engine_form_submitting: False,
        engine_form_error: opt.None,
      )
    admin_workflows.EngineDialogEdit(workflow) ->
      admin_workflows.Model(
        ..state,
        engine_dialog_mode: opt.Some(mode),
        engine_form_name: workflow.name,
        engine_form_description: optional_text(workflow.description),
        engine_form_active: workflow.active,
        engine_form_submitting: False,
        engine_form_error: opt.None,
      )
    admin_workflows.EngineDialogDelete(_) ->
      admin_workflows.Model(
        ..state,
        engine_dialog_mode: opt.Some(mode),
        engine_form_submitting: False,
        engine_form_error: opt.None,
      )
  }
}

fn close_engine_dialog(state: admin_workflows.Model) -> admin_workflows.Model {
  admin_workflows.Model(
    ..state,
    engine_dialog_mode: opt.None,
    engine_form_submitting: False,
    engine_form_error: opt.None,
  )
}

fn optional_text(value: opt.Option(String)) -> String {
  case value {
    opt.Some(text) -> text
    opt.None -> ""
  }
}

fn submit_engine_form(
  state: admin_workflows.Model,
  selected_project_id: opt.Option(Int),
  feedback: EngineFeedbackContext(parent_msg),
) -> #(admin_workflows.Model, Effect(parent_msg)) {
  case state.engine_dialog_mode {
    opt.Some(admin_workflows.EngineDialogCreate) ->
      submit_engine_create(state, selected_project_id, feedback)
    opt.Some(admin_workflows.EngineDialogEdit(workflow)) ->
      submit_engine_update(state, workflow.id, feedback)
    _ -> #(state, effect.none())
  }
}

fn submit_engine_create(
  state: admin_workflows.Model,
  selected_project_id: opt.Option(Int),
  feedback: EngineFeedbackContext(parent_msg),
) -> #(admin_workflows.Model, Effect(parent_msg)) {
  case selected_project_id {
    opt.None -> #(
      engine_form_error(state, "Select a project first"),
      effect.none(),
    )
    opt.Some(project_id) ->
      case parse_engine_form(state) {
        Error(message) -> #(engine_form_error(state, message), effect.none())
        Ok(form) -> #(
          engine_form_submitting(state),
          api_workflows.create_project_workflow(
            project_id,
            form.name,
            form.description,
            form.active,
            feedback.on_engine_saved,
          ),
        )
      }
  }
}

fn submit_engine_update(
  state: admin_workflows.Model,
  workflow_id: Int,
  feedback: EngineFeedbackContext(parent_msg),
) -> #(admin_workflows.Model, Effect(parent_msg)) {
  case parse_engine_form(state) {
    Error(message) -> #(engine_form_error(state, message), effect.none())
    Ok(form) -> #(
      engine_form_submitting(state),
      api_workflows.update_workflow(
        workflow_id,
        form.name,
        form.description,
        form.active,
        feedback.on_engine_saved,
      ),
    )
  }
}

fn confirm_engine_delete(
  state: admin_workflows.Model,
  feedback: EngineFeedbackContext(parent_msg),
) -> #(admin_workflows.Model, Effect(parent_msg)) {
  case state.engine_dialog_mode {
    opt.Some(admin_workflows.EngineDialogDelete(workflow)) -> #(
      engine_form_submitting(state),
      api_workflows.delete_workflow(workflow.id, fn(result) {
        feedback.on_engine_deleted(workflow.id, result)
      }),
    )
    _ -> #(state, effect.none())
  }
}

type EngineForm {
  EngineForm(name: String, description: String, active: Bool)
}

fn parse_engine_form(state: admin_workflows.Model) -> Result(EngineForm, String) {
  let name = string.trim(state.engine_form_name)
  case name {
    "" -> Error("Engine name is required")
    _ ->
      Ok(EngineForm(
        name: name,
        description: state.engine_form_description,
        active: state.engine_form_active,
      ))
  }
}

fn engine_form_submitting(state: admin_workflows.Model) -> admin_workflows.Model {
  admin_workflows.Model(
    ..state,
    engine_form_submitting: True,
    engine_form_error: opt.None,
  )
}

fn engine_form_error(
  state: admin_workflows.Model,
  message: String,
) -> admin_workflows.Model {
  admin_workflows.Model(
    ..state,
    engine_form_submitting: False,
    engine_form_error: opt.Some(message),
  )
}

fn success_for_engine_saved(state: admin_workflows.Model) -> EngineCrudSuccess {
  case state.engine_dialog_mode {
    opt.Some(admin_workflows.EngineDialogEdit(_)) -> EngineUpdated
    _ -> EngineCreated
  }
}

fn engine_saved(
  state: admin_workflows.Model,
  workflow: Workflow,
) -> admin_workflows.Model {
  case state.engine_dialog_mode {
    opt.Some(admin_workflows.EngineDialogEdit(_)) ->
      engine_updated(state, workflow)
    _ -> engine_created(state, workflow)
  }
}

fn engine_created(
  state: admin_workflows.Model,
  workflow: Workflow,
) -> admin_workflows.Model {
  let #(org, project) =
    scoped_remote_list.prepend_for_scope(
      state.engines_org,
      state.engines_project,
      workflow.project_id,
      workflow,
    )

  admin_workflows.Model(
    ..state,
    engines_org: org,
    engines_project: project,
    engine_dialog_mode: opt.None,
    engine_form_name: "",
    engine_form_description: "",
    engine_form_active: True,
    engine_form_submitting: False,
    engine_form_error: opt.None,
  )
}

fn engine_updated(
  state: admin_workflows.Model,
  updated_workflow: Workflow,
) -> admin_workflows.Model {
  let org =
    scoped_remote_list.replace_by_id(
      state.engines_org,
      updated_workflow,
      fn(workflow: Workflow) { workflow.id },
    )
  let project =
    scoped_remote_list.replace_by_id(
      state.engines_project,
      updated_workflow,
      fn(workflow: Workflow) { workflow.id },
    )

  admin_workflows.Model(
    ..state,
    engines_org: org,
    engines_project: project,
    engine_dialog_mode: opt.None,
    engine_form_submitting: False,
    engine_form_error: opt.None,
  )
}

fn engine_deleted(
  state: admin_workflows.Model,
  workflow_id: Int,
) -> admin_workflows.Model {
  let org =
    scoped_remote_list.remove_by_id(
      state.engines_org,
      workflow_id,
      fn(workflow: Workflow) { workflow.id },
    )
  let project =
    scoped_remote_list.remove_by_id(
      state.engines_project,
      workflow_id,
      fn(workflow: Workflow) { workflow.id },
    )

  admin_workflows.Model(
    ..state,
    engines_org: org,
    engines_project: project,
    engine_dialog_mode: opt.None,
    engine_form_submitting: False,
    engine_form_error: opt.None,
  )
}

fn rule_subject_changed(
  state: admin_rules.Model,
  subject: String,
) -> admin_rules.Model {
  let event = case subject, state.rule_form_event {
    "task", "task_created" -> "task_created"
    "task", "task_claimed" -> "task_claimed"
    "task", "task_released" -> "task_released"
    "task", _ -> "task_completed"
    "card", "card_closed" -> "card_closed"
    "card", _ -> "card_activated"
    _, _ -> state.rule_form_event
  }
  let task_type_id = case subject {
    "card" -> ""
    _ -> state.rule_form_task_type_id
  }

  admin_rules.Model(
    ..state,
    rule_form_subject: subject,
    rule_form_task_type_id: task_type_id,
    rule_form_event: event,
    rule_form_card_scope: "",
  )
}

fn submit_rule_form(
  state: admin_rules.Model,
  feedback: RuleFeedbackContext(parent_msg),
) -> #(admin_rules.Model, Effect(parent_msg)) {
  case state.rules_dialog_mode {
    opt.Some(admin_rules.RuleDialogCreate) ->
      submit_rule_create(state, feedback)
    opt.Some(admin_rules.RuleDialogEdit(rule)) ->
      submit_rule_update(state, rule.id, feedback)
    _ -> #(state, effect.none())
  }
}

fn submit_rule_create(
  state: admin_rules.Model,
  feedback: RuleFeedbackContext(parent_msg),
) -> #(admin_rules.Model, Effect(parent_msg)) {
  case state.rules_workflow_id {
    opt.None -> #(rule_form_error(state, "Open an engine first"), effect.none())
    opt.Some(workflow_id) ->
      case parse_rule_form(state) {
        Error(message) -> #(rule_form_error(state, message), effect.none())
        Ok(form) -> #(
          rule_form_submitting(state),
          api_rules.create_rule(
            workflow_id,
            form.name,
            form.goal,
            form.trigger,
            form.action,
            form.status,
            feedback.on_rule_saved,
          ),
        )
      }
  }
}

fn submit_rule_update(
  state: admin_rules.Model,
  rule_id: Int,
  feedback: RuleFeedbackContext(parent_msg),
) -> #(admin_rules.Model, Effect(parent_msg)) {
  case parse_rule_form(state) {
    Error(message) -> #(rule_form_error(state, message), effect.none())
    Ok(form) -> #(
      rule_form_submitting(state),
      api_rules.update_rule(
        rule_id,
        form.name,
        form.goal,
        form.trigger,
        form.action,
        form.status,
        feedback.on_rule_saved,
      ),
    )
  }
}

fn confirm_rule_delete(
  state: admin_rules.Model,
  feedback: RuleFeedbackContext(parent_msg),
) -> #(admin_rules.Model, Effect(parent_msg)) {
  case state.rules_dialog_mode {
    opt.Some(admin_rules.RuleDialogDelete(rule)) -> #(
      rule_form_submitting(state),
      api_rules.delete_rule(rule.id, fn(result) {
        feedback.on_rule_deleted(rule.id, result)
      }),
    )
    _ -> #(state, effect.none())
  }
}

type RuleForm {
  RuleForm(
    name: String,
    goal: String,
    trigger: automation.AutomationTrigger,
    action: automation.AutomationAction,
    status: automation.AutomationRuleStatus,
  )
}

fn parse_rule_form(state: admin_rules.Model) -> Result(RuleForm, String) {
  let name = string.trim(state.rule_form_name)
  case name {
    "" -> Error("Rule name is required")
    _ -> {
      use trigger <- result.try(parse_rule_trigger_form(state))
      use template_id <- result.try(parse_rule_template_id(
        state.rule_form_template_id,
      ))
      Ok(RuleForm(
        name: name,
        goal: state.rule_form_goal,
        trigger: trigger,
        action: automation.CreateTask(template_id),
        status: rule_form_status(state),
      ))
    }
  }
}

fn parse_rule_trigger_form(
  state: admin_rules.Model,
) -> Result(automation.AutomationTrigger, String) {
  case state.rule_form_event {
    "task_created" -> {
      use task_type_id <- result.try(parse_rule_task_type_id(
        state.rule_form_task_type_id,
      ))
      Ok(automation.TaskCreated(task_type_id))
    }
    "task_completed" -> {
      use task_type_id <- result.try(parse_rule_task_type_id(
        state.rule_form_task_type_id,
      ))
      Ok(automation.TaskCompleted(task_type_id))
    }
    "task_claimed" -> {
      use task_type_id <- result.try(parse_rule_task_type_id(
        state.rule_form_task_type_id,
      ))
      Ok(automation.TaskClaimed(task_type_id))
    }
    "task_released" -> {
      use task_type_id <- result.try(parse_rule_task_type_id(
        state.rule_form_task_type_id,
      ))
      Ok(automation.TaskReleased(task_type_id))
    }
    "card_activated" -> {
      use scope <- result.try(parse_rule_card_scope(state.rule_form_card_scope))
      Ok(automation.CardActivated(scope))
    }
    "card_closed" -> {
      use scope <- result.try(parse_rule_card_scope(state.rule_form_card_scope))
      Ok(automation.CardClosed(scope))
    }
    _ -> Error("Choose a supported automation event")
  }
}

fn rule_form_status(state: admin_rules.Model) -> automation.AutomationRuleStatus {
  case state.rule_form_active {
    True -> automation.Active
    False -> automation.Paused
  }
}

fn parse_rule_template_id(value: String) -> Result(Int, String) {
  case string.trim(value) {
    "" -> Error("Choose one template")
    trimmed ->
      case int.parse(trimmed) {
        Ok(id) if id > 0 -> Ok(id)
        _ -> Error("Choose a valid template")
      }
  }
}

fn parse_rule_task_type_id(value: String) -> Result(opt.Option(Int), String) {
  case string.trim(value) {
    "" -> Ok(opt.None)
    trimmed ->
      case int.parse(trimmed) {
        Ok(id) -> Ok(opt.Some(id))
        Error(_) -> Error("Choose a valid task type")
      }
  }
}

fn parse_rule_card_scope(
  value: String,
) -> Result(automation.CardAutomationScope, String) {
  case string.trim(value) {
    "" -> Ok(automation.AnyCard)
    trimmed ->
      case int.parse(trimmed) {
        Ok(depth) ->
          case automation.card_depth_from_int(depth) {
            Ok(card_depth) -> Ok(automation.AtDepth(card_depth))
            Error(_) -> Error("Choose a valid card level")
          }
        Error(_) -> Error("Choose a valid card level")
      }
  }
}

fn rule_form_submitting(state: admin_rules.Model) -> admin_rules.Model {
  admin_rules.Model(
    ..state,
    rule_form_submitting: True,
    rule_form_error: opt.None,
  )
}

fn rule_form_error(
  state: admin_rules.Model,
  message: String,
) -> admin_rules.Model {
  admin_rules.Model(
    ..state,
    rule_form_submitting: False,
    rule_form_error: opt.Some(message),
  )
}

fn success_for_rule_saved(state: admin_rules.Model) -> RuleSuccess {
  case state.rules_dialog_mode {
    opt.Some(admin_rules.RuleDialogEdit(_)) -> RuleUpdated
    _ -> RuleCreated
  }
}

fn rule_saved(state: admin_rules.Model, rule: Rule) -> admin_rules.Model {
  case state.rules_dialog_mode {
    opt.Some(admin_rules.RuleDialogEdit(_)) -> rule_updated(state, rule)
    _ -> rule_created(state, rule)
  }
}

fn rule_created(state: admin_rules.Model, rule: Rule) -> admin_rules.Model {
  let rules = case state.rules {
    Loaded(existing) -> Loaded([rule, ..existing])
    _ -> Loaded([rule])
  }

  admin_rules.Model(
    ..state,
    rules: rules,
    rules_dialog_mode: opt.None,
    rule_form_submitting: False,
    rule_form_error: opt.None,
  )
}

fn rule_updated(
  state: admin_rules.Model,
  updated_rule: Rule,
) -> admin_rules.Model {
  let rules =
    scoped_remote_list.replace_by_id(state.rules, updated_rule, fn(rule: Rule) {
      rule.id
    })

  admin_rules.Model(
    ..state,
    rules: rules,
    rules_dialog_mode: opt.None,
    rule_form_submitting: False,
    rule_form_error: opt.None,
  )
}

fn rule_deleted(state: admin_rules.Model, rule_id: Int) -> admin_rules.Model {
  let rules =
    scoped_remote_list.remove_by_id(state.rules, rule_id, fn(rule: Rule) {
      rule.id
    })

  admin_rules.Model(
    ..state,
    rules: rules,
    rules_dialog_mode: opt.None,
    rule_form_submitting: False,
    rule_form_error: opt.None,
  )
}

fn workflow_rules_opened(
  state: admin_rules.Model,
  workflow_id: Int,
) -> admin_rules.Model {
  admin_rules.Model(
    ..state,
    rules_workflow_id: opt.Some(workflow_id),
    rules: Loading,
    rules_metrics: Loading,
  )
}

fn rules_fetched_ok(
  state: admin_rules.Model,
  rules: List(Rule),
) -> admin_rules.Model {
  admin_rules.Model(..state, rules: Loaded(rules))
}

fn rules_fetched_error(
  state: admin_rules.Model,
  err: ApiError,
) -> admin_rules.Model {
  admin_rules.Model(..state, rules: Failed(err))
}

fn rule_metrics_fetched_ok(
  state: admin_rules.Model,
  metrics: api_rule_metrics.WorkflowMetrics,
) -> admin_rules.Model {
  admin_rules.Model(..state, rules_metrics: Loaded(metrics))
}

fn rule_metrics_fetched_error(
  state: admin_rules.Model,
  err: ApiError,
) -> admin_rules.Model {
  admin_rules.Model(..state, rules_metrics: Failed(err))
}

fn rules_back_clicked(state: admin_rules.Model) -> admin_rules.Model {
  admin_rules.Model(
    ..state,
    rules_workflow_id: opt.None,
    rules: NotAsked,
    rules_metrics: NotAsked,
  )
}

fn open_rule_dialog(
  state: admin_rules.Model,
  mode: admin_rules.RuleDialogMode,
) -> admin_rules.Model {
  case mode {
    admin_rules.RuleDialogCreate ->
      admin_rules.Model(
        ..state,
        rules_dialog_mode: opt.Some(mode),
        rule_form_name: "",
        rule_form_goal: "",
        rule_form_subject: "task",
        rule_form_task_type_id: "",
        rule_form_event: "task_completed",
        rule_form_card_scope: "",
        rule_form_template_search: "",
        rule_form_template_id: "",
        rule_form_active: True,
        rule_form_submitting: False,
        rule_form_error: opt.None,
      )
    admin_rules.RuleDialogEdit(rule) -> {
      let #(subject, task_type_id, event, card_scope) =
        rule_trigger_form_values(rule.trigger)
      let template_id = selected_rule_template_id(rule.template)
      admin_rules.Model(
        ..state,
        rules_dialog_mode: opt.Some(mode),
        rule_form_name: rule.name,
        rule_form_goal: optional_text(rule.goal),
        rule_form_subject: subject,
        rule_form_task_type_id: task_type_id,
        rule_form_event: event,
        rule_form_card_scope: card_scope,
        rule_form_template_search: "",
        rule_form_template_id: template_id,
        rule_form_active: automation.status_to_active(rule.status),
        rule_form_submitting: False,
        rule_form_error: opt.None,
      )
    }
    admin_rules.RuleDialogDelete(_) ->
      admin_rules.Model(
        ..state,
        rules_dialog_mode: opt.Some(mode),
        rule_form_submitting: False,
        rule_form_error: opt.None,
      )
  }
}

fn selected_rule_template_id(
  template: opt.Option(workflow.RuleTemplate),
) -> String {
  case template {
    opt.Some(template) -> int.to_string(template.id)
    opt.None -> ""
  }
}

fn close_rule_dialog(state: admin_rules.Model) -> admin_rules.Model {
  admin_rules.Model(
    ..state,
    rules_dialog_mode: opt.None,
    rule_form_submitting: False,
    rule_form_error: opt.None,
  )
}

fn rule_trigger_form_values(
  trigger: automation.AutomationTrigger,
) -> #(String, String, String, String) {
  case trigger {
    automation.TaskCreated(task_type_id) -> #(
      "task",
      optional_int_text(task_type_id),
      "task_created",
      "",
    )
    automation.TaskCompleted(task_type_id) -> #(
      "task",
      optional_int_text(task_type_id),
      "task_completed",
      "",
    )
    automation.TaskClaimed(task_type_id) -> #(
      "task",
      optional_int_text(task_type_id),
      "task_claimed",
      "",
    )
    automation.TaskReleased(task_type_id) -> #(
      "task",
      optional_int_text(task_type_id),
      "task_released",
      "",
    )
    automation.CardActivated(scope) -> #(
      "card",
      "",
      "card_activated",
      card_scope_form_value(scope),
    )
    automation.CardClosed(scope) -> #(
      "card",
      "",
      "card_closed",
      card_scope_form_value(scope),
    )
  }
}

fn card_scope_form_value(scope: automation.CardAutomationScope) -> String {
  case scope {
    automation.AnyCard -> ""
    automation.AtDepth(depth) ->
      int.to_string(automation.card_depth_to_int(depth))
  }
}

fn optional_int_text(value: opt.Option(Int)) -> String {
  case value {
    opt.Some(id) -> int.to_string(id)
    opt.None -> ""
  }
}

fn engine_success_effect(
  success: EngineCrudSuccess,
  feedback: EngineFeedbackContext(parent_msg),
) -> Effect(parent_msg) {
  let message = case success {
    EngineCreated -> feedback.engine_created
    EngineUpdated -> feedback.engine_updated
    EngineDeleted -> feedback.engine_deleted
  }

  feedback.on_success_toast(message)
}

fn rule_success_effect(
  success: RuleSuccess,
  feedback: RuleFeedbackContext(parent_msg),
) -> Effect(parent_msg) {
  let message = case success {
    RuleCreated -> feedback.rule_created
    RuleUpdated -> feedback.rule_updated
    RuleDeleted -> feedback.rule_deleted
  }

  feedback.on_success_toast(message)
}
