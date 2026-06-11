import gleam/option as opt
import gleam/string
import lustre/element
import lustre/element/html

import domain/milestone.{
  type MilestoneProgress, type MilestoneState, Active, Milestone,
  MilestoneProgress, Ready,
}
import scrumbringer_client/features/milestones/content_pane
import scrumbringer_client/features/milestones/list_pane
import scrumbringer_client/i18n/locale
import scrumbringer_client/ui/badge

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

fn progress(id: Int, state: MilestoneState) -> MilestoneProgress {
  MilestoneProgress(
    milestone: Milestone(
      id: id,
      project_id: 1,
      name: "Milestone",
      description: opt.Some("Delivery slice"),
      state: state,
      position: id,
      created_by: 1,
      created_at: "2026-02-06T00:00:00Z",
      activated_at: opt.None,
      completed_at: opt.None,
    ),
    cards_total: 2,
    cards_completed: 1,
    tasks_total: 4,
    tasks_completed: 2,
  )
}

fn state_label(state: MilestoneState) -> String {
  case state {
    Active -> "Active"
    Ready -> "Ready"
    _ -> "Done"
  }
}

fn state_variant(_state: MilestoneState) -> badge.BadgeVariant {
  badge.Primary
}

pub fn list_pane_renders_from_config_without_root_model_test() {
  let html =
    list_pane.view(list_pane.Config(
      locale: locale.En,
      items: [progress(1, Active), progress(2, Ready)],
      selected_id: opt.Some(1),
      search_query: "mile",
      show_completed: False,
      show_empty: True,
      on_search_change: fn(value) { "search:" <> value },
      on_toggle_completed: "toggle-completed",
      on_toggle_empty: "toggle-empty",
      on_select: fn(_) { "select" },
      loose_tasks_count: fn(_) { 3 },
      empty_cards_count: fn(_) { 0 },
      milestone_state_label: state_label,
      milestone_state_variant: state_variant,
    ))
    |> element.to_document_string

  assert_contains(html, "Milestone")
  assert_contains(html, "Active")
  assert_contains(html, "3 loose tasks")
  assert_not_contains(html, "Completed")
}

pub fn content_pane_renders_from_config_without_root_model_test() {
  let item = progress(1, Ready)
  let html =
    content_pane.view(
      content_pane.Config(
        locale: locale.En,
        progress: item,
        tasks_in_cards: 2,
        loose_tasks: 3,
        blocked_tasks: 1,
        empty_cards: 0,
        cards_section: html.div([], [html.text("cards section")]),
        loose_tasks_panel: html.div([], [html.text("loose tasks")]),
        actions: [],
        metrics_summary: html.div([], [html.text("metrics summary")]),
        summary_expanded: True,
        on_summary_toggle: "toggle-summary",
        milestone_state_label: state_label,
        milestone_state_variant: state_variant,
        progress_percentage: fn(_) { 50 },
      ),
    )
    |> element.to_document_string

  assert_contains(html, "Milestone")
  assert_contains(html, "Delivery slice")
  assert_contains(html, "milestone-structure-strip")
  assert_contains(html, "Cards 1/2")
  assert_contains(html, "2 tasks in cards")
  assert_contains(html, "3 loose tasks")
  assert_contains(html, "1 blocked tasks")
  assert_contains(html, "metrics summary")
}
