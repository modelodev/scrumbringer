import gleam/option.{None, Some}

import domain/api_error.{ApiError}
import domain/milestone.{
  type MilestoneProgress, type MilestoneState, Active, Milestone,
  MilestoneProgress, Ready,
}
import domain/remote.{Failed, Loaded, Loading, NotAsked}
import scrumbringer_client/features/milestones/refresh as milestone_refresh
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
  let store =
    normalized_store.new()
    |> milestone_refresh.mark_pending(2)
  let progress = sample_progress(10, Ready)

  let milestone_refresh.ProjectFetched(
    milestones_store: next_store,
    milestones: next_milestones,
    selected_milestone_id: selected_id,
  ) =
    milestone_refresh.project_fetched(store, Loading, None, 1, [
      progress,
    ])

  let assert 1 = normalized_store.pending(next_store)
  let assert Loading = next_milestones
  let assert None = selected_id
}

pub fn project_fetched_selects_active_milestone_when_ready_test() {
  let store =
    normalized_store.new()
    |> milestone_refresh.mark_pending(1)

  let milestone_refresh.ProjectFetched(
    milestones: milestones,
    selected_milestone_id: selected_id,
    ..,
  ) =
    milestone_refresh.project_fetched(store, Loading, None, 1, [
      sample_progress(10, Ready),
      sample_progress(20, Active),
    ])

  let assert Loaded([_, _]) = milestones
  let assert Some(20) = selected_id
}

pub fn project_fetched_keeps_existing_selection_test() {
  let store =
    normalized_store.new()
    |> milestone_refresh.mark_pending(1)

  let milestone_refresh.ProjectFetched(selected_milestone_id: selected_id, ..) =
    milestone_refresh.project_fetched(store, Loading, Some(10), 1, [
      sample_progress(10, Ready),
      sample_progress(20, Active),
    ])

  let assert Some(10) = selected_id
}

pub fn project_failed_preserves_loaded_milestones_and_fails_empty_state_test() {
  let progress = sample_progress(10, Ready)

  let #(_loaded_store, loaded_milestones) =
    milestone_refresh.project_failed(
      milestone_refresh.mark_pending(normalized_store.new(), 1),
      Loaded([progress]),
      api_error(),
    )
  let #(_empty_store, empty_milestones) =
    milestone_refresh.project_failed(
      milestone_refresh.mark_pending(normalized_store.new(), 1),
      Loading,
      api_error(),
    )

  let assert Loaded([_progress]) = loaded_milestones
  let assert Failed(ApiError(status: 500, code: "ERR", message: "boom")) =
    empty_milestones
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
