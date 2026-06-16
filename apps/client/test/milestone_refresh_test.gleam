import gleam/option.{None, Some}

import domain/api_error.{ApiError}
import domain/milestone.{
  type MilestoneProgress, type MilestoneState, Active, Milestone,
  MilestoneProgress, Ready,
}
import domain/remote.{Failed, Loaded, Loading, NotAsked}
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/milestones/refresh as milestone_refresh
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/pool_prefs
import scrumbringer_client/state/normalized_store

pub fn loading_unless_loaded_preserves_loaded_milestones_test() {
  let progress = sample_progress(1, Ready)

  let assert Loaded([_progress]) =
    milestone_refresh.loading_unless_loaded(Loaded([progress]))
  let assert Loading = milestone_refresh.loading_unless_loaded(NotAsked)
  let assert Loading =
    milestone_refresh.loading_unless_loaded(Failed(api_error()))
}

pub fn project_fetched_updates_store_and_waits_until_ready_test() {
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_milestones_store: milestone_refresh.mark_pending(
        normalized_store.new(),
        2,
      ),
      member_milestones: Loading,
    )
  let progress = sample_progress(10, Ready)

  let assert Some(next) =
    milestone_refresh.try_update(
      model,
      pool_messages.MemberProjectMilestonesFetched(1, Ok([progress])),
    )

  let assert 1 = normalized_store.pending(next.member_milestones_store)
  let assert Loading = next.member_milestones
  let assert None = next.member_selected_milestone_id
}

pub fn project_fetched_selects_active_milestone_when_ready_test() {
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_milestones_store: milestone_refresh.mark_pending(
        normalized_store.new(),
        1,
      ),
      member_milestones: Loading,
    )

  let assert Some(next) =
    milestone_refresh.try_update(
      model,
      pool_messages.MemberProjectMilestonesFetched(
        1,
        Ok([
          sample_progress(10, Ready),
          sample_progress(20, Active),
        ]),
      ),
    )

  let assert Loaded([_, _]) = next.member_milestones
  let assert Some(20) = next.member_selected_milestone_id
}

pub fn project_fetched_keeps_existing_selection_test() {
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_milestones_store: milestone_refresh.mark_pending(
        normalized_store.new(),
        1,
      ),
      member_milestones: Loading,
      member_selected_milestone_id: Some(10),
    )

  let assert Some(next) =
    milestone_refresh.try_update(
      model,
      pool_messages.MemberProjectMilestonesFetched(
        1,
        Ok([
          sample_progress(10, Ready),
          sample_progress(20, Active),
        ]),
      ),
    )

  let assert Some(10) = next.member_selected_milestone_id
}

pub fn project_failed_preserves_loaded_milestones_and_fails_empty_state_test() {
  let progress = sample_progress(10, Ready)

  let loaded_model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_milestones_store: milestone_refresh.mark_pending(
        normalized_store.new(),
        1,
      ),
      member_milestones: Loaded([progress]),
    )
  let empty_model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_milestones_store: milestone_refresh.mark_pending(
        normalized_store.new(),
        1,
      ),
      member_milestones: Loading,
    )

  let assert Some(loaded_next) =
    milestone_refresh.try_update(
      loaded_model,
      pool_messages.MemberProjectMilestonesFetched(1, Error(api_error())),
    )
  let assert Some(empty_next) =
    milestone_refresh.try_update(
      empty_model,
      pool_messages.MemberProjectMilestonesFetched(1, Error(api_error())),
    )

  let assert Loaded([_progress]) = loaded_next.member_milestones
  let assert Failed(ApiError(status: 500, code: "ERR", message: "boom")) =
    empty_next.member_milestones
}

pub fn try_update_ignores_non_refresh_message_test() {
  let assert None =
    milestone_refresh.try_update(
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
}

fn api_error() {
  ApiError(status: 500, code: "ERR", message: "boom")
}

fn sample_progress(id: Int, state: MilestoneState) -> MilestoneProgress {
  MilestoneProgress(
    milestone: Milestone(
      id: id,
      project_id: 1,
      name: "Milestone",
      description: None,
      state: state,
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
