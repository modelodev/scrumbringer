//// Admin workflows update handlers.
////
//// ## Mission
////
//// Handles workflow and rule CRUD operations in the admin panel.
////
//// ## Responsibilities
////
//// - Workflow list fetch and CRUD
//// - Rule list fetch and CRUD within workflows
//// - Rule expansion and builder state
////
//// ## Relations
////
//// - **update.gleam**: Main update module that delegates to handlers here
//// - **view.gleam**: Renders the workflows UI using model state

import gleam/int
import gleam/option as opt
import gleam/result
import gleam/set
import gleam/string

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError, type ApiResult}
import domain/card
import domain/remote.{Failed, Loaded, Loading, NotAsked}
import domain/task_status
import domain/task_type.{type TaskType}
import domain/workflow.{
  type Rule, type RuleTarget, type Workflow, CardRule, TaskRule,
}
import scrumbringer_client/client_state/admin/rules as admin_rules
import scrumbringer_client/client_state/admin/workflows as admin_workflows
import scrumbringer_client/features/admin/scoped_remote_list
import scrumbringer_client/features/pool/msg as pool_messages

import scrumbringer_client/api/tasks/task_types as task_types_api
import scrumbringer_client/api/workflows as api_workflows
import scrumbringer_client/api/workflows/rule_metrics as api_rule_metrics
import scrumbringer_client/api/workflows/rules as api_rules

type WorkflowSuccess {
  WorkflowCreated
  WorkflowUpdated
  WorkflowDeleted
}

