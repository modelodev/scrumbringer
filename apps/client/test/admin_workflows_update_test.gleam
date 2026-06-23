import gleam/option as opt
import lustre/effect

import domain/api_error.{ApiError}
import domain/automation
import domain/remote.{type Remote, Failed, Loaded, Loading, NotAsked}
import domain/workflow.{type Rule, type Workflow, Rule, Workflow}
import scrumbringer_client/api/workflows/rule_metrics as api_rule_metrics
import scrumbringer_client/client_state
import scrumbringer_client/client_state/admin/rules as admin_rules
import scrumbringer_client/client_state/admin/workflows as admin_workflows
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/admin/workflows as workflows_update
import scrumbringer_client/features/pool/msg as pool_messages

fn workflow(id: Int, name: String, project_id: opt.Option(Int)) -> Workflow {
  Workflow(
    id: id,
    org_id: 1,
    project_id: project_id,
    name: name,
    description: opt.None,
    active: True,
    rule_count: 1,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
  )
}

fn rule(id: Int, name: String) -> Rule {
  Rule(
    id: id,
    workflow_id: 3,
    name: name,
    goal: opt.None,
    trigger: automation.TaskCompleted(opt.None),
    action: opt.None,
    status: automation.RequiresReview(automation.TemplateMissing),
    created_at: "2026-01-01T00:00:00Z",
    template: opt.None,
  )
}

fn rule_with_trigger(
  id: Int,
  name: String,
  trigger: automation.AutomationTrigger,
) -> Rule {
  Rule(..rule(id, name), trigger: trigger)
}

fn workflow_metrics(workflow_id: Int) -> api_rule_metrics.WorkflowMetrics {
  api_rule_metrics.WorkflowMetrics(
    workflow_id: workflow_id,
    workflow_name: "Delivery",
    rules: [],
  )
}

fn workflow_feedback_context() -> workflows_update.WorkflowFeedbackContext(
  client_state.Msg,
) {
  workflows_update.WorkflowFeedbackContext(
    workflow_created: "Workflow created",
    workflow_updated: "Workflow updated",
    workflow_deleted: "Workflow deleted",
    on_success_toast: fn(_message) { effect.from(fn(_dispatch) { Nil }) },
    on_workflow_saved: fn(result) {
      client_state.pool_msg(pool_messages.WorkflowSaved(result))
    },
    on_workflow_deleted: fn(workflow_id, result) {
      client_state.pool_msg(pool_messages.WorkflowDeleteFinished(
        workflow_id,
        result,
      ))
    },
  )
}

fn rule_feedback_context() -> workflows_update.RuleFeedbackContext(
  client_state.Msg,
) {
  workflows_update.RuleFeedbackContext(
    rule_created: "Rule created",
    rule_updated: "Rule updated",
    rule_deleted: "Rule deleted",
    on_success_toast: fn(_message) { effect.from(fn(_dispatch) { Nil }) },
    on_rule_saved: fn(result) {
      client_state.pool_msg(pool_messages.RuleSaved(result))
    },
    on_rule_deleted: fn(rule_id, result) {
      client_state.pool_msg(pool_messages.RuleDeleteFinished(rule_id, result))
    },
  )
}

fn rules_context(
  selected_project_id: opt.Option(Int),
) -> workflows_update.RulesContext(client_state.Msg) {
  workflows_update.RulesContext(
    selected_project_id: selected_project_id,
    on_rules_fetched: fn(result) {
      client_state.pool_msg(pool_messages.RulesFetched(result))
    },
    on_rule_metrics_fetched: fn(result) {
      client_state.pool_msg(pool_messages.RuleMetricsFetched(result))
    },
    on_task_types_fetched: fn(result) {
      client_state.admin_msg(admin_messages.TaskTypesFetched(result))
    },
  )
}

