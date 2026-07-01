//// Root-aware adapter for admin-owned flows reachable from the pool.

import gleam/int
import gleam/option as opt
import lustre/effect

import domain/api_error.{type ApiError}
import domain/workflow.{type TaskTemplate}
import scrumbringer_client/app/effects as app_effects
import scrumbringer_client/client_state
import scrumbringer_client/client_state/admin/rules as admin_rules
import scrumbringer_client/client_state/admin/task_templates as admin_task_templates
import scrumbringer_client/client_state/admin/workflows as admin_workflows
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/features/admin/cards as cards_workflow
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/admin/task_templates as task_templates_workflow
import scrumbringer_client/features/admin/workflows as automations_update
import scrumbringer_client/features/automations/focus_target as automation_focus
import scrumbringer_client/features/cards/cache as card_cache
import scrumbringer_client/features/pool/card_show_state
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/pool/root
import scrumbringer_client/features/route_support
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/text as i18n_text

pub fn try_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  close_focus_target: fn(client_state.Model) -> opt.Option(String),
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case try_cards_update(model, inner, close_focus_target) {
    opt.Some(result) -> opt.Some(result)
    opt.None -> try_automation_admin_update(model, inner)
  }
}

fn try_automation_admin_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case try_engine_crud_update(model, inner) {
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
      opt.Some(apply_cards_update(model, inner, update, close_focus_target))
    opt.None -> opt.None
  }
}

fn apply_cards_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  update: cards_workflow.Update(client_state.Msg),
  close_focus_target: fn(client_state.Model) -> opt.Option(String),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let cards_workflow.Update(cards, fx, auth_policy, focus_policy) = update

  route_support.apply_auth_check(
    model,
    route_support.auth_check_before(cards_auth_error(auth_policy)),
    fn() {
      let next =
        root.set_admin_cards(model, cards)
        |> sync_member_card_cache(inner)

      #(
        next,
        apply_cards_focus_policy(model, focus_policy, fx, close_focus_target),
      )
    },
  )
}

fn sync_member_card_cache(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> client_state.Model {
  case inner {
    pool_messages.CardCrudCreated(card) ->
      root.set_member_pool(model, card_cache.created(model.member.pool, card))
    pool_messages.CardCrudUpdated(card) ->
      root.set_member_pool(model, card_cache.updated(model.member.pool, card))
    pool_messages.CardCrudDeleted(card_id) ->
      root.set_member_pool(
        model,
        card_cache.deleted(model.member.pool, card_id),
      )
      |> close_card_show_if_deleted(card_id)
    _ -> model
  }
}

fn close_card_show_if_deleted(
  model: client_state.Model,
  deleted_card_id: Int,
) -> client_state.Model {
  case model.member.card_show_open {
    opt.Some(open_card_id) if open_card_id == deleted_card_id -> {
      let #(card_show_open, card_show_model) = card_show_state.handle_closed()
      client_state.update_member(model, fn(member) {
        member_state.MemberModel(
          ..member,
          card_show_open: card_show_open,
          card_show_model: card_show_model,
        )
      })
    }
    _ -> model
  }
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

fn try_engine_crud_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    automations_update.try_engines_update(
      model.admin.workflows,
      inner,
      engine_crud_feedback_context(model),
    )
  {
    opt.Some(update) -> opt.Some(apply_engine_update(model, inner, update))
    opt.None -> opt.None
  }
}

fn apply_engine_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  update: automations_update.EngineUpdate(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let automations_update.EngineUpdate(workflows, fx, auth_policy) = update

  route_support.apply_auth_check(
    model,
    route_support.auth_check_before(engine_auth_error(auth_policy)),
    fn() {
      #(
        root.set_admin_workflows(model, workflows),
        apply_automation_panel_focus(model, inner, fx),
      )
    },
  )
}

fn try_rule_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    automations_update.try_rules_update(
      model.admin.rules,
      inner,
      rules_context(model),
      rule_feedback_context(model),
    )
  {
    opt.Some(update) -> opt.Some(apply_rules_update(model, inner, update))
    opt.None -> opt.None
  }
}

fn apply_rules_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  update: automations_update.RulesUpdate(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let automations_update.RulesUpdate(rules, fx, auth_policy) = update

  route_support.apply_auth_check(
    model,
    route_support.auth_check_before(rules_auth_error(auth_policy)),
    fn() {
      #(
        root.set_admin_rules(model, rules),
        apply_automation_panel_focus(model, inner, fx),
      )
    },
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
    opt.Some(update) ->
      opt.Some(apply_task_templates_update(model, inner, update))
    opt.None -> opt.None
  }
}

fn apply_task_templates_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  update: task_templates_workflow.Update(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let task_templates_workflow.Update(task_templates, fx, auth_policy) = update

  route_support.apply_auth_check(
    model,
    route_support.auth_check_before(task_templates_auth_error(auth_policy)),
    fn() {
      let updated = root.set_admin_task_templates(model, task_templates)
      #(
        select_created_template_for_rule_builder(updated, model, inner),
        apply_automation_panel_focus(model, inner, fx),
      )
    },
  )
}

fn apply_automation_panel_focus(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  fx: effect.Effect(client_state.Msg),
) -> effect.Effect(client_state.Msg) {
  case automation_panel_focus_target(model, inner) {
    opt.Some(element_id) ->
      effect.batch([
        fx,
        app_effects.focus_element_after_timeout(element_id, 0),
      ])
    opt.None -> fx
  }
}

