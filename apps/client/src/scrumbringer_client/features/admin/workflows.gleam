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
//// - Rule-template attachment management
////
//// ## Relations
////
//// - **update.gleam**: Main update module that delegates to handlers here
//// - **view.gleam**: Renders the workflows UI using model state

import gleam/list
import gleam/option as opt
import gleam/set

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError, type ApiResult}
import domain/remote.{type Remote, Failed, Loaded, Loading, NotAsked}
import domain/task_type.{type TaskType}
import domain/workflow.{
  type Rule, type RuleTemplate, type TaskTemplate, type Workflow,
}
import scrumbringer_client/client_state/admin/rules as admin_rules
import scrumbringer_client/client_state/admin/task_templates as admin_task_templates
import scrumbringer_client/client_state/admin/workflows as admin_workflows
import scrumbringer_client/client_state/types as state_types
import scrumbringer_client/features/pool/msg as pool_messages

import scrumbringer_client/api/tasks/task_types as task_types_api
import scrumbringer_client/api/workflows/rule_metrics as api_rule_metrics
import scrumbringer_client/api/workflows/rules as api_rules
import scrumbringer_client/api/workflows/task_templates as api_task_templates

pub type WorkflowSuccess {
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
  )
}

pub type RuleSuccess {
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

pub type TemplateAttachmentModel {
  TemplateAttachmentModel(
    rules: admin_rules.Model,
    task_templates: admin_task_templates.Model,
  )
}

pub type TemplateAttachmentContext(parent_msg) {
  TemplateAttachmentContext(
    selected_project_id: opt.Option(Int),
    on_task_templates_fetched: fn(ApiResult(List(TaskTemplate))) -> parent_msg,
    on_attach_template_succeeded: fn(Int, List(RuleTemplate)) -> parent_msg,
    on_attach_template_failed: fn(ApiError) -> parent_msg,
    on_template_detach_succeeded: fn(Int, Int) -> parent_msg,
    on_template_detach_failed: fn(Int, Int, ApiError) -> parent_msg,
  )
}

pub type TemplateAttachmentAuthPolicy {
  NoTemplateAttachmentAuthCheck
  CheckTemplateAttachmentAuth(ApiError)
}

pub type TemplateAttachmentUpdate(parent_msg) {
  TemplateAttachmentUpdate(
    TemplateAttachmentModel,
    Effect(parent_msg),
    TemplateAttachmentAuthPolicy,
  )
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

    pool_messages.RuleCrudCreated(rule) ->
      #(rule_created(state, rule), rule_success_effect(RuleCreated, feedback))
      |> without_rules_auth_check

    pool_messages.RuleCrudUpdated(rule) ->
      #(rule_updated(state, rule), rule_success_effect(RuleUpdated, feedback))
      |> without_rules_auth_check

    pool_messages.RuleCrudDeleted(rule_id) ->
      #(
        rule_deleted(state, rule_id),
        rule_success_effect(RuleDeleted, feedback),
      )
      |> without_rules_auth_check

    _ -> opt.None
  }
}

pub fn try_template_attachment_update(
  state: TemplateAttachmentModel,
  inner: pool_messages.Msg,
  context: TemplateAttachmentContext(parent_msg),
  feedback: TemplateAttachmentFeedbackContext(parent_msg),
) -> opt.Option(TemplateAttachmentUpdate(parent_msg)) {
  case inner {
    pool_messages.RuleExpandToggled(rule_id) ->
      #(rule_expand_toggled(state, rule_id), effect.none())
      |> without_template_attachment_auth_check

    pool_messages.AttachTemplateModalOpened(rule_id) ->
      attach_template_modal_opened(state, rule_id, context)
      |> without_template_attachment_auth_check

    pool_messages.AttachTemplateModalClosed ->
      #(attach_template_modal_closed(state), effect.none())
      |> without_template_attachment_auth_check

    pool_messages.AttachTemplateSelected(template_id) ->
      #(attach_template_selected(state, template_id), effect.none())
      |> without_template_attachment_auth_check

    pool_messages.AttachTemplateSubmitted ->
      attach_template_submitted(state, context)
      |> without_template_attachment_auth_check

    pool_messages.AttachTemplateSucceeded(rule_id, templates) ->
      #(
        attach_template_success_local(state, rule_id, templates),
        template_attachment_success_effect(TemplateAttached, feedback),
      )
      |> without_template_attachment_auth_check

    pool_messages.AttachTemplateFailed(err) ->
      #(
        attach_template_failed_local(state),
        feedback.on_error_toast(err.message),
      )
      |> with_template_attachment_auth_check(err)

    pool_messages.TemplateDetachClicked(rule_id, template_id) ->
      template_detach_clicked(state, rule_id, template_id, context)
      |> without_template_attachment_auth_check

    pool_messages.TemplateDetachSucceeded(rule_id, template_id) ->
      #(
        template_detach_success_local(state, rule_id, template_id),
        template_attachment_success_effect(TemplateDetached, feedback),
      )
      |> without_template_attachment_auth_check

    pool_messages.TemplateDetachFailed(rule_id, template_id, err) ->
      #(
        template_detach_failed_local(state, rule_id, template_id),
        feedback.on_error_toast(err.message),
      )
      |> with_template_attachment_auth_check(err)

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
  state: TemplateAttachmentModel,
  rule_id: Int,
) -> TemplateAttachmentModel {
  let TemplateAttachmentModel(rules: rules, task_templates: task_templates) =
    state
  let expanded = case set.contains(rules.rules_expanded, rule_id) {
    True -> set.delete(rules.rules_expanded, rule_id)
    False -> set.insert(rules.rules_expanded, rule_id)
  }

  TemplateAttachmentModel(
    rules: admin_rules.Model(..rules, rules_expanded: expanded),
    task_templates: task_templates,
  )
}

