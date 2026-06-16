import gleam/option.{None, Some}
import lustre/effect

import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/milestones/create_update
import scrumbringer_client/features/milestones/update as milestones_update
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/pool_prefs

fn assert_equal(actual: a, expected: a) {
  let assert True = actual == expected
}

pub fn milestones_create_update_opens_task_dialog_for_milestone_test() {
  let pool =
    member_pool.Model(
      ..member_pool.default_model(),
      member_milestone_dialog: member_pool.MilestoneDialogEdit(
        id: 88,
        name: "Milestone",
        description: "",
      ),
      member_milestone_dialog_in_flight: True,
      member_milestone_dialog_error: Some("stale"),
    )

  let assert Some(milestones_update.Update(next, fx, policy, root_policy)) =
    create_update.try_update(
      pool,
      pool_messages.MemberMilestoneCreateTaskClicked(88),
    )

  next.member_milestone_dialog
  |> assert_equal(member_pool.MilestoneDialogClosed)
  next.member_milestone_dialog_in_flight |> assert_equal(False)
  next.member_milestone_dialog_error |> assert_equal(None)
  next.member_create_milestone_id |> assert_equal(Some(88))
  next.member_create_card_id |> assert_equal(None)
  let assert True = fx == effect.none()
  policy |> assert_equal(milestones_update.NoRefresh)
  root_policy |> assert_equal(milestones_update.NoRootPolicy)
}

pub fn milestones_create_update_requests_card_dialog_root_policy_test() {
  let pool =
    member_pool.Model(
      ..member_pool.default_model(),
      member_milestone_dialog: member_pool.MilestoneDialogEdit(
        id: 89,
        name: "Milestone",
        description: "",
      ),
      member_milestone_dialog_in_flight: True,
      member_milestone_dialog_error: Some("stale"),
    )

  let assert Some(milestones_update.Update(next, fx, policy, root_policy)) =
    create_update.try_update(
      pool,
      pool_messages.MemberMilestoneCreateCardClicked(89),
    )

  next.member_milestone_dialog
  |> assert_equal(member_pool.MilestoneDialogClosed)
  next.member_milestone_dialog_in_flight |> assert_equal(False)
  next.member_milestone_dialog_error |> assert_equal(None)
  let assert True = fx == effect.none()
  policy |> assert_equal(milestones_update.NoRefresh)
  root_policy
  |> assert_equal(milestones_update.OpenCardForMilestone(89))
}

pub fn milestones_create_update_ignores_unrelated_message_test() {
  create_update.try_update(
    member_pool.default_model(),
    pool_messages.GlobalKeyDown(pool_prefs.KeyEvent(
      key: "Escape",
      ctrl: False,
      meta: False,
      shift: False,
      is_editing: False,
      modal_open: False,
    )),
  )
  |> assert_equal(None)
}
