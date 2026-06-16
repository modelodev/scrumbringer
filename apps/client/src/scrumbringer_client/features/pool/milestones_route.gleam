//// Root-aware adapter for member-pool milestone updates.

import gleam/option as opt
import lustre/effect

import scrumbringer_client/app/effects as app_effects
import scrumbringer_client/client_state
import scrumbringer_client/features/admin/cards as cards_workflow
import scrumbringer_client/features/milestones/create_update as milestone_create_update
import scrumbringer_client/features/milestones/dialog_update as milestone_dialog_update
import scrumbringer_client/features/milestones/movement_update as milestone_movement_update
import scrumbringer_client/features/milestones/update as milestones_workflow
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/pool/root
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/text as i18n_text

pub fn try_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  let feedback = feedback_context(model)
  let context = milestones_context(model)

  case
    milestone_dialog_update.try_update(
      model.member.pool,
      inner,
      context,
      feedback,
    )
  {
    opt.Some(update) ->
      opt.Some(apply_update(model, update, feedback, member_refresh))
    opt.None ->
      try_movement_update(
        model,
        inner,
        movement_context(),
        feedback,
        member_refresh,
      )
  }
}

fn try_movement_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  context: milestone_movement_update.Context(client_state.Msg),
  feedback: milestones_workflow.FeedbackContext(client_state.Msg),
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    milestone_movement_update.try_update(
      model.member.pool,
      inner,
      context,
      feedback,
    )
  {
    opt.Some(update) ->
      opt.Some(apply_update(model, update, feedback, member_refresh))
    opt.None -> try_create_update(model, inner, feedback, member_refresh)
  }
}

fn try_create_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  feedback: milestones_workflow.FeedbackContext(client_state.Msg),
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case milestone_create_update.try_update(model.member.pool, inner) {
    opt.Some(update) ->
      opt.Some(apply_update(model, update, feedback, member_refresh))
    opt.None -> try_workflow_update(model, inner, feedback, member_refresh)
  }
}

fn try_workflow_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  feedback: milestones_workflow.FeedbackContext(client_state.Msg),
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case milestones_workflow.try_member_pool_update(model.member.pool, inner) {
    opt.Some(update) ->
      opt.Some(apply_update(model, update, feedback, member_refresh))
    opt.None -> opt.None
  }
}

fn apply_update(
  model: client_state.Model,
  update: milestones_workflow.Update(client_state.Msg),
  feedback: milestones_workflow.FeedbackContext(client_state.Msg),
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let milestones_workflow.Update(pool, local_fx, refresh_policy, root_policy) =
    update
  let model = root.set_member_pool(model, pool)

  let #(model, fx) =
    apply_refresh_policy(
      model,
      local_fx,
      refresh_policy,
      feedback,
      member_refresh,
    )

  apply_root_policy(model, fx, root_policy)
}

fn apply_refresh_policy(
  model: client_state.Model,
  local_fx: effect.Effect(client_state.Msg),
  refresh_policy: milestones_workflow.RefreshPolicy,
  feedback: milestones_workflow.FeedbackContext(client_state.Msg),
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case refresh_policy {
    milestones_workflow.NoRefresh -> #(model, local_fx)
    milestones_workflow.RefreshWithSuccess(success) -> {
      let #(next, refresh_fx) = member_refresh(model)
      #(
        next,
        effect.batch([
          local_fx,
          milestones_workflow.success_effect(success, feedback),
          refresh_fx,
        ]),
      )
    }
  }
}

fn apply_root_policy(
  model: client_state.Model,
  fx: effect.Effect(client_state.Msg),
  policy: milestones_workflow.RootPolicy,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case policy {
    milestones_workflow.NoRootPolicy -> #(model, fx)
    milestones_workflow.OpenCardForMilestone(milestone_id) -> {
      let #(cards, card_fx) =
        cards_workflow.handle_open_card_dialog_for_milestone(
          model.admin.cards,
          milestone_id,
        )
      #(root.set_admin_cards(model, cards), effect.batch([fx, card_fx]))
    }
  }
}

fn milestones_context(
  model: client_state.Model,
) -> milestones_workflow.Context(client_state.Msg) {
  milestones_workflow.Context(
    selected_project_id: model.core.selected_project_id,
    on_milestone_activated: fn(milestone_id, result) {
      client_state.pool_msg(pool_messages.MemberMilestoneActivated(
        milestone_id,
        result,
      ))
    },
    on_milestone_created: fn(result) {
      client_state.pool_msg(pool_messages.MemberMilestoneCreated(result))
    },
    on_milestone_updated: fn(result) {
      client_state.pool_msg(pool_messages.MemberMilestoneUpdated(result))
    },
    on_milestone_deleted: fn(milestone_id, result) {
      client_state.pool_msg(pool_messages.MemberMilestoneDeleted(
        milestone_id,
        result,
      ))
    },
    name_required: i18n.t(model.ui.locale, i18n_text.NameRequired),
    select_project_first: i18n.t(model.ui.locale, i18n_text.SelectProjectFirst),
  )
}

fn movement_context() -> milestone_movement_update.Context(client_state.Msg) {
  milestone_movement_update.Context(
    on_milestone_card_moved: fn(result) {
      client_state.pool_msg(pool_messages.MemberMilestoneCardMoved(result))
    },
    on_milestone_task_moved: fn(result) {
      client_state.pool_msg(pool_messages.MemberMilestoneTaskMoved(result))
    },
  )
}

fn feedback_context(
  model: client_state.Model,
) -> milestones_workflow.FeedbackContext(client_state.Msg) {
  milestones_workflow.FeedbackContext(
    milestone_activated: i18n.t(model.ui.locale, i18n_text.MilestoneActivated),
    milestone_created: i18n.t(model.ui.locale, i18n_text.MilestoneCreated),
    milestone_updated: i18n.t(model.ui.locale, i18n_text.MilestoneUpdated),
    milestone_deleted: i18n.t(model.ui.locale, i18n_text.MilestoneDeleted),
    milestone_activate_failed: i18n.t(
      model.ui.locale,
      i18n_text.MilestoneActivateFailed,
    ),
    milestone_create_failed: i18n.t(
      model.ui.locale,
      i18n_text.MilestoneCreateFailed,
    ),
    milestone_update_failed: i18n.t(
      model.ui.locale,
      i18n_text.MilestoneUpdateFailed,
    ),
    milestone_delete_failed: i18n.t(
      model.ui.locale,
      i18n_text.MilestoneDeleteFailed,
    ),
    milestone_already_active: i18n.t(
      model.ui.locale,
      i18n_text.MilestoneAlreadyActive,
    ),
    milestone_activation_irreversible: i18n.t(
      model.ui.locale,
      i18n_text.MilestoneActivationIrreversible,
    ),
    milestone_delete_not_allowed: i18n.t(
      model.ui.locale,
      i18n_text.MilestoneDeleteNotAllowed,
    ),
    on_success_toast: app_effects.toast_success,
    on_error_toast: app_effects.toast_error,
  )
}
