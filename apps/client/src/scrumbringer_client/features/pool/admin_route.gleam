//// Root-aware adapter for admin-owned flows reachable from the pool.

import gleam/option as opt
import lustre/effect

import domain/api_error.{type ApiError}
import scrumbringer_client/app/effects as app_effects
import scrumbringer_client/client_state
import scrumbringer_client/features/admin/cards as cards_workflow
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/admin/task_templates as task_templates_workflow
import scrumbringer_client/features/admin/workflows as workflows_workflow
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/pool/root
import scrumbringer_client/features/pool/route_support
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/text as i18n_text

pub fn try_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  close_focus_target: fn(client_state.Model) -> opt.Option(String),
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case try_cards_update(model, inner, close_focus_target) {
    opt.Some(result) -> opt.Some(result)
    opt.None -> try_workflows_update(model, inner)
  }
}

fn try_workflows_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case try_workflow_crud_update(model, inner) {
    opt.Some(result) -> opt.Some(result)
    opt.None -> try_rules_update(model, inner)
  }
}

fn try_rules_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case try_rule_update(model, inner) {
    opt.Some(result) -> opt.Some(result)
    opt.None -> try_task_templates_update(model, inner)
  }
}

fn try_cards_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  close_focus_target: fn(client_state.Model) -> opt.Option(String),
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    cards_workflow.try_update(
      model.admin.cards,
      inner,
      card_crud_feedback_context(model),
    )
  {
    opt.Some(update) ->
      opt.Some(apply_cards_update(model, update, close_focus_target))
    opt.None -> opt.None
  }
}

fn apply_cards_update(
  model: client_state.Model,
  update: cards_workflow.Update(client_state.Msg),
  close_focus_target: fn(client_state.Model) -> opt.Option(String),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let cards_workflow.Update(cards, fx, auth_policy, focus_policy) = update

  route_support.apply_auth_check_before(
    model,
    cards_auth_error(auth_policy),
    fn() {
      #(
        root.set_admin_cards(model, cards),
        apply_cards_focus_policy(model, focus_policy, fx, close_focus_target),
      )
    },
  )
}

fn apply_cards_focus_policy(
  model: client_state.Model,
  focus_policy: cards_workflow.FocusPolicy,
  fx: effect.Effect(client_state.Msg),
  close_focus_target: fn(client_state.Model) -> opt.Option(String),
) -> effect.Effect(client_state.Msg) {
  case focus_policy {
    cards_workflow.NoFocusAfterUpdate -> fx
    cards_workflow.FocusAfterClose ->
      case close_focus_target(model) {
        opt.Some(element_id) ->
          effect.batch([
            fx,
            app_effects.focus_element_after_timeout(element_id, 0),
          ])
        opt.None -> fx
      }
  }
}

fn try_workflow_crud_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    workflows_workflow.try_workflows_update(
      model.admin.workflows,
      inner,
      workflow_crud_feedback_context(model),
    )
  {
    opt.Some(update) -> opt.Some(apply_workflows_update(model, update))
    opt.None -> opt.None
  }
}