pub type WorkflowFeedbackContext(parent_msg) {
  WorkflowFeedbackContext(
    workflow_created: String,
    workflow_updated: String,
    workflow_deleted: String,
    on_success_toast: fn(String) -> Effect(parent_msg),
    on_workflow_saved: fn(ApiResult(Workflow)) -> parent_msg,
    on_workflow_deleted: fn(Int, ApiResult(Nil)) -> parent_msg,
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

pub type WorkflowAuthPolicy {
  NoWorkflowAuthCheck
  CheckWorkflowAuth(ApiError)
}

pub type WorkflowUpdate(parent_msg) {
  WorkflowUpdate(admin_workflows.Model, Effect(parent_msg), WorkflowAuthPolicy)
}

pub fn try_workflows_update(
  state: admin_workflows.Model,
  inner: pool_messages.Msg,
  feedback: WorkflowFeedbackContext(parent_msg),
) -> opt.Option(WorkflowUpdate(parent_msg)) {
  case inner {
    pool_messages.WorkflowsProjectFetched(Ok(workflows)) ->
      workflows_project_fetched_ok(state, workflows)
      |> without_workflow_auth_check

    pool_messages.WorkflowsProjectFetched(Error(err)) ->
      workflows_project_fetched_error(state, err)
      |> with_workflow_auth_check(err)

    pool_messages.WorkflowsSearchChanged(query) ->
      admin_workflows.Model(..state, workflows_search: query)
      |> without_workflow_auth_check

    pool_messages.WorkflowsStatusFilterChanged(status) ->
      admin_workflows.Model(..state, workflows_status_filter: status)
      |> without_workflow_auth_check

    pool_messages.OpenWorkflowDialog(mode) ->
      open_workflow_dialog(state, mode)
      |> without_workflow_auth_check

    pool_messages.CloseWorkflowDialog ->
      close_workflow_dialog(state)
      |> without_workflow_auth_check

    pool_messages.WorkflowNameChanged(value) ->
      admin_workflows.Model(..state, workflow_form_name: value)
      |> without_workflow_auth_check

    pool_messages.WorkflowDescriptionChanged(value) ->
      admin_workflows.Model(..state, workflow_form_description: value)
      |> without_workflow_auth_check

    pool_messages.WorkflowActiveChanged(value) ->
      admin_workflows.Model(..state, workflow_form_active: value)
      |> without_workflow_auth_check

    pool_messages.WorkflowFormSubmitted(project_id) ->
      submit_workflow_form(state, project_id, feedback)
      |> without_workflow_tuple_auth_check

    pool_messages.WorkflowSaved(Ok(workflow)) ->
      workflow_saved(state, workflow)
      |> with_workflow_effect(workflow_success_effect(
        success_for_workflow_saved(state),
        feedback,
      ))

    pool_messages.WorkflowSaved(Error(err)) ->
      workflow_form_error(state, err.message)
      |> with_workflow_auth_check(err)

    pool_messages.WorkflowDeleteConfirmed ->
      confirm_workflow_delete(state, feedback)
      |> without_workflow_tuple_auth_check

    pool_messages.WorkflowDeleteFinished(workflow_id, Ok(_)) ->
      workflow_deleted(state, workflow_id)
      |> with_workflow_effect(workflow_success_effect(WorkflowDeleted, feedback))

    pool_messages.WorkflowDeleteFinished(_workflow_id, Error(err)) ->
      workflow_form_error(state, err.message)
      |> with_workflow_auth_check(err)

    _ -> opt.None
  }
}

fn without_workflow_auth_check(
  state: admin_workflows.Model,
) -> opt.Option(WorkflowUpdate(parent_msg)) {
  with_workflow_effect(state, effect.none())
}

fn without_workflow_tuple_auth_check(
  result: #(admin_workflows.Model, Effect(parent_msg)),
) -> opt.Option(WorkflowUpdate(parent_msg)) {
  let #(state, fx) = result
  with_workflow_effect(state, fx)
}

fn with_workflow_auth_check(
  state: admin_workflows.Model,
  err: ApiError,
) -> opt.Option(WorkflowUpdate(parent_msg)) {
  opt.Some(WorkflowUpdate(state, effect.none(), CheckWorkflowAuth(err)))
}

fn with_workflow_effect(
  state: admin_workflows.Model,
  fx: Effect(parent_msg),
) -> opt.Option(WorkflowUpdate(parent_msg)) {
  opt.Some(WorkflowUpdate(state, fx, NoWorkflowAuthCheck))
}

fn workflows_project_fetched_ok(
  state: admin_workflows.Model,
  workflows: List(Workflow),
) -> admin_workflows.Model {
  admin_workflows.Model(..state, workflows_project: Loaded(workflows))
}

fn workflows_project_fetched_error(
  state: admin_workflows.Model,
  err: ApiError,
) -> admin_workflows.Model {
  admin_workflows.Model(..state, workflows_project: Failed(err))
}

fn open_workflow_dialog(
  state: admin_workflows.Model,
  mode: admin_workflows.WorkflowDialogMode,
) -> admin_workflows.Model {
  case mode {
    admin_workflows.WorkflowDialogCreate ->
      admin_workflows.Model(
        ..state,
        workflows_dialog_mode: opt.Some(mode),
        workflow_form_name: "",
        workflow_form_description: "",
        workflow_form_active: True,
        workflow_form_submitting: False,
        workflow_form_error: opt.None,
      )
    admin_workflows.WorkflowDialogEdit(workflow) ->
      admin_workflows.Model(
        ..state,
        workflows_dialog_mode: opt.Some(mode),
        workflow_form_name: workflow.name,
        workflow_form_description: optional_text(workflow.description),
        workflow_form_active: workflow.active,
        workflow_form_submitting: False,
        workflow_form_error: opt.None,
      )
    admin_workflows.WorkflowDialogDelete(_) ->
      admin_workflows.Model(
        ..state,
        workflows_dialog_mode: opt.Some(mode),
        workflow_form_submitting: False,
        workflow_form_error: opt.None,
      )
  }
}

fn close_workflow_dialog(state: admin_workflows.Model) -> admin_workflows.Model {
  admin_workflows.Model(
    ..state,
    workflows_dialog_mode: opt.None,
    workflow_form_submitting: False,
    workflow_form_error: opt.None,
  )
}

fn optional_text(value: opt.Option(String)) -> String {
  case value {
    opt.Some(text) -> text
    opt.None -> ""
  }
}

fn submit_workflow_form(
  state: admin_workflows.Model,
  selected_project_id: opt.Option(Int),
  feedback: WorkflowFeedbackContext(parent_msg),
) -> #(admin_workflows.Model, Effect(parent_msg)) {
  case state.workflows_dialog_mode {
    opt.Some(admin_workflows.WorkflowDialogCreate) ->
      submit_workflow_create(state, selected_project_id, feedback)
    opt.Some(admin_workflows.WorkflowDialogEdit(workflow)) ->
      submit_workflow_update(state, workflow.id, feedback)
    _ -> #(state, effect.none())
  }
}

fn submit_workflow_create(
  state: admin_workflows.Model,
  selected_project_id: opt.Option(Int),
  feedback: WorkflowFeedbackContext(parent_msg),
) -> #(admin_workflows.Model, Effect(parent_msg)) {
  case selected_project_id {
    opt.None -> #(
      workflow_form_error(state, "Select a project first"),
      effect.none(),
    )
    opt.Some(project_id) ->
      case parse_workflow_form(state) {
        Error(message) -> #(workflow_form_error(state, message), effect.none())
        Ok(form) -> #(
          workflow_form_submitting(state),
          api_workflows.create_project_workflow(
            project_id,
            form.name,
            form.description,
            form.active,
            feedback.on_workflow_saved,
          ),
        )
      }
  }
}

