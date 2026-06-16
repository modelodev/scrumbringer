//// Milestone quick-create routing for task and card creation.

import gleam/option as opt

import lustre/effect

import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/milestones/update as milestone_update
import scrumbringer_client/features/pool/msg as pool_messages

pub fn try_update(
  model: member_pool.Model,
  inner: pool_messages.Msg,
) -> opt.Option(milestone_update.Update(parent_msg)) {
  case inner {
    pool_messages.MemberMilestoneCreateTaskClicked(milestone_id) ->
      opt.Some(open_task_dialog(model, milestone_id))

    pool_messages.MemberMilestoneCreateCardClicked(milestone_id) ->
      opt.Some(request_card_dialog(model, milestone_id))

    _ -> opt.None
  }
}

fn open_task_dialog(
  model: member_pool.Model,
  milestone_id: Int,
) -> milestone_update.Update(parent_msg) {
  milestone_update.Update(
    member_pool.Model(
      ..model,
      member_milestone_dialog: member_pool.MilestoneDialogClosed,
      member_milestone_dialog_in_flight: False,
      member_milestone_dialog_error: opt.None,
      member_create_dialog_mode: dialog_mode.DialogCreate,
      member_create_card_id: opt.None,
      member_create_milestone_id: opt.Some(milestone_id),
    ),
    effect.none(),
    milestone_update.NoRefresh,
    milestone_update.NoRootPolicy,
  )
}

fn request_card_dialog(
  model: member_pool.Model,
  milestone_id: Int,
) -> milestone_update.Update(parent_msg) {
  milestone_update.Update(
    member_pool.Model(
      ..model,
      member_milestone_dialog: member_pool.MilestoneDialogClosed,
      member_milestone_dialog_in_flight: False,
      member_milestone_dialog_error: opt.None,
    ),
    effect.none(),
    milestone_update.NoRefresh,
    milestone_update.OpenCardForMilestone(milestone_id),
  )
}
