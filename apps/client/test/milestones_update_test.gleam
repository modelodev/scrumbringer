import gleam/int
import gleam/option.{None, Some}
import gleeunit/should
import lustre/effect

import domain/api_error.{ApiError}
import domain/milestone.{
  type MilestoneProgress, Milestone, MilestoneProgress, Ready,
}
import domain/remote.{Loaded}

import scrumbringer_client/client_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/pool/update as pool_update
import scrumbringer_client/helpers/i18n as helpers_i18n
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/member_section
import scrumbringer_client/pool_prefs

fn test_context() -> pool_update.Context {
  pool_update.Context(member_refresh: fn(model) {
    #(
      client_state.update_member(model, fn(member) {
        let pool = member.pool
        member_state.MemberModel(
          ..member,
          pool: member_pool.Model(..pool, member_filters_q: "refreshed"),
        )
      }),
      effect.none(),
    )
  })
}

fn sample_progress(id: Int) -> MilestoneProgress {
  MilestoneProgress(
    milestone: Milestone(
      id: id,
      project_id: 1,
      name: "Milestone " <> int.to_string(id),
      description: Some("Desc"),
      state: Ready,
      position: 1,
      created_by: 1,
      created_at: "2026-01-01T00:00:00Z",
      activated_at: None,
      completed_at: None,
    ),
    cards_total: 3,
    cards_completed: 1,
    tasks_total: 6,
    tasks_completed: 2,
  )
}

pub fn milestone_activate_clicked_sets_in_flight_id_test() {
  let model = client_state.default_model()

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberMilestoneActivateClicked(42),
      test_context(),
    )

  next.member.pool.member_milestone_activate_in_flight_id
  |> should.equal(Some(42))
  next.member.pool.member_milestone_dialog_in_flight |> should.equal(True)
}

pub fn milestone_activate_prompt_opens_dialog_test() {
  let model = client_state.default_model()

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberMilestoneActivatePromptClicked(42),
      test_context(),
    )

  next.member.pool.member_milestone_dialog
  |> should.equal(member_pool.MilestoneDialogActivate(42))
}

pub fn milestone_dialog_closed_resets_dialog_state_test() {
  let model =
    client_state.default_model()
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_milestone_dialog: member_pool.MilestoneDialogActivate(42),
          member_milestone_dialog_in_flight: True,
          member_milestone_dialog_error: Some("boom"),
        ),
      )
    })

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberMilestoneDialogClosed,
      test_context(),
    )

  next.member.pool.member_milestone_dialog
  |> should.equal(member_pool.MilestoneDialogClosed)
  next.member.pool.member_milestone_dialog_in_flight |> should.equal(False)
  next.member.pool.member_milestone_dialog_error |> should.equal(None)
}

pub fn milestone_activated_ok_clears_in_flight_and_refreshes_test() {
  let model =
    client_state.default_model()
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_milestone_activate_in_flight_id: Some(7),
        ),
      )
    })

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberMilestoneActivated(7, Ok(Nil)),
      test_context(),
    )

  next.member.pool.member_milestone_activate_in_flight_id
  |> should.equal(None)
  next.member.pool.member_filters_q |> should.equal("refreshed")
}

pub fn milestone_edit_clicked_opens_edit_dialog_test() {
  let model =
    client_state.default_model()
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_milestones: Loaded([sample_progress(3)]),
        ),
      )
    })

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberMilestoneEditClicked(3),
      test_context(),
    )

  next.member.pool.member_milestone_dialog
  |> should.equal(member_pool.MilestoneDialogEdit(3, "Milestone 3", "Desc"))
}

pub fn milestone_delete_clicked_opens_delete_dialog_test() {
  let model =
    client_state.default_model()
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_milestones: Loaded([sample_progress(5)]),
        ),
      )
    })

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberMilestoneDeleteClicked(5),
      test_context(),
    )

  next.member.pool.member_milestone_dialog
  |> should.equal(member_pool.MilestoneDialogDelete(5, "Milestone 5"))
}

pub fn milestone_activate_error_maps_backend_code_test() {
  let model = client_state.default_model()

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberMilestoneActivated(
        7,
        Error(ApiError(
          status: 409,
          code: "MILESTONE_ALREADY_ACTIVE",
          message: "Another milestone is already active",
        )),
      ),
      test_context(),
    )

  let expected = helpers_i18n.i18n_t(next, i18n_text.MilestoneAlreadyActive)

  next.member.pool.member_milestone_dialog_error |> should.equal(Some(expected))
}

pub fn milestone_delete_error_maps_backend_code_test() {
  let model = client_state.default_model()

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberMilestoneDeleted(
        7,
        Error(ApiError(
          status: 409,
          code: "MILESTONE_DELETE_NOT_ALLOWED",
          message: "Milestone must be ready and empty",
        )),
      ),
      test_context(),
    )

  let expected = helpers_i18n.i18n_t(next, i18n_text.MilestoneDeleteNotAllowed)

  next.member.pool.member_milestone_dialog_error |> should.equal(Some(expected))
}

pub fn milestone_filters_toggle_flags_test() {
  let model = client_state.default_model()

  let #(next_a, _fx_a) =
    pool_update.update(
      model,
      pool_messages.MemberMilestonesShowCompletedToggled,
      test_context(),
    )

  next_a.member.pool.member_milestones_show_completed |> should.equal(True)

  let #(next_b, _fx_b) =
    pool_update.update(
      next_a,
      pool_messages.MemberMilestonesShowEmptyToggled,
      test_context(),
    )

  next_b.member.pool.member_milestones_show_empty |> should.equal(True)
}

pub fn milestone_details_click_opens_view_dialog_test() {
  let model = client_state.default_model()

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberMilestoneDetailsClicked(77),
      test_context(),
    )

  next.member.pool.member_milestone_dialog
  |> should.equal(member_pool.MilestoneDialogView(77))
}

pub fn milestone_escape_shortcut_closes_activate_dialog_test() {
  let model =
    client_state.default_model()
    |> client_state.update_core(fn(core) {
      client_state.CoreModel(..core, page: client_state.Member)
    })
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_section: member_section.Pool,
          member_milestone_dialog: member_pool.MilestoneDialogActivate(42),
          member_milestone_dialog_in_flight: True,
          member_milestone_dialog_error: Some("boom"),
        ),
      )
    })

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.GlobalKeyDown(pool_prefs.KeyEvent(
        key: "Escape",
        ctrl: False,
        meta: False,
        shift: False,
        is_editing: False,
        modal_open: False,
      )),
      test_context(),
    )

  next.member.pool.member_milestone_dialog
  |> should.equal(member_pool.MilestoneDialogClosed)
  next.member.pool.member_milestone_dialog_in_flight |> should.equal(False)
  next.member.pool.member_milestone_dialog_error |> should.equal(None)
}