fn apply_workflows_update(
  model: client_state.Model,
  update: workflows_workflow.WorkflowUpdate(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let workflows_workflow.WorkflowUpdate(workflows, fx, auth_policy) = update

  route_support.apply_auth_check_before(
    model,
    workflow_auth_error(auth_policy),
    fn() { #(root.set_admin_workflows(model, workflows), fx) },
  )
}

fn try_rule_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    workflows_workflow.try_rules_update(
      model.admin.rules,
      inner,
      rules_context(model),
      rule_feedback_context(model),
    )
  {
    opt.Some(update) -> opt.Some(apply_rules_update(model, update))
    opt.None -> opt.None
  }
}

fn apply_rules_update(
  model: client_state.Model,
  update: workflows_workflow.RulesUpdate(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let workflows_workflow.RulesUpdate(rules, fx, auth_policy) = update

  route_support.apply_auth_check_before(
    model,
    rules_auth_error(auth_policy),
    fn() { #(root.set_admin_rules(model, rules), fx) },
  )
}

fn try_task_templates_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    task_templates_workflow.try_update(
      model.admin.task_templates,
      inner,
      task_template_crud_feedback_context(model),
    )
  {
    opt.Some(update) -> opt.Some(apply_task_templates_update(model, update))
    opt.None -> opt.None
  }
}

fn apply_task_templates_update(
  model: client_state.Model,
  update: task_templates_workflow.Update(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let task_templates_workflow.Update(task_templates, fx, auth_policy) = update

  route_support.apply_auth_check_before(
    model,
    task_templates_auth_error(auth_policy),
    fn() { #(root.set_admin_task_templates(model, task_templates), fx) },
  )
}

fn rules_context(
  model: client_state.Model,
) -> workflows_workflow.RulesContext(client_state.Msg) {
  workflows_workflow.RulesContext(
    selected_project_id: model.core.selected_project_id,
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

fn card_crud_feedback_context(
  model: client_state.Model,
) -> cards_workflow.CrudFeedbackContext(client_state.Msg) {
  cards_workflow.CrudFeedbackContext(
    card_created: i18n.t(model.ui.locale, i18n_text.CardCreated),
    card_updated: i18n.t(model.ui.locale, i18n_text.CardUpdated),
    card_deleted: i18n.t(model.ui.locale, i18n_text.CardDeleted),
    on_success_toast: app_effects.toast_success,
  )
}

fn workflow_crud_feedback_context(
  model: client_state.Model,
) -> workflows_workflow.WorkflowFeedbackContext(client_state.Msg) {
  workflows_workflow.WorkflowFeedbackContext(
    workflow_created: i18n.t(model.ui.locale, i18n_text.WorkflowCreated),
    workflow_updated: i18n.t(model.ui.locale, i18n_text.WorkflowUpdated),
    workflow_deleted: i18n.t(model.ui.locale, i18n_text.WorkflowDeleted),
    on_success_toast: app_effects.toast_success,
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

fn rule_feedback_context(
  model: client_state.Model,
) -> workflows_workflow.RuleFeedbackContext(client_state.Msg) {
  workflows_workflow.RuleFeedbackContext(
    rule_created: i18n.t(model.ui.locale, i18n_text.RuleCreated),
    rule_updated: i18n.t(model.ui.locale, i18n_text.RuleUpdated),
    rule_deleted: i18n.t(model.ui.locale, i18n_text.RuleDeleted),
    on_success_toast: app_effects.toast_success,
    on_rule_saved: fn(result) {
      client_state.pool_msg(pool_messages.RuleSaved(result))
    },
    on_rule_deleted: fn(rule_id, result) {
      client_state.pool_msg(pool_messages.RuleDeleteFinished(rule_id, result))
    },
  )
}

fn task_template_crud_feedback_context(
  model: client_state.Model,
) -> task_templates_workflow.FeedbackContext(client_state.Msg) {
  task_templates_workflow.FeedbackContext(
    task_template_created: i18n.t(
      model.ui.locale,
      i18n_text.TaskTemplateCreated,
    ),
    task_template_updated: i18n.t(
      model.ui.locale,
      i18n_text.TaskTemplateUpdated,
    ),
    task_template_deleted: i18n.t(
      model.ui.locale,
      i18n_text.TaskTemplateDeleted,
    ),
    on_success_toast: app_effects.toast_success,
    on_template_saved: fn(result) {
      client_state.pool_msg(pool_messages.TaskTemplateSaved(result))
    },
    on_template_deleted: fn(template_id, result) {
      client_state.pool_msg(pool_messages.TaskTemplateDeleteFinished(
        template_id,
        result,
      ))
    },
  )
}

fn cards_auth_error(policy: cards_workflow.AuthPolicy) -> opt.Option(ApiError) {
  case policy {
    cards_workflow.NoAuthCheck -> opt.None
    cards_workflow.CheckAuth(err) -> opt.Some(err)
  }
}

fn workflow_auth_error(
  policy: workflows_workflow.WorkflowAuthPolicy,
) -> opt.Option(ApiError) {
  case policy {
    workflows_workflow.NoWorkflowAuthCheck -> opt.None
    workflows_workflow.CheckWorkflowAuth(err) -> opt.Some(err)
  }
}

fn rules_auth_error(
  policy: workflows_workflow.RulesAuthPolicy,
) -> opt.Option(ApiError) {
  case policy {
    workflows_workflow.NoRulesAuthCheck -> opt.None
    workflows_workflow.CheckRulesAuth(err) -> opt.Some(err)
  }
}

fn task_templates_auth_error(
  policy: task_templates_workflow.AuthPolicy,
) -> opt.Option(ApiError) {
  case policy {
    task_templates_workflow.NoAuthCheck -> opt.None
    task_templates_workflow.CheckAuth(err) -> opt.Some(err)
  }
}
