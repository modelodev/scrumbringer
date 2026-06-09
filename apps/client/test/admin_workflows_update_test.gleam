import gleam/option as opt
import gleam/set
import lustre/effect

import domain/api_error.{ApiError}
import domain/remote.{type Remote, Failed, Loaded, Loading, NotAsked}
import domain/task_status
import domain/workflow.{
  type Rule, type RuleTemplate, type Workflow, Rule, RuleTemplate, TaskRule,
  Workflow,
}
import scrumbringer_client/api/workflows as api_workflows
import scrumbringer_client/client_state
import scrumbringer_client/client_state/admin/rules as admin_rules
import scrumbringer_client/client_state/admin/task_templates as admin_task_templates
import scrumbringer_client/client_state/admin/workflows as admin_workflows
import scrumbringer_client/client_state/types as state_types
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

fn rule(id: Int, name: String, templates: List(RuleTemplate)) -> Rule {
  Rule(
    id: id,
    workflow_id: 3,
    name: name,
    goal: opt.None,
    target: TaskRule(task_status.Completed, opt.None),
    active: True,
    created_at: "2026-01-01T00:00:00Z",
    templates: templates,
  )
}

fn rule_template(id: Int, name: String) -> RuleTemplate {
  RuleTemplate(
    id: id,
    org_id: 1,
    project_id: opt.Some(7),
    name: name,
    description: opt.None,
    type_id: 2,
    type_name: "Bug",
    priority: 3,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    execution_order: 1,
  )
}

