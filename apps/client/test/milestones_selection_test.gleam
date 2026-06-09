import gleam/int
import gleam/option as opt

import domain/milestone.{
  type MilestoneProgress, type MilestoneState, Active, Completed, Milestone,
  MilestoneProgress, Ready,
}
import scrumbringer_client/features/milestones/selection

fn milestone(id: Int, state: MilestoneState) -> MilestoneProgress {
  MilestoneProgress(
    milestone: Milestone(
      id: id,
      project_id: 1,
      name: "Milestone " <> int.to_string(id),
      description: opt.None,
      state: state,
      position: id,
      created_by: 1,
      created_at: "2026-02-06T00:00:00Z",
      activated_at: opt.None,
      completed_at: opt.None,
    ),
    cards_total: 0,
    cards_completed: 0,
    tasks_total: 0,
    tasks_completed: 0,
  )
}

fn assert_selected_id(selected: opt.Option(MilestoneProgress), expected_id: Int) {
  let assert opt.Some(progress) = selected
  let assert True = progress.milestone.id == expected_id
}

pub fn milestones_selection_prefers_explicit_selected_id_test() {
  let items = [milestone(1, Active), milestone(2, Ready)]

  selection.selected_progress(items, opt.Some(2))
  |> assert_selected_id(2)
}

pub fn milestones_selection_falls_back_to_active_when_missing_selected_id_test() {
  let items = [milestone(1, Ready), milestone(2, Active)]

  selection.selected_progress(items, opt.Some(99))
  |> assert_selected_id(2)
}

pub fn milestones_selection_prefers_active_by_default_test() {
  let items = [milestone(1, Ready), milestone(2, Active)]

  selection.selected_progress(items, opt.None)
  |> assert_selected_id(2)
}

pub fn milestones_selection_uses_ready_when_no_active_test() {
  let items = [milestone(1, Completed), milestone(2, Ready)]

  selection.selected_progress(items, opt.None)
  |> assert_selected_id(2)
}

pub fn milestones_selection_uses_first_item_when_no_active_or_ready_test() {
  let items = [milestone(1, Completed), milestone(2, Completed)]

  selection.selected_progress(items, opt.None)
  |> assert_selected_id(1)
}

pub fn milestones_selection_returns_none_for_empty_list_test() {
  let assert opt.None = selection.selected_progress([], opt.None)
}