fn attach_template_modal_opened(
  state: TemplateAttachmentModel,
  rule_id: Int,
  context: TemplateAttachmentContext(parent_msg),
) -> #(TemplateAttachmentModel, Effect(parent_msg)) {
  let TemplateAttachmentModel(rules: rules, task_templates: task_templates) =
    state

  let fetch_effect = case
    task_templates.task_templates_project,
    context.selected_project_id
  {
    Loaded(_), _ -> effect.none()
    Loading, _ -> effect.none()
    _, opt.Some(project_id) ->
      api_task_templates.list_project_templates(
        project_id,
        context.on_task_templates_fetched,
      )
    _, opt.None -> effect.none()
  }

  let task_templates_project = case
    task_templates.task_templates_project,
    context.selected_project_id
  {
    Loaded(_), _ -> task_templates.task_templates_project
    Loading, _ -> task_templates.task_templates_project
    _, opt.Some(_) -> Loading
    _, opt.None -> task_templates.task_templates_project
  }

  #(
    TemplateAttachmentModel(
      rules: admin_rules.Model(
        ..rules,
        attach_template_modal: opt.Some(rule_id),
        attach_template_selected: opt.None,
        attach_template_loading: False,
      ),
      task_templates: admin_task_templates.Model(
        ..task_templates,
        task_templates_project: task_templates_project,
      ),
    ),
    fetch_effect,
  )
}

fn attach_template_modal_closed(
  state: TemplateAttachmentModel,
) -> TemplateAttachmentModel {
  let TemplateAttachmentModel(rules: rules, task_templates: task_templates) =
    state
  TemplateAttachmentModel(
    rules: admin_rules.Model(
      ..rules,
      attach_template_modal: opt.None,
      attach_template_selected: opt.None,
      attach_template_loading: False,
    ),
    task_templates: task_templates,
  )
}

fn attach_template_selected(
  state: TemplateAttachmentModel,
  template_id: Int,
) -> TemplateAttachmentModel {
  let TemplateAttachmentModel(rules: rules, task_templates: task_templates) =
    state
  TemplateAttachmentModel(
    rules: admin_rules.Model(
      ..rules,
      attach_template_selected: opt.Some(template_id),
    ),
    task_templates: task_templates,
  )
}

fn attach_template_submitted(
  state: TemplateAttachmentModel,
  context: TemplateAttachmentContext(parent_msg),
) -> #(TemplateAttachmentModel, Effect(parent_msg)) {
  let TemplateAttachmentModel(rules: rules, task_templates: task_templates) =
    state

  case rules.attach_template_modal, rules.attach_template_selected {
    opt.Some(rule_id), opt.Some(template_id) -> {
      let order = next_template_order(rules, rule_id)
      #(
        TemplateAttachmentModel(
          rules: admin_rules.Model(..rules, attach_template_loading: True),
          task_templates: task_templates,
        ),
        api_rules.attach_template(rule_id, template_id, order, fn(result) {
          case result {
            Ok(templates) ->
              context.on_attach_template_succeeded(rule_id, templates)
            Error(err) -> context.on_attach_template_failed(err)
          }
        }),
      )
    }
    _, _ -> #(state, effect.none())
  }
}