fn workflows_state(
  org: Remote(List(Workflow)),
  project: Remote(List(Workflow)),
) -> admin_workflows.Model {
  admin_workflows.Model(
    workflows_org: org,
    workflows_project: project,
    workflows_search: "",
    workflows_status_filter: "all",
    workflows_dialog_mode: opt.Some(admin_workflows.WorkflowDialogCreate),
    workflow_form_name: "",
    workflow_form_description: "",
    workflow_form_active: True,
    workflow_form_submitting: False,
    workflow_form_error: opt.None,
  )
}

fn workflow_update(
  state: admin_workflows.Model,
  msg: pool_messages.Msg,
) -> #(
  admin_workflows.Model,
  effect.Effect(client_state.Msg),
  workflows_update.WorkflowAuthPolicy,
) {
  let assert opt.Some(workflows_update.WorkflowUpdate(next, fx, auth_policy)) =
    workflows_update.try_workflows_update(
      state,
      msg,
      workflow_feedback_context(),
    )

  #(next, fx, auth_policy)
}

fn rules_update(
  state: admin_rules.Model,
  msg: pool_messages.Msg,
  selected_project_id: opt.Option(Int),
) -> #(
  admin_rules.Model,
  effect.Effect(client_state.Msg),
  workflows_update.RulesAuthPolicy,
) {
  let assert opt.Some(workflows_update.RulesUpdate(next, fx, auth_policy)) =
    workflows_update.try_rules_update(
      state,
      msg,
      rules_context(selected_project_id),
      rule_feedback_context(),
    )

  #(next, fx, auth_policy)
}

pub fn local_workflow_crud_transitions_update_scopes_test() {
  let existing = workflow(1, "Existing", opt.Some(7))
  let created = workflow(2, "Created", opt.Some(7))
  let updated = workflow(2, "Updated", opt.Some(7))
  let state = workflows_state(Loaded([]), Loaded([existing]))

  let #(after_create, fx, auth_policy) =
    workflow_update(state, pool_messages.WorkflowSaved(Ok(created)))
  let assert True =
    after_create.workflows_project == Loaded([created, existing])
  let assert opt.None = after_create.workflows_dialog_mode
  let assert True = fx != effect.none()
  let assert workflows_update.NoWorkflowAuthCheck = auth_policy

  let #(editing, fx, auth_policy) =
    workflow_update(
      after_create,
      pool_messages.OpenWorkflowDialog(admin_workflows.WorkflowDialogEdit(
        created,
      )),
    )
  let assert True = fx == effect.none()
  let assert workflows_update.NoWorkflowAuthCheck = auth_policy

  let #(after_update, fx, auth_policy) =
    workflow_update(editing, pool_messages.WorkflowSaved(Ok(updated)))
  let assert True =
    after_update.workflows_project == Loaded([updated, existing])
  let assert True = fx != effect.none()
  let assert workflows_update.NoWorkflowAuthCheck = auth_policy

  let #(deleting, fx, auth_policy) =
    workflow_update(
      after_update,
      pool_messages.OpenWorkflowDialog(admin_workflows.WorkflowDialogDelete(
        updated,
      )),
    )
  let assert True = fx == effect.none()
  let assert workflows_update.NoWorkflowAuthCheck = auth_policy

  let #(after_delete, fx, auth_policy) =
    workflow_update(deleting, pool_messages.WorkflowDeleteFinished(2, Ok(Nil)))
  let assert True = after_delete.workflows_project == Loaded([existing])
  let assert True = fx != effect.none()
  let assert workflows_update.NoWorkflowAuthCheck = auth_policy
}