fn submit_workflow_update(
  state: admin_workflows.Model,
  workflow_id: Int,
  feedback: WorkflowFeedbackContext(parent_msg),
) -> #(admin_workflows.Model, Effect(parent_msg)) {
  case parse_workflow_form(state) {
    Error(message) -> #(workflow_form_error(state, message), effect.none())
    Ok(form) -> #(
      workflow_form_submitting(state),
      api_workflows.update_workflow(
        workflow_id,
        form.name,
        form.description,
        form.active,
        feedback.on_workflow_saved,
      ),
    )
  }
}

fn confirm_workflow_delete(
  state: admin_workflows.Model,
  feedback: WorkflowFeedbackContext(parent_msg),
) -> #(admin_workflows.Model, Effect(parent_msg)) {
  case state.workflows_dialog_mode {
    opt.Some(admin_workflows.WorkflowDialogDelete(workflow)) -> #(
      workflow_form_submitting(state),
      api_workflows.delete_workflow(workflow.id, fn(result) {
        feedback.on_workflow_deleted(workflow.id, result)
      }),
    )
    _ -> #(state, effect.none())
  }
}

type WorkflowForm {
  WorkflowForm(name: String, description: String, active: Bool)
}

fn parse_workflow_form(
  state: admin_workflows.Model,
) -> Result(WorkflowForm, String) {
  let name = string.trim(state.workflow_form_name)
  case name {
    "" -> Error("Engine name is required")
    _ ->
      Ok(WorkflowForm(
        name: name,
        description: state.workflow_form_description,
        active: state.workflow_form_active,
      ))
  }
}

fn workflow_form_submitting(
  state: admin_workflows.Model,
) -> admin_workflows.Model {
  admin_workflows.Model(
    ..state,
    workflow_form_submitting: True,
    workflow_form_error: opt.None,
  )
}

fn workflow_form_error(
  state: admin_workflows.Model,
  message: String,
) -> admin_workflows.Model {
  admin_workflows.Model(
    ..state,
    workflow_form_submitting: False,
    workflow_form_error: opt.Some(message),
  )
}

fn success_for_workflow_saved(state: admin_workflows.Model) -> WorkflowSuccess {
  case state.workflows_dialog_mode {
    opt.Some(admin_workflows.WorkflowDialogEdit(_)) -> WorkflowUpdated
    _ -> WorkflowCreated
  }
}

fn workflow_saved(
  state: admin_workflows.Model,
  workflow: Workflow,
) -> admin_workflows.Model {
  case state.workflows_dialog_mode {
    opt.Some(admin_workflows.WorkflowDialogEdit(_)) ->
      workflow_updated(state, workflow)
    _ -> workflow_created(state, workflow)
  }
}

fn workflow_created(
  state: admin_workflows.Model,
  workflow: Workflow,
) -> admin_workflows.Model {
  let #(org, project) =
    scoped_remote_list.prepend_for_scope(
      state.workflows_org,
      state.workflows_project,
      workflow.project_id,
      workflow,
    )

  admin_workflows.Model(
    ..state,
    workflows_org: org,
    workflows_project: project,
    workflows_dialog_mode: opt.None,
    workflow_form_name: "",
    workflow_form_description: "",
    workflow_form_active: True,
    workflow_form_submitting: False,
    workflow_form_error: opt.None,
  )
}

fn workflow_updated(
  state: admin_workflows.Model,
  updated_workflow: Workflow,
) -> admin_workflows.Model {
  let org =
    scoped_remote_list.replace_by_id(
      state.workflows_org,
      updated_workflow,
      fn(workflow: Workflow) { workflow.id },
    )
  let project =
    scoped_remote_list.replace_by_id(
      state.workflows_project,
      updated_workflow,
      fn(workflow: Workflow) { workflow.id },
    )

  admin_workflows.Model(
    ..state,
    workflows_org: org,
    workflows_project: project,
    workflows_dialog_mode: opt.None,
    workflow_form_submitting: False,
    workflow_form_error: opt.None,
  )
}