fn next_template_order(rules_state: admin_rules.Model, rule_id: Int) -> Int {
  case rules_state.rules {
    Loaded(rules) ->
      case list.find(rules, fn(rule) { rule.id == rule_id }) {
        Ok(rule) -> list.length(rule.templates) + 1
        Error(_) -> 1
      }
    _ -> 1
  }
}

fn attach_template_success_local(
  state: TemplateAttachmentModel,
  rule_id: Int,
  templates: List(RuleTemplate),
) -> TemplateAttachmentModel {
  let TemplateAttachmentModel(rules: rules, task_templates: task_templates) =
    state
  TemplateAttachmentModel(
    rules: attach_template_succeeded(rules, rule_id, templates),
    task_templates: task_templates,
  )
}

fn attach_template_failed_local(
  state: TemplateAttachmentModel,
) -> TemplateAttachmentModel {
  let TemplateAttachmentModel(rules: rules, task_templates: task_templates) =
    state
  TemplateAttachmentModel(
    rules: attach_template_failed(rules),
    task_templates: task_templates,
  )
}

fn template_detach_clicked(
  state: TemplateAttachmentModel,
  rule_id: Int,
  template_id: Int,
  context: TemplateAttachmentContext(parent_msg),
) -> #(TemplateAttachmentModel, Effect(parent_msg)) {
  let TemplateAttachmentModel(rules: rules, task_templates: task_templates) =
    state
  #(
    TemplateAttachmentModel(
      rules: template_detach_started(rules, rule_id, template_id),
      task_templates: task_templates,
    ),
    api_rules.detach_template(rule_id, template_id, fn(result) {
      case result {
        Ok(_) -> context.on_template_detach_succeeded(rule_id, template_id)
        Error(err) ->
          context.on_template_detach_failed(rule_id, template_id, err)
      }
    }),
  )
}

fn template_detach_success_local(
  state: TemplateAttachmentModel,
  rule_id: Int,
  template_id: Int,
) -> TemplateAttachmentModel {
  let TemplateAttachmentModel(rules: rules, task_templates: task_templates) =
    state
  TemplateAttachmentModel(
    rules: template_detach_succeeded(rules, rule_id, template_id),
    task_templates: task_templates,
  )
}

fn template_detach_failed_local(
  state: TemplateAttachmentModel,
  rule_id: Int,
  template_id: Int,
) -> TemplateAttachmentModel {
  let TemplateAttachmentModel(rules: rules, task_templates: task_templates) =
    state
  TemplateAttachmentModel(
    rules: template_detach_failed(rules, rule_id, template_id),
    task_templates: task_templates,
  )
}

fn without_template_attachment_auth_check(
  result: #(TemplateAttachmentModel, Effect(parent_msg)),
) -> opt.Option(TemplateAttachmentUpdate(parent_msg)) {
  let #(state, fx) = result
  opt.Some(TemplateAttachmentUpdate(state, fx, NoTemplateAttachmentAuthCheck))
}

fn with_template_attachment_auth_check(
  result: #(TemplateAttachmentModel, Effect(parent_msg)),
  err: ApiError,
) -> opt.Option(TemplateAttachmentUpdate(parent_msg)) {
  let #(state, fx) = result
  opt.Some(TemplateAttachmentUpdate(state, fx, CheckTemplateAttachmentAuth(err)))
}

pub type TemplateAttachmentSuccess {
  TemplateAttached
  TemplateDetached
}

pub type TemplateAttachmentFeedbackContext(parent_msg) {
  TemplateAttachmentFeedbackContext(
    template_attached: String,
    template_detached: String,
    on_success_toast: fn(String) -> Effect(parent_msg),
    on_error_toast: fn(String) -> Effect(parent_msg),
  )
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

    pool_messages.OpenWorkflowDialog(mode) ->
      open_workflow_dialog(state, mode)
      |> without_workflow_auth_check

    pool_messages.CloseWorkflowDialog ->
      close_workflow_dialog(state)
      |> without_workflow_auth_check

    pool_messages.WorkflowCrudCreated(workflow) ->
      workflow_created(state, workflow)
      |> with_workflow_effect(workflow_success_effect(WorkflowCreated, feedback))

    pool_messages.WorkflowCrudUpdated(workflow) ->
      workflow_updated(state, workflow)
      |> with_workflow_effect(workflow_success_effect(WorkflowUpdated, feedback))

    pool_messages.WorkflowCrudDeleted(workflow_id) ->
      workflow_deleted(state, workflow_id)
      |> with_workflow_effect(workflow_success_effect(WorkflowDeleted, feedback))

    _ -> opt.None
  }
}

