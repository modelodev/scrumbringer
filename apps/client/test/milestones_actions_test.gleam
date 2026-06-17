import gleam/int
import gleam/option.{None}
import gleam/string
import lustre/element

import domain/milestone.{
  type MilestoneProgress, type MilestoneState, Active, Milestone,
  MilestoneProgress, Ready,
}
import scrumbringer_client/features/milestones/actions
import scrumbringer_client/i18n/locale

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

fn progress(id: Int, state: MilestoneState) {
  progress_with_counts(id, state, cards_total: 1, tasks_total: 1)
}

fn progress_with_counts(
  id: Int,
  state: MilestoneState,
  cards_total cards_total: Int,
  tasks_total tasks_total: Int,
) {
  MilestoneProgress(
    milestone: Milestone(
      id: id,
      project_id: 1,
      name: "Milestone " <> int.to_string(id),
      description: None,
      state: state,
      position: id,
      created_by: 1,
      created_at: "2026-02-06T00:00:00Z",
      activated_at: None,
      completed_at: None,
    ),
    cards_total: cards_total,
    cards_completed: 0,
    tasks_total: tasks_total,
    tasks_completed: 0,
  )
}

fn config(can_manage, state, has_other_active) -> actions.Config(String) {
  actions.Config(
    locale: locale.En,
    progress: progress(42, state),
    can_manage: can_manage,
    activation_in_flight: False,
    has_other_active: has_other_active,
    on_quick_create_card: fn(id) { "quick-card:" <> int.to_string(id) },
    on_quick_create_task: fn(id) { "quick-task:" <> int.to_string(id) },
    on_activate_prompt: fn(id) { "activate:" <> int.to_string(id) },
    on_edit: fn(id) { "edit:" <> int.to_string(id) },
    on_delete: fn(id) { "delete:" <> int.to_string(id) },
  )
}

fn config_with_progress(progress: MilestoneProgress) -> actions.Config(String) {
  actions.Config(..config(True, Ready, False), progress: progress)
}

fn render(config: actions.Config(String)) -> String {
  actions.view(config)
  |> element.fragment
  |> element.to_document_string
}

pub fn milestones_actions_render_ready_management_actions_without_root_model_test() {
  let html = render(config(True, Ready, False))

  assert_contains(html, "milestone-quick-new-card:42")
  assert_contains(html, "milestone-quick-new-task:42")
  assert_contains(html, "milestone-activate-button:42")
  assert_contains(html, "milestone-edit-button:42")
  assert_contains(html, "milestone-delete-button:42")
  assert_contains(html, "aria-disabled=\"true\"")
  assert_contains(html, "Milestone must be ready and empty")
  assert_contains(html, "Activate")
}

pub fn milestones_actions_hide_management_actions_without_permission_test() {
  let html = render(config(False, Ready, False))

  assert_not_contains(html, "milestone-quick-new-card:42")
  assert_not_contains(html, "milestone-activate-button:42")
  assert_not_contains(html, "milestone-edit-button:42")
  assert_not_contains(html, "milestone-delete-button:42")
}

pub fn milestones_actions_hide_activation_when_another_milestone_active_test() {
  let html = render(config(True, Ready, True))

  assert_contains(html, "milestone-edit-button:42")
  assert_not_contains(html, "milestone-activate-button:42")
}

pub fn milestones_actions_block_delete_for_non_ready_milestone_test() {
  let html = render(config(True, Active, False))

  assert_contains(html, "milestone-edit-button:42")
  assert_contains(html, "milestone-delete-button:42")
  assert_contains(html, "btn-delete-blocked")
  assert_contains(html, "data-tooltip=\"Milestone must be ready and empty\"")
}

pub fn milestones_actions_allow_delete_for_ready_empty_milestone_test() {
  let html =
    progress_with_counts(42, Ready, cards_total: 0, tasks_total: 0)
    |> config_with_progress
    |> render

  assert_contains(html, "milestone-delete-button:42")
  assert_contains(html, "aria-label=\"Delete milestone\"")
  assert_not_contains(html, "btn-delete-blocked")
  assert_not_contains(html, "aria-disabled=\"true\"")
}