fn workflow_deleted(
  state: admin_workflows.Model,
  workflow_id: Int,
) -> admin_workflows.Model {
  let org =
    scoped_remote_list.remove_by_id(
      state.workflows_org,
      workflow_id,
      fn(workflow: Workflow) { workflow.id },
    )
  let project =
    scoped_remote_list.remove_by_id(
      state.workflows_project,
      workflow_id,
      fn(workflow: Workflow) { workflow.id },
    )

  admin_workflows.Model(
    ..state,
    workflows_org: org,
    workflows_project: project,
    workflows_dialog_mode: opt.None,
    workflow_form_submitting: False,
    workflow_form_error: opt.None,
  )
}

fn rule_subject_changed(
  state: admin_rules.Model,
  subject: String,
) -> admin_rules.Model {
  let event = case subject, state.rule_form_event {
    "task", "task_claimed" -> "task_claimed"
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
            form.target,
            form.template_id,
            form.active,
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
        form.target,
        form.template_id,
        form.active,
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
    target: RuleTarget,
    template_id: Int,
    active: Bool,
  )
}

fn parse_rule_form(state: admin_rules.Model) -> Result(RuleForm, String) {
  let name = string.trim(state.rule_form_name)
  case name {
    "" -> Error("Rule name is required")
    _ -> {
      use target <- result.try(parse_rule_target_form(state))
      use template_id <- result.try(parse_rule_template_id(
        state.rule_form_template_id,
      ))
      Ok(RuleForm(
        name: name,
        goal: state.rule_form_goal,
        target: target,
        template_id: template_id,
        active: state.rule_form_active,
      ))
    }
  }
}

fn parse_rule_target_form(
  state: admin_rules.Model,
) -> Result(RuleTarget, String) {
  case state.rule_form_event {
    "task_completed" -> {
      use task_type_id <- result.try(parse_rule_task_type_id(
        state.rule_form_task_type_id,
      ))
      Ok(TaskRule(task_status.Done, task_type_id))
    }
    "task_claimed" -> {
      use task_type_id <- result.try(parse_rule_task_type_id(
        state.rule_form_task_type_id,
      ))
      Ok(TaskRule(task_status.Claimed(task_status.Taken), task_type_id))
    }
    "card_activated" -> Ok(CardRule(card.Active))
    "card_closed" -> Ok(CardRule(card.Closed))
    _ -> Error("Choose a supported automation event")
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
        rule_form_template_id: "",
        rule_form_active: True,
        rule_form_submitting: False,
        rule_form_error: opt.None,
      )
    admin_rules.RuleDialogEdit(rule) -> {
      let #(subject, task_type_id, event) = rule_target_form_values(rule.target)
      let template_id = selected_rule_template_id(rule.template)
      admin_rules.Model(
        ..state,
        rules_dialog_mode: opt.Some(mode),
        rule_form_name: rule.name,
        rule_form_goal: optional_text(rule.goal),
        rule_form_subject: subject,
        rule_form_task_type_id: task_type_id,
        rule_form_event: event,
        rule_form_template_id: template_id,
        rule_form_active: rule.active,
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

fn rule_target_form_values(target: RuleTarget) -> #(String, String, String) {
  case target {
    TaskRule(task_status.Done, task_type_id) -> #(
      "task",
      optional_int_text(task_type_id),
      "task_completed",
    )
    TaskRule(task_status.Claimed(_), task_type_id) -> #(
      "task",
      optional_int_text(task_type_id),
      "task_claimed",
    )
    TaskRule(_, task_type_id) -> #(
      "task",
      optional_int_text(task_type_id),
      "unsupported",
    )
    CardRule(card.Active) -> #("card", "", "card_activated")
    CardRule(card.Closed) -> #("card", "", "card_closed")
    CardRule(_) -> #("card", "", "unsupported")
  }
}

fn optional_int_text(value: opt.Option(Int)) -> String {
  case value {
    opt.Some(id) -> int.to_string(id)
    opt.None -> ""
  }
}

fn workflow_success_effect(
  success: WorkflowSuccess,
  feedback: WorkflowFeedbackContext(parent_msg),
) -> Effect(parent_msg) {
  let message = case success {
    WorkflowCreated -> feedback.workflow_created
    WorkflowUpdated -> feedback.workflow_updated
    WorkflowDeleted -> feedback.workflow_deleted
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