pub fn local_workflow_fetch_and_dialog_transitions_test() {
  let loaded = [workflow(1, "Loaded", opt.Some(7))]
  let state = workflows_state(Loaded([]), Loaded([]))

  let #(after_fetch, fx, auth_policy) =
    workflow_update(state, pool_messages.WorkflowsProjectFetched(Ok(loaded)))
  let assert True = after_fetch.workflows_project == Loaded(loaded)
  let assert True = fx == effect.none()
  let assert workflows_update.NoWorkflowAuthCheck = auth_policy

  let err = ApiError(status: 500, code: "ERROR", message: "Backend failed")
  let #(after_error, fx, auth_policy) =
    workflow_update(
      after_fetch,
      pool_messages.WorkflowsProjectFetched(Error(err)),
    )
  let assert True = after_error.workflows_project == Failed(err)
  let assert True = fx == effect.none()
  let assert workflows_update.CheckWorkflowAuth(auth_err) = auth_policy
  let assert True = auth_err == err

  let item = workflow(2, "Edit", opt.Some(7))
  let #(opened, fx, auth_policy) =
    workflow_update(
      after_error,
      pool_messages.OpenWorkflowDialog(admin_workflows.WorkflowDialogEdit(item)),
    )
  let assert True =
    opened.workflows_dialog_mode
    == opt.Some(admin_workflows.WorkflowDialogEdit(item))
  let assert True = fx == effect.none()
  let assert workflows_update.NoWorkflowAuthCheck = auth_policy

  let #(closed, fx, auth_policy) =
    workflow_update(opened, pool_messages.CloseWorkflowDialog)
  let assert opt.None = closed.workflows_dialog_mode
  let assert True = fx == effect.none()
  let assert workflows_update.NoWorkflowAuthCheck = auth_policy
}

pub fn try_workflows_update_fetch_error_requests_auth_check_test() {
  let err = ApiError(status: 500, code: "ERROR", message: "Backend failed")

  let assert opt.Some(workflows_update.WorkflowUpdate(next, fx, auth_policy)) =
    workflows_update.try_workflows_update(
      admin_workflows.default_model(),
      pool_messages.WorkflowsProjectFetched(Error(err)),
      workflow_feedback_context(),
    )
  let assert workflows_update.CheckWorkflowAuth(auth_err) = auth_policy

  let assert True = auth_err == err
  let assert True = next.workflows_project == Failed(err)
  let assert True = fx == effect.none()
}

pub fn try_workflows_update_open_dialog_returns_local_update_test() {
  let item = workflow(2, "Edit", opt.Some(7))

  let assert opt.Some(workflows_update.WorkflowUpdate(next, fx, auth_policy)) =
    workflows_update.try_workflows_update(
      admin_workflows.default_model(),
      pool_messages.OpenWorkflowDialog(admin_workflows.WorkflowDialogEdit(item)),
      workflow_feedback_context(),
    )

  let assert True =
    next.workflows_dialog_mode
    == opt.Some(admin_workflows.WorkflowDialogEdit(item))
  let assert True = fx == effect.none()
  let assert workflows_update.NoWorkflowAuthCheck = auth_policy
}

pub fn try_workflows_update_crud_created_returns_feedback_effect_test() {
  let existing = workflow(1, "Existing", opt.Some(7))
  let created = workflow(2, "Created", opt.Some(7))
  let state = workflows_state(Loaded([]), Loaded([existing]))

  let assert opt.Some(workflows_update.WorkflowUpdate(next, fx, auth_policy)) =
    workflows_update.try_workflows_update(
      state,
      pool_messages.WorkflowSaved(Ok(created)),
      workflow_feedback_context(),
    )

  let assert True = next.workflows_project == Loaded([created, existing])
  let assert opt.None = next.workflows_dialog_mode
  let assert True = fx != effect.none()
  let assert workflows_update.NoWorkflowAuthCheck = auth_policy
}

pub fn try_workflows_update_search_change_is_local_test() {
  let #(next, fx, auth_policy) =
    workflow_update(
      admin_workflows.default_model(),
      pool_messages.WorkflowsSearchChanged("release"),
    )

  let assert "release" = next.workflows_search
  let assert True = fx == effect.none()
  let assert workflows_update.NoWorkflowAuthCheck = auth_policy
}