fn without_workflow_auth_check(
  state: admin_workflows.Model,
) -> opt.Option(WorkflowUpdate(parent_msg)) {
  with_workflow_effect(state, effect.none())
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

pub fn workflows_project_fetched_ok(
  state: admin_workflows.Model,
  workflows: List(Workflow),
) -> admin_workflows.Model {
  admin_workflows.Model(..state, workflows_project: Loaded(workflows))
}

pub fn workflows_project_fetched_error(
  state: admin_workflows.Model,
  err: ApiError,
) -> admin_workflows.Model {
  admin_workflows.Model(..state, workflows_project: Failed(err))
}

pub fn open_workflow_dialog(
  state: admin_workflows.Model,
  mode: state_types.WorkflowDialogMode,
) -> admin_workflows.Model {
  admin_workflows.Model(..state, workflows_dialog_mode: opt.Some(mode))
}

pub fn close_workflow_dialog(
  state: admin_workflows.Model,
) -> admin_workflows.Model {
  admin_workflows.Model(..state, workflows_dialog_mode: opt.None)
}

pub fn workflow_created(
  state: admin_workflows.Model,
  workflow: Workflow,
) -> admin_workflows.Model {
  let #(org, project) =
    prepend_for_scope(
      state.workflows_org,
      state.workflows_project,
      workflow.project_id,
      workflow,
    )

  admin_workflows.Model(
    workflows_org: org,
    workflows_project: project,
    workflows_dialog_mode: opt.None,
  )
}

pub fn workflow_updated(
  state: admin_workflows.Model,
  updated_workflow: Workflow,
) -> admin_workflows.Model {
  let org =
    replace_loaded_by_id(
      state.workflows_org,
      updated_workflow,
      fn(workflow: Workflow) { workflow.id },
    )
  let project =
    replace_loaded_by_id(
      state.workflows_project,
      updated_workflow,
      fn(workflow: Workflow) { workflow.id },
    )

  admin_workflows.Model(
    workflows_org: org,
    workflows_project: project,
    workflows_dialog_mode: opt.None,
  )
}

pub fn workflow_deleted(
  state: admin_workflows.Model,
  workflow_id: Int,
) -> admin_workflows.Model {
  let org =
    remove_loaded_by_id(
      state.workflows_org,
      workflow_id,
      fn(workflow: Workflow) { workflow.id },
    )
  let project =
    remove_loaded_by_id(
      state.workflows_project,
      workflow_id,
      fn(workflow: Workflow) { workflow.id },
    )

  admin_workflows.Model(
    workflows_org: org,
    workflows_project: project,
    workflows_dialog_mode: opt.None,
  )
}

pub fn rule_created(state: admin_rules.Model, rule: Rule) -> admin_rules.Model {
  let rules = case state.rules {
    Loaded(existing) -> Loaded([rule, ..existing])
    _ -> Loaded([rule])
  }

  admin_rules.Model(..state, rules: rules, rules_dialog_mode: opt.None)
}

pub fn rule_updated(
  state: admin_rules.Model,
  updated_rule: Rule,
) -> admin_rules.Model {
  let rules =
    replace_loaded_by_id(state.rules, updated_rule, fn(rule: Rule) { rule.id })

  admin_rules.Model(..state, rules: rules, rules_dialog_mode: opt.None)
}

pub fn rule_deleted(state: admin_rules.Model, rule_id: Int) -> admin_rules.Model {
  let rules =
    remove_loaded_by_id(state.rules, rule_id, fn(rule: Rule) { rule.id })

  admin_rules.Model(..state, rules: rules, rules_dialog_mode: opt.None)
}

pub fn workflow_rules_opened(
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

pub fn rules_fetched_ok(
  state: admin_rules.Model,
  rules: List(Rule),
) -> admin_rules.Model {
  admin_rules.Model(..state, rules: Loaded(rules))
}

pub fn rules_fetched_error(
  state: admin_rules.Model,
  err: ApiError,
) -> admin_rules.Model {
  admin_rules.Model(..state, rules: Failed(err))
}

pub fn rule_metrics_fetched_ok(
  state: admin_rules.Model,
  metrics: api_rule_metrics.WorkflowMetrics,
) -> admin_rules.Model {
  admin_rules.Model(..state, rules_metrics: Loaded(metrics))
}

pub fn rule_metrics_fetched_error(
  state: admin_rules.Model,
  err: ApiError,
) -> admin_rules.Model {
  admin_rules.Model(..state, rules_metrics: Failed(err))
}

pub fn rules_back_clicked(state: admin_rules.Model) -> admin_rules.Model {
  admin_rules.Model(
    ..state,
    rules_workflow_id: opt.None,
    rules: NotAsked,
    rules_metrics: NotAsked,
  )
}

pub fn open_rule_dialog(
  state: admin_rules.Model,
  mode: state_types.RuleDialogMode,
) -> admin_rules.Model {
  admin_rules.Model(..state, rules_dialog_mode: opt.Some(mode))
}

pub fn close_rule_dialog(state: admin_rules.Model) -> admin_rules.Model {
  admin_rules.Model(..state, rules_dialog_mode: opt.None)
}

pub fn attach_template_succeeded(
  state: admin_rules.Model,
  rule_id: Int,
  templates: List(RuleTemplate),
) -> admin_rules.Model {
  let rules =
    map_loaded(state.rules, fn(rules) {
      list.map(rules, fn(rule) {
        case rule.id == rule_id {
          True -> workflow.Rule(..rule, templates: templates)
          False -> rule
        }
      })
    })

  admin_rules.Model(
    ..state,
    rules: rules,
    attach_template_modal: opt.None,
    attach_template_selected: opt.None,
    attach_template_loading: False,
  )
}

pub fn attach_template_failed(state: admin_rules.Model) -> admin_rules.Model {
  admin_rules.Model(..state, attach_template_loading: False)
}

pub fn template_detach_started(
  state: admin_rules.Model,
  rule_id: Int,
  template_id: Int,
) -> admin_rules.Model {
  admin_rules.Model(
    ..state,
    detaching_templates: set.insert(state.detaching_templates, #(
      rule_id,
      template_id,
    )),
  )
}

pub fn template_detach_succeeded(
  state: admin_rules.Model,
  rule_id: Int,
  template_id: Int,
) -> admin_rules.Model {
  let rules =
    map_loaded(state.rules, fn(rules) {
      list.map(rules, fn(rule) {
        case rule.id == rule_id {
          True ->
            workflow.Rule(
              ..rule,
              templates: list.filter(rule.templates, fn(template) {
                template.id != template_id
              }),
            )
          False -> rule
        }
      })
    })

  admin_rules.Model(
    ..state,
    rules: rules,
    detaching_templates: set.delete(state.detaching_templates, #(
      rule_id,
      template_id,
    )),
  )
}