fn workflow_metrics(workflow_id: Int) -> api_workflows.WorkflowMetrics {
  api_workflows.WorkflowMetrics(
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

fn template_feedback_context() -> workflows_update.TemplateAttachmentFeedbackContext(
  client_state.Msg,
) {
  workflows_update.TemplateAttachmentFeedbackContext(
    template_attached: "Template attached",
    template_detached: "Template detached",
    on_success_toast: fn(_message) { effect.from(fn(_dispatch) { Nil }) },
    on_error_toast: fn(_message) { effect.from(fn(_dispatch) { Nil }) },
  )
}

fn template_attachment_context(
  selected_project_id: opt.Option(Int),
) -> workflows_update.TemplateAttachmentContext(client_state.Msg) {
  workflows_update.TemplateAttachmentContext(
    selected_project_id: selected_project_id,
    on_task_templates_fetched: fn(result) {
      client_state.pool_msg(pool_messages.TaskTemplatesProjectFetched(result))
    },
    on_attach_template_succeeded: fn(rule_id, templates) {
      client_state.pool_msg(pool_messages.AttachTemplateSucceeded(
        rule_id,
        templates,
      ))
    },
    on_attach_template_failed: fn(err) {
      client_state.pool_msg(pool_messages.AttachTemplateFailed(err))
    },
    on_template_detach_succeeded: fn(rule_id, template_id) {
      client_state.pool_msg(pool_messages.TemplateDetachSucceeded(
        rule_id,
        template_id,
      ))
    },
    on_template_detach_failed: fn(rule_id, template_id, err) {
      client_state.pool_msg(pool_messages.TemplateDetachFailed(
        rule_id,
        template_id,
        err,
      ))
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
    workflows_dialog_mode: opt.Some(state_types.WorkflowDialogCreate),
  )
}

pub fn local_workflow_crud_transitions_update_scopes_test() {
  let existing = workflow(1, "Existing", opt.Some(7))
  let created = workflow(2, "Created", opt.Some(7))
  let updated = workflow(2, "Updated", opt.Some(7))
  let state = workflows_state(Loaded([]), Loaded([existing]))

  let after_create = workflows_update.workflow_created(state, created)
  let assert True =
    after_create.workflows_project == Loaded([created, existing])
  let assert opt.None = after_create.workflows_dialog_mode

  let after_update = workflows_update.workflow_updated(after_create, updated)
  let assert True =
    after_update.workflows_project == Loaded([updated, existing])

  let after_delete = workflows_update.workflow_deleted(after_update, 2)
  let assert True = after_delete.workflows_project == Loaded([existing])
}

pub fn local_workflow_fetch_and_dialog_transitions_test() {
  let loaded = [workflow(1, "Loaded", opt.Some(7))]
  let state = workflows_state(Loaded([]), Loaded([]))

  let after_fetch = workflows_update.workflows_project_fetched_ok(state, loaded)
  let assert True = after_fetch.workflows_project == Loaded(loaded)

  let err = ApiError(status: 500, code: "ERROR", message: "Backend failed")
  let after_error =
    workflows_update.workflows_project_fetched_error(after_fetch, err)
  let assert True = after_error.workflows_project == Failed(err)

  let item = workflow(2, "Edit", opt.Some(7))
  let opened =
    workflows_update.open_workflow_dialog(
      after_error,
      state_types.WorkflowDialogEdit(item),
    )
  let assert True =
    opened.workflows_dialog_mode
    == opt.Some(state_types.WorkflowDialogEdit(item))

  let closed = workflows_update.close_workflow_dialog(opened)
  let assert opt.None = closed.workflows_dialog_mode
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
      pool_messages.OpenWorkflowDialog(state_types.WorkflowDialogEdit(item)),
      workflow_feedback_context(),
    )

  let assert True =
    next.workflows_dialog_mode == opt.Some(state_types.WorkflowDialogEdit(item))
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
      pool_messages.WorkflowCrudCreated(created),
      workflow_feedback_context(),
    )

  let assert True = next.workflows_project == Loaded([created, existing])
  let assert opt.None = next.workflows_dialog_mode
  let assert True = fx != effect.none()
  let assert workflows_update.NoWorkflowAuthCheck = auth_policy
}

pub fn try_workflows_update_ignores_non_workflow_messages_test() {
  let assert opt.None =
    workflows_update.try_workflows_update(
      admin_workflows.default_model(),
      pool_messages.MemberPoolFiltersToggled,
      workflow_feedback_context(),
    )
}

pub fn local_rule_crud_transitions_update_loaded_rules_test() {
  let existing = rule(1, "Existing", [])
  let created = rule(2, "Created", [])
  let updated = rule(2, "Updated", [])
  let state =
    admin_rules.Model(
      ..admin_rules.default_model(),
      rules: Loaded([existing]),
      rules_dialog_mode: opt.Some(state_types.RuleDialogCreate),
    )

  let after_create = workflows_update.rule_created(state, created)
  let assert True = after_create.rules == Loaded([created, existing])
  let assert opt.None = after_create.rules_dialog_mode

  let after_update = workflows_update.rule_updated(after_create, updated)
  let assert True = after_update.rules == Loaded([updated, existing])

  let after_delete = workflows_update.rule_deleted(after_update, 2)
  let assert True = after_delete.rules == Loaded([existing])
}

pub fn local_rule_fetch_navigation_and_dialog_transitions_test() {
  let rules = [rule(1, "Rule", [])]
  let metrics = workflow_metrics(3)
  let err = ApiError(status: 409, code: "CONFLICT", message: "Conflict")
  let state = admin_rules.default_model()

  let opened = workflows_update.workflow_rules_opened(state, 3)
  let assert opt.Some(3) = opened.rules_workflow_id
  let assert Loading = opened.rules
  let assert Loading = opened.rules_metrics

  let rules_loaded = workflows_update.rules_fetched_ok(opened, rules)
  let assert True = rules_loaded.rules == Loaded(rules)

  let rules_failed = workflows_update.rules_fetched_error(rules_loaded, err)
  let assert True = rules_failed.rules == Failed(err)

  let metrics_loaded =
    workflows_update.rule_metrics_fetched_ok(rules_failed, metrics)
  let assert True = metrics_loaded.rules_metrics == Loaded(metrics)

  let metrics_failed =
    workflows_update.rule_metrics_fetched_error(metrics_loaded, err)
  let assert True = metrics_failed.rules_metrics == Failed(err)

  let dialog_opened =
    workflows_update.open_rule_dialog(
      metrics_failed,
      state_types.RuleDialogCreate,
    )
  let assert opt.Some(state_types.RuleDialogCreate) =
    dialog_opened.rules_dialog_mode

  let dialog_closed = workflows_update.close_rule_dialog(dialog_opened)
  let assert opt.None = dialog_closed.rules_dialog_mode

  let back = workflows_update.rules_back_clicked(dialog_closed)
  let assert opt.None = back.rules_workflow_id
  let assert NotAsked = back.rules
  let assert NotAsked = back.rules_metrics
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
      pool_messages.OpenRuleDialog(state_types.RuleDialogCreate),
      rules_context(opt.None),
      rule_feedback_context(),
    )

  let assert opt.Some(state_types.RuleDialogCreate) = next.rules_dialog_mode
  let assert True = fx == effect.none()
  let assert workflows_update.NoRulesAuthCheck = auth_policy
}

pub fn try_rules_update_ignores_non_rule_messages_test() {
  let assert opt.None =
    workflows_update.try_rules_update(
      admin_rules.default_model(),
      pool_messages.MemberPoolFiltersToggled,
      rules_context(opt.None),
      rule_feedback_context(),
    )
}