pub fn try_workflows_update_status_filter_change_is_local_test() {
  let #(next, fx, auth_policy) =
    workflow_update(
      admin_workflows.default_model(),
      pool_messages.WorkflowsStatusFilterChanged("paused"),
    )

  let assert "paused" = next.workflows_status_filter
  let assert True = fx == effect.none()
  let assert workflows_update.NoWorkflowAuthCheck = auth_policy
}

pub fn try_workflows_update_ignores_non_workflow_messages_test() {
  let assert opt.None =
    workflows_update.try_workflows_update(
      admin_workflows.default_model(),
      pool_messages.MemberPoolVisibilityChanged("all-open"),
      workflow_feedback_context(),
    )
}

pub fn local_rule_form_transitions_update_loaded_rules_test() {
  let existing = rule(1, "Existing")
  let created = rule(2, "Created")
  let updated = rule(2, "Updated")
  let state =
    admin_rules.Model(
      ..admin_rules.default_model(),
      rules: Loaded([existing]),
      rules_workflow_id: opt.Some(3),
    )

  let #(create_opened, fx, auth_policy) =
    rules_update(
      state,
      pool_messages.OpenRuleDialog(admin_rules.RuleDialogCreate),
      opt.None,
    )
  let assert opt.Some(admin_rules.RuleDialogCreate) =
    create_opened.rules_dialog_mode
  let assert "" = create_opened.rule_form_name
  let assert "task_completed" = create_opened.rule_form_event
  let assert "" = create_opened.rule_form_template_search
  let assert True = fx == effect.none()
  let assert workflows_update.NoRulesAuthCheck = auth_policy

  let #(after_create, fx, auth_policy) =
    rules_update(create_opened, pool_messages.RuleSaved(Ok(created)), opt.None)
  let assert True = after_create.rules == Loaded([created, existing])
  let assert opt.None = after_create.rules_dialog_mode
  let assert True = fx != effect.none()
  let assert workflows_update.NoRulesAuthCheck = auth_policy

  let #(edit_opened, fx, auth_policy) =
    rules_update(
      after_create,
      pool_messages.OpenRuleDialog(admin_rules.RuleDialogEdit(created)),
      opt.None,
    )
  let assert "Created" = edit_opened.rule_form_name
  let assert "task_completed" = edit_opened.rule_form_event
  let assert "" = edit_opened.rule_form_template_search
  let assert True = fx == effect.none()
  let assert workflows_update.NoRulesAuthCheck = auth_policy

  let #(after_update, fx, auth_policy) =
    rules_update(edit_opened, pool_messages.RuleSaved(Ok(updated)), opt.None)
  let assert True = after_update.rules == Loaded([updated, existing])
  let assert True = fx != effect.none()
  let assert workflows_update.NoRulesAuthCheck = auth_policy

  let #(delete_opened, fx, auth_policy) =
    rules_update(
      after_update,
      pool_messages.OpenRuleDialog(admin_rules.RuleDialogDelete(updated)),
      opt.None,
    )
  let assert opt.Some(admin_rules.RuleDialogDelete(_updated)) =
    delete_opened.rules_dialog_mode
  let assert True = fx == effect.none()
  let assert workflows_update.NoRulesAuthCheck = auth_policy

  let #(after_delete, fx, auth_policy) =
    rules_update(
      delete_opened,
      pool_messages.RuleDeleteFinished(2, Ok(Nil)),
      opt.None,
    )
  let assert True = after_delete.rules == Loaded([existing])
  let assert True = fx != effect.none()
  let assert workflows_update.NoRulesAuthCheck = auth_policy
}