pub fn template_detach_failed(
  state: admin_rules.Model,
  rule_id: Int,
  template_id: Int,
) -> admin_rules.Model {
  admin_rules.Model(
    ..state,
    detaching_templates: set.delete(state.detaching_templates, #(
      rule_id,
      template_id,
    )),
  )
}

pub fn workflow_success_effect(
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

pub fn rule_success_effect(
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

pub fn template_attachment_success_effect(
  success: TemplateAttachmentSuccess,
  feedback: TemplateAttachmentFeedbackContext(parent_msg),
) -> Effect(parent_msg) {
  let message = case success {
    TemplateAttached -> feedback.template_attached
    TemplateDetached -> feedback.template_detached
  }

  feedback.on_success_toast(message)
}

// =============================================================================
// Fetch Helpers
// =============================================================================

/// Fetch workflows for admin panel (project-scoped only).
fn prepend_for_scope(
  org: Remote(List(a)),
  project: Remote(List(a)),
  project_id: opt.Option(Int),
  item: a,
) -> #(Remote(List(a)), Remote(List(a))) {
  case project_id {
    opt.Some(_) -> #(org, prepend_loaded_or_new(project, item))
    opt.None -> #(prepend_loaded_or_new(org, item), project)
  }
}

fn prepend_loaded_or_new(remote: Remote(List(a)), item: a) -> Remote(List(a)) {
  case remote {
    Loaded(existing) -> Loaded([item, ..existing])
    _ -> Loaded([item])
  }
}

fn replace_loaded_by_id(
  remote: Remote(List(a)),
  updated: a,
  id: fn(a) -> Int,
) -> Remote(List(a)) {
  map_loaded(remote, fn(items) {
    list.map(items, fn(item) {
      case id(item) == id(updated) {
        True -> updated
        False -> item
      }
    })
  })
}

fn remove_loaded_by_id(
  remote: Remote(List(a)),
  target_id: Int,
  id: fn(a) -> Int,
) -> Remote(List(a)) {
  map_loaded(remote, fn(items) {
    list.filter(items, fn(item) { id(item) != target_id })
  })
}

fn map_loaded(
  remote: Remote(List(a)),
  f: fn(List(a)) -> List(a),
) -> Remote(List(a)) {
  case remote {
    Loaded(items) -> Loaded(f(items))
    other -> other
  }
}