pub fn try_rules_update_rule_crud_created_updates_rules_and_emits_feedback_test() {
  let existing = rule(1, "Existing", [])
  let created = rule(2, "Created", [])
  let state =
    admin_rules.Model(
      ..admin_rules.default_model(),
      rules: Loaded([existing]),
      rules_dialog_mode: opt.Some(state_types.RuleDialogCreate),
    )

  let assert opt.Some(workflows_update.RulesUpdate(next, fx, auth_policy)) =
    workflows_update.try_rules_update(
      state,
      pool_messages.RuleCrudCreated(created),
      rules_context(opt.None),
      rule_feedback_context(),
    )

  let assert True = next.rules == Loaded([created, existing])
  let assert opt.None = next.rules_dialog_mode
  let assert True = fx != effect.none()
  let assert workflows_update.NoRulesAuthCheck = auth_policy
}

pub fn local_template_attachment_transitions_update_rules_test() {
  let template_a = rule_template(10, "Template A")
  let template_b = rule_template(11, "Template B")
  let detaching = set.insert(set.new(), #(1, 10))
  let state =
    admin_rules.Model(
      ..admin_rules.default_model(),
      rules: Loaded([rule(1, "Rule", [template_a])]),
      attach_template_modal: opt.Some(1),
      attach_template_selected: opt.Some(11),
      attach_template_loading: True,
      detaching_templates: detaching,
    )

  let after_attach =
    workflows_update.attach_template_succeeded(state, 1, [
      template_a,
      template_b,
    ])
  let assert Loaded([attached_rule]) = after_attach.rules
  let assert True = attached_rule.templates == [template_a, template_b]
  let assert opt.None = after_attach.attach_template_modal
  let assert opt.None = after_attach.attach_template_selected
  let assert False = after_attach.attach_template_loading

  let after_detach =
    workflows_update.template_detach_succeeded(after_attach, 1, 10)
  let assert Loaded([detached_rule]) = after_detach.rules
  let assert True = detached_rule.templates == [template_b]
  let assert False = set.contains(after_detach.detaching_templates, #(1, 10))
}

pub fn try_template_attachment_update_modal_open_sets_loading_and_effect_test() {
  let local =
    workflows_update.TemplateAttachmentModel(
      rules: admin_rules.default_model(),
      task_templates: admin_task_templates.default_model(),
    )

  let assert opt.Some(workflows_update.TemplateAttachmentUpdate(
    next,
    fx,
    auth_policy,
  )) =
    workflows_update.try_template_attachment_update(
      local,
      pool_messages.AttachTemplateModalOpened(1),
      template_attachment_context(opt.Some(7)),
      template_feedback_context(),
    )
  let workflows_update.TemplateAttachmentModel(
    rules: rules,
    task_templates: task_templates,
  ) = next

  let assert opt.Some(1) = rules.attach_template_modal
  let assert opt.None = rules.attach_template_selected
  let assert False = rules.attach_template_loading
  let assert Loading = task_templates.task_templates_project
  let assert True = fx != effect.none()
  let assert workflows_update.NoTemplateAttachmentAuthCheck = auth_policy
}

pub fn try_template_attachment_update_submit_sets_loading_and_effect_test() {
  let template = rule_template(10, "Template")
  let rules =
    admin_rules.Model(
      ..admin_rules.default_model(),
      rules: Loaded([rule(1, "Rule", [template])]),
      attach_template_modal: opt.Some(1),
      attach_template_selected: opt.Some(11),
    )
  let local =
    workflows_update.TemplateAttachmentModel(
      rules: rules,
      task_templates: admin_task_templates.default_model(),
    )

  let assert opt.Some(workflows_update.TemplateAttachmentUpdate(
    next,
    fx,
    auth_policy,
  )) =
    workflows_update.try_template_attachment_update(
      local,
      pool_messages.AttachTemplateSubmitted,
      template_attachment_context(opt.None),
      template_feedback_context(),
    )
  let workflows_update.TemplateAttachmentModel(rules: next_rules, ..) = next

  let assert True = next_rules.attach_template_loading
  let assert True = fx != effect.none()
  let assert workflows_update.NoTemplateAttachmentAuthCheck = auth_policy
}

pub fn try_template_attachment_update_failed_requests_auth_check_test() {
  let err = ApiError(status: 401, code: "UNAUTHORIZED", message: "Unauthorized")
  let rules =
    admin_rules.Model(
      ..admin_rules.default_model(),
      attach_template_loading: True,
    )
  let local =
    workflows_update.TemplateAttachmentModel(
      rules: rules,
      task_templates: admin_task_templates.default_model(),
    )

  let assert opt.Some(workflows_update.TemplateAttachmentUpdate(
    next,
    fx,
    auth_policy,
  )) =
    workflows_update.try_template_attachment_update(
      local,
      pool_messages.AttachTemplateFailed(err),
      template_attachment_context(opt.None),
      template_feedback_context(),
    )
  let workflows_update.TemplateAttachmentModel(rules: next_rules, ..) = next

  let assert False = next_rules.attach_template_loading
  let assert True = fx != effect.none()
  let assert workflows_update.CheckTemplateAttachmentAuth(auth_err) =
    auth_policy
  let assert True = auth_err == err
}

pub fn try_template_attachment_update_detach_click_marks_in_flight_test() {
  let local =
    workflows_update.TemplateAttachmentModel(
      rules: admin_rules.default_model(),
      task_templates: admin_task_templates.default_model(),
    )

  let assert opt.Some(workflows_update.TemplateAttachmentUpdate(
    next,
    fx,
    auth_policy,
  )) =
    workflows_update.try_template_attachment_update(
      local,
      pool_messages.TemplateDetachClicked(1, 10),
      template_attachment_context(opt.None),
      template_feedback_context(),
    )
  let workflows_update.TemplateAttachmentModel(rules: next_rules, ..) = next

  let assert True = set.contains(next_rules.detaching_templates, #(1, 10))
  let assert True = fx != effect.none()
  let assert workflows_update.NoTemplateAttachmentAuthCheck = auth_policy
}

pub fn workflow_created_updates_project_scope_and_emits_feedback_test() {
  let existing = workflow(1, "Existing", opt.Some(7))
  let created = workflow(2, "Created", opt.Some(7))
  let workflows =
    admin_workflows.Model(
      workflows_org: Loaded([]),
      workflows_project: Loaded([existing]),
      workflows_dialog_mode: opt.Some(state_types.WorkflowDialogCreate),
    )

  let next = workflows_update.workflow_created(workflows, created)
  let fx =
    workflows_update.workflow_success_effect(
      workflows_update.WorkflowCreated,
      workflow_feedback_context(),
    )

  let assert True = next.workflows_project == Loaded([created, existing])
  let assert True = next.workflows_org == Loaded([])
  let assert opt.None = next.workflows_dialog_mode
  let assert True = fx != effect.none()
}

pub fn rule_updated_replaces_loaded_rule_and_emits_feedback_test() {
  let old = rule(1, "Old", [])
  let updated = rule(1, "Updated", [])
  let other = rule(2, "Other", [])
  let rules =
    admin_rules.Model(
      ..admin_rules.default_model(),
      rules: Loaded([old, other]),
      rules_dialog_mode: opt.Some(state_types.RuleDialogEdit(old)),
    )

  let next = workflows_update.rule_updated(rules, updated)
  let fx =
    workflows_update.rule_success_effect(
      workflows_update.RuleUpdated,
      rule_feedback_context(),
    )

  let assert True = next.rules == Loaded([updated, other])
  let assert opt.None = next.rules_dialog_mode
  let assert True = fx != effect.none()
}

pub fn attach_template_succeeded_updates_rule_and_emits_feedback_test() {
  let attached = rule_template(10, "Regression checklist")
  let rules =
    admin_rules.Model(
      ..admin_rules.default_model(),
      rules: Loaded([rule(1, "Rule", [])]),
      attach_template_modal: opt.Some(1),
      attach_template_selected: opt.Some(10),
      attach_template_loading: True,
    )

  let next = workflows_update.attach_template_succeeded(rules, 1, [attached])
  let fx =
    workflows_update.template_attachment_success_effect(
      workflows_update.TemplateAttached,
      template_feedback_context(),
    )

  let assert Loaded([updated_rule]) = next.rules
  let assert True = updated_rule.templates == [attached]
  let assert opt.None = next.attach_template_modal
  let assert opt.None = next.attach_template_selected
  let assert False = next.attach_template_loading
  let assert True = fx != effect.none()
}

pub fn template_detach_failed_clears_in_flight_and_emits_error_feedback_test() {
  let detaching = set.insert(set.new(), #(1, 10))
  let rules =
    admin_rules.Model(
      ..admin_rules.default_model(),
      rules: Loaded([rule(1, "Rule", [rule_template(10, "Template")])]),
      detaching_templates: detaching,
    )
  let local =
    workflows_update.TemplateAttachmentModel(
      rules: rules,
      task_templates: admin_task_templates.default_model(),
    )
  let err = ApiError(status: 500, code: "ERROR", message: "Backend failed")

  let assert opt.Some(workflows_update.TemplateAttachmentUpdate(
    next,
    fx,
    auth_policy,
  )) =
    workflows_update.try_template_attachment_update(
      local,
      pool_messages.TemplateDetachFailed(1, 10, err),
      template_attachment_context(opt.None),
      template_feedback_context(),
    )
  let workflows_update.TemplateAttachmentModel(rules: next_rules, ..) = next

  let assert False = set.contains(next_rules.detaching_templates, #(1, 10))
  let assert True = fx != effect.none()
  let assert workflows_update.CheckTemplateAttachmentAuth(auth_err) =
    auth_policy
  let assert True = auth_err == err
}