pub fn local_rule_fetch_navigation_and_dialog_transitions_test() {
  let rules = [rule(1, "Rule")]
  let metrics = workflow_metrics(3)
  let err = ApiError(status: 409, code: "CONFLICT", message: "Conflict")
  let state = admin_rules.default_model()

  let #(opened, fx, auth_policy) =
    rules_update(state, pool_messages.WorkflowRulesClicked(3), opt.None)
  let assert opt.Some(3) = opened.rules_workflow_id
  let assert Loading = opened.rules
  let assert Loading = opened.rules_metrics
  let assert True = fx != effect.none()
  let assert workflows_update.NoRulesAuthCheck = auth_policy

  let #(rules_loaded, fx, auth_policy) =
    rules_update(opened, pool_messages.RulesFetched(Ok(rules)), opt.None)
  let assert True = rules_loaded.rules == Loaded(rules)
  let assert True = fx == effect.none()
  let assert workflows_update.NoRulesAuthCheck = auth_policy

  let #(rules_failed, fx, auth_policy) =
    rules_update(rules_loaded, pool_messages.RulesFetched(Error(err)), opt.None)
  let assert True = rules_failed.rules == Failed(err)
  let assert True = fx == effect.none()
  let assert workflows_update.CheckRulesAuth(auth_err) = auth_policy
  let assert True = auth_err == err

  let metrics_loaded =
    rules_update(
      rules_failed,
      pool_messages.RuleMetricsFetched(Ok(metrics)),
      opt.None,
    )
  let #(metrics_loaded, fx, auth_policy) = metrics_loaded
  let assert True = metrics_loaded.rules_metrics == Loaded(metrics)
  let assert True = fx == effect.none()
  let assert workflows_update.NoRulesAuthCheck = auth_policy

  let metrics_failed =
    rules_update(
      metrics_loaded,
      pool_messages.RuleMetricsFetched(Error(err)),
      opt.None,
    )
  let #(metrics_failed, fx, auth_policy) = metrics_failed
  let assert True = metrics_failed.rules_metrics == Failed(err)
  let assert True = fx == effect.none()
  let assert workflows_update.CheckRulesAuth(auth_err) = auth_policy
  let assert True = auth_err == err

  let #(dialog_opened, fx, auth_policy) =
    rules_update(
      metrics_failed,
      pool_messages.OpenRuleDialog(admin_rules.RuleDialogCreate),
      opt.None,
    )
  let assert opt.Some(admin_rules.RuleDialogCreate) =
    dialog_opened.rules_dialog_mode
  let assert True = fx == effect.none()
  let assert workflows_update.NoRulesAuthCheck = auth_policy

  let #(dialog_closed, fx, auth_policy) =
    rules_update(dialog_opened, pool_messages.CloseRuleDialog, opt.None)
  let assert opt.None = dialog_closed.rules_dialog_mode
  let assert True = fx == effect.none()
  let assert workflows_update.NoRulesAuthCheck = auth_policy

  let #(back, fx, auth_policy) =
    rules_update(dialog_closed, pool_messages.RulesBackClicked, opt.None)
  let assert opt.None = back.rules_workflow_id
  let assert NotAsked = back.rules
  let assert NotAsked = back.rules_metrics
  let assert True = fx == effect.none()
  let assert workflows_update.NoRulesAuthCheck = auth_policy
}

pub fn try_rules_update_workflow_rules_clicked_returns_loading_and_effects_test() {
  let assert opt.Some(workflows_update.RulesUpdate(next, fx, auth_policy)) =
    workflows_update.try_rules_update(
      admin_rules.default_model(),
      pool_messages.WorkflowRulesClicked(3),
      rules_context(opt.Some(7)),
      rule_feedback_context(),
    )

  let assert opt.Some(3) = next.rules_workflow_id
  let assert Loading = next.rules
  let assert Loading = next.rules_metrics
  let assert True = fx != effect.none()
  let assert workflows_update.NoRulesAuthCheck = auth_policy
}