fn automation_panel_focus_target(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> opt.Option(String) {
  case inner {
    pool_messages.CloseEngineDialog
    | pool_messages.EngineSaved(Ok(_))
    | pool_messages.EngineDeleteFinished(_, Ok(_)) ->
      engine_dialog_focus_target(model.admin.workflows.engine_dialog_mode)

    pool_messages.CloseRuleDialog
    | pool_messages.RuleSaved(Ok(_))
    | pool_messages.RuleDeleteFinished(_, Ok(_)) ->
      rule_dialog_focus_target(model.admin.rules.rules_dialog_mode)

    pool_messages.CloseTaskTemplateDialog
    | pool_messages.TaskTemplateSaved(Ok(_))
    | pool_messages.TaskTemplateDeleteFinished(_, Ok(_)) ->
      task_template_dialog_focus_target(
        model.admin.task_templates.task_templates_dialog_mode,
      )

    _ -> opt.None
  }
}

fn engine_dialog_focus_target(
  mode: opt.Option(admin_workflows.EngineDialogMode),
) -> opt.Option(String) {
  case mode {
    opt.Some(admin_workflows.EngineDialogCreate) ->
      opt.Some(automation_focus.create_engine_trigger_id)
    opt.Some(admin_workflows.EngineDialogEdit(workflow)) ->
      opt.Some(automation_focus.engine_edit_trigger_id(workflow.id))
    opt.Some(admin_workflows.EngineDialogDelete(workflow)) ->
      opt.Some(automation_focus.engine_delete_trigger_id(workflow.id))
    opt.None -> opt.None
  }
}

fn rule_dialog_focus_target(
  mode: opt.Option(admin_rules.RuleDialogMode),
) -> opt.Option(String) {
  case mode {
    opt.Some(admin_rules.RuleDialogCreate) ->
      opt.Some(automation_focus.create_rule_trigger_id)
    opt.Some(admin_rules.RuleDialogEdit(rule)) ->
      opt.Some(automation_focus.rule_edit_trigger_id(rule.id))
    opt.Some(admin_rules.RuleDialogDelete(rule)) ->
      opt.Some(automation_focus.rule_delete_trigger_id(rule.id))
    opt.None -> opt.None
  }
}

fn task_template_dialog_focus_target(
  mode: opt.Option(admin_task_templates.TaskTemplateDialogMode),
) -> opt.Option(String) {
  case mode {
    opt.Some(admin_task_templates.TaskTemplateDialogCreate) ->
      opt.Some(automation_focus.create_template_trigger_id)
    opt.Some(admin_task_templates.TaskTemplateDialogEdit(template)) ->
      opt.Some(automation_focus.template_edit_trigger_id(template.id))
    opt.Some(admin_task_templates.TaskTemplateDialogDelete(template)) ->
      opt.Some(automation_focus.template_delete_trigger_id(template.id))
    opt.None -> opt.None
  }
}

fn select_created_template_for_rule_builder(
  updated: client_state.Model,
  previous: client_state.Model,
  inner: client_state.PoolMsg,
) -> client_state.Model {
  case inner, previous.admin.task_templates.task_templates_dialog_mode {
    pool_messages.TaskTemplateSaved(Ok(template)),
      opt.Some(admin_task_templates.TaskTemplateDialogCreate)
    -> select_rule_builder_template(updated, template)
    _, _ -> updated
  }
}

fn select_rule_builder_template(
  model: client_state.Model,
  template: TaskTemplate,
) -> client_state.Model {
  case rule_builder_is_open(model.admin.rules.rules_dialog_mode) {
    True -> {
      let rules = model.admin.rules
      root.set_admin_rules(
        model,
        admin_rules.Model(
          ..rules,
          rule_form_template_id: int.to_string(template.id),
          rule_form_template_search: "",
          rule_form_error: opt.None,
        ),
      )
    }
    False -> model
  }
}

fn rule_builder_is_open(mode: opt.Option(admin_rules.RuleDialogMode)) -> Bool {
  case mode {
    opt.Some(admin_rules.RuleDialogCreate)
    | opt.Some(admin_rules.RuleDialogEdit(_)) -> True
    opt.Some(admin_rules.RuleDialogDelete(_)) | opt.None -> False
  }
}

fn rules_context(
  model: client_state.Model,
) -> automations_update.RulesContext(client_state.Msg) {
  automations_update.RulesContext(
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

fn engine_crud_feedback_context(
  model: client_state.Model,
) -> automations_update.EngineFeedbackContext(client_state.Msg) {
  automations_update.EngineFeedbackContext(
    engine_created: i18n.t(model.ui.locale, i18n_text.AutomationEngineCreated),
    engine_updated: i18n.t(model.ui.locale, i18n_text.AutomationEngineUpdated),
    engine_deleted: i18n.t(model.ui.locale, i18n_text.AutomationEngineDeleted),
    on_success_toast: app_effects.toast_success,
    on_engine_saved: fn(result) {
      client_state.pool_msg(pool_messages.EngineSaved(result))
    },
    on_engine_deleted: fn(workflow_id, result) {
      client_state.pool_msg(pool_messages.EngineDeleteFinished(
        workflow_id,
        result,
      ))
    },
  )
}

fn rule_feedback_context(
  model: client_state.Model,
) -> automations_update.RuleFeedbackContext(client_state.Msg) {
  automations_update.RuleFeedbackContext(
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

fn engine_auth_error(
  policy: automations_update.EngineAuthPolicy,
) -> opt.Option(ApiError) {
  case policy {
    automations_update.NoEngineAuthCheck -> opt.None
    automations_update.CheckEngineAuth(err) -> opt.Some(err)
  }
}

fn rules_auth_error(
  policy: automations_update.RulesAuthPolicy,
) -> opt.Option(ApiError) {
  case policy {
    automations_update.NoRulesAuthCheck -> opt.None
    automations_update.CheckRulesAuth(err) -> opt.Some(err)
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