pub fn try_rules_update_rules_error_requests_auth_check_test() {
  let err = ApiError(status: 401, code: "UNAUTHORIZED", message: "Unauthorized")

  let assert opt.Some(workflows_update.RulesUpdate(next, fx, auth_policy)) =
    workflows_update.try_rules_update(
      admin_rules.default_model(),
      pool_messages.RulesFetched(Error(err)),
      rules_context(opt.None),
      rule_feedback_context(),
    )

  let assert True = next.rules == Failed(err)
  let assert True = fx == effect.none()
  let assert workflows_update.CheckRulesAuth(auth_err) = auth_policy
  let assert True = auth_err == err
}

pub fn try_rules_update_rule_metrics_success_updates_loaded_metrics_test() {
  let metrics = workflow_metrics(3)

  let assert opt.Some(workflows_update.RulesUpdate(next, fx, auth_policy)) =
    workflows_update.try_rules_update(
      admin_rules.default_model(),
      pool_messages.RuleMetricsFetched(Ok(metrics)),
      rules_context(opt.None),
      rule_feedback_context(),
    )

  let assert True = next.rules_metrics == Loaded(metrics)
  let assert True = fx == effect.none()
  let assert workflows_update.NoRulesAuthCheck = auth_policy
}

pub fn try_rules_update_open_dialog_returns_local_update_test() {
  let assert opt.Some(workflows_update.RulesUpdate(next, fx, auth_policy)) =
    workflows_update.try_rules_update(
      admin_rules.default_model(),
      pool_messages.OpenRuleDialog(admin_rules.RuleDialogCreate),
      rules_context(opt.None),
      rule_feedback_context(),
    )

  let assert opt.Some(admin_rules.RuleDialogCreate) = next.rules_dialog_mode
  let assert True = fx == effect.none()
  let assert workflows_update.NoRulesAuthCheck = auth_policy
}

pub fn try_rules_update_rule_card_scope_change_is_local_test() {
  let assert opt.Some(workflows_update.RulesUpdate(next, fx, auth_policy)) =
    workflows_update.try_rules_update(
      admin_rules.default_model(),
      pool_messages.RuleCardScopeChanged("2"),
      rules_context(opt.None),
      rule_feedback_context(),
    )

  let assert "2" = next.rule_form_card_scope
  let assert True = fx == effect.none()
  let assert workflows_update.NoRulesAuthCheck = auth_policy
}

pub fn try_rules_update_open_card_depth_rule_preserves_scope_test() {
  let assert Ok(depth) = automation.card_depth_from_int(2)
  let card_rule =
    rule_with_trigger(
      7,
      "Depth close review",
      automation.CardClosed(automation.AtDepth(depth)),
    )

  let assert opt.Some(workflows_update.RulesUpdate(next, fx, auth_policy)) =
    workflows_update.try_rules_update(
      admin_rules.default_model(),
      pool_messages.OpenRuleDialog(admin_rules.RuleDialogEdit(card_rule)),
      rules_context(opt.None),
      rule_feedback_context(),
    )

  let assert "card" = next.rule_form_subject
  let assert "card_closed" = next.rule_form_event
  let assert "2" = next.rule_form_card_scope
  let assert True = fx == effect.none()
  let assert workflows_update.NoRulesAuthCheck = auth_policy
}

pub fn try_rules_update_invalid_card_depth_blocks_submit_test() {
  let state =
    admin_rules.Model(
      ..admin_rules.default_model(),
      rules_dialog_mode: opt.Some(admin_rules.RuleDialogCreate),
      rules_workflow_id: opt.Some(3),
      rule_form_name: "Bad card scope",
      rule_form_subject: "card",
      rule_form_event: "card_activated",
      rule_form_card_scope: "0",
      rule_form_template_id: "12",
    )

  let assert opt.Some(workflows_update.RulesUpdate(next, fx, auth_policy)) =
    workflows_update.try_rules_update(
      state,
      pool_messages.RuleFormSubmitted,
      rules_context(opt.None),
      rule_feedback_context(),
    )

  let assert opt.Some("Choose a valid card level") = next.rule_form_error
  let assert False = next.rule_form_submitting
  let assert True = fx == effect.none()
  let assert workflows_update.NoRulesAuthCheck = auth_policy
}

pub fn try_rules_update_template_search_changed_updates_rule_form_test() {
  let state =
    admin_rules.Model(
      ..admin_rules.default_model(),
      rules_dialog_mode: opt.Some(admin_rules.RuleDialogCreate),
    )

  let assert opt.Some(workflows_update.RulesUpdate(next, fx, auth_policy)) =
    workflows_update.try_rules_update(
      state,
      pool_messages.RuleTemplateSearchChanged("Follow"),
      rules_context(opt.None),
      rule_feedback_context(),
    )

  let assert "Follow" = next.rule_form_template_search
  let assert True = fx == effect.none()
  let assert workflows_update.NoRulesAuthCheck = auth_policy
}

pub fn try_rules_update_ignores_non_rule_messages_test() {
  let assert opt.None =
    workflows_update.try_rules_update(
      admin_rules.default_model(),
      pool_messages.MemberPoolVisibilityChanged("all-open"),
      rules_context(opt.None),
      rule_feedback_context(),
    )
}

pub fn try_rules_update_rule_saved_updates_rules_and_emits_feedback_test() {
  let existing = rule(1, "Existing")
  let created = rule(2, "Created")
  let state =
    admin_rules.Model(
      ..admin_rules.default_model(),
      rules: Loaded([existing]),
      rules_dialog_mode: opt.Some(admin_rules.RuleDialogCreate),
    )

  let assert opt.Some(workflows_update.RulesUpdate(next, fx, auth_policy)) =
    workflows_update.try_rules_update(
      state,
      pool_messages.RuleSaved(Ok(created)),
      rules_context(opt.None),
      rule_feedback_context(),
    )

  let assert True = next.rules == Loaded([created, existing])
  let assert opt.None = next.rules_dialog_mode
  let assert True = fx != effect.none()
  let assert workflows_update.NoRulesAuthCheck = auth_policy
}

pub fn try_workflows_update_created_updates_project_scope_and_emits_feedback_test() {
  let existing = workflow(1, "Existing", opt.Some(7))
  let created = workflow(2, "Created", opt.Some(7))
  let workflows =
    admin_workflows.Model(
      workflows_org: Loaded([]),
      workflows_project: Loaded([existing]),
      workflows_search: "",
      workflows_status_filter: "all",
      workflows_dialog_mode: opt.Some(admin_workflows.WorkflowDialogCreate),
      workflow_form_name: "",
      workflow_form_description: "",
      workflow_form_active: True,
      workflow_form_submitting: False,
      workflow_form_error: opt.None,
    )

  let #(next, fx, auth_policy) =
    workflow_update(workflows, pool_messages.WorkflowSaved(Ok(created)))

  let assert True = next.workflows_project == Loaded([created, existing])
  let assert True = next.workflows_org == Loaded([])
  let assert opt.None = next.workflows_dialog_mode
  let assert True = fx != effect.none()
  let assert workflows_update.NoWorkflowAuthCheck = auth_policy
}

pub fn try_rules_update_updated_replaces_loaded_rule_and_emits_feedback_test() {
  let old = rule(1, "Old")
  let updated = rule(1, "Updated")
  let other = rule(2, "Other")
  let rules =
    admin_rules.Model(
      ..admin_rules.default_model(),
      rules: Loaded([old, other]),
      rules_dialog_mode: opt.Some(admin_rules.RuleDialogEdit(old)),
    )

  let #(next, fx, auth_policy) =
    rules_update(rules, pool_messages.RuleSaved(Ok(updated)), opt.None)

  let assert True = next.rules == Loaded([updated, other])
  let assert opt.None = next.rules_dialog_mode
  let assert True = fx != effect.none()
  let assert workflows_update.NoRulesAuthCheck = auth_policy
}
