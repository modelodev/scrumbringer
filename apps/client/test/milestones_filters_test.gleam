import gleam/option.{None, Some}

import domain/milestone.{
  type MilestoneState, Active, Completed, Milestone, MilestoneProgress, Ready,
}
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/milestones/filters

fn progress(
  id: Int,
  name: String,
  project_id: Int,
  state: MilestoneState,
  cards_total: Int,
  tasks_total: Int,
) {
  MilestoneProgress(
    milestone: Milestone(
      id: id,
      project_id: project_id,
      name: name,
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

fn config(search_query, show_completed, show_empty) {
  filters.Config(
    search_query: search_query,
    show_completed: show_completed,
    show_empty: show_empty,
  )
}

pub fn milestones_filters_searches_case_insensitive_with_trim_test() {
  let items = [
    progress(1, "Discovery Slice", 1, Ready, 1, 0),
    progress(2, "Delivery Plan", 1, Active, 1, 0),
  ]

  let filtered = filters.apply(items, config("  slice  ", True, True))

  let assert [item] = filtered
  let assert 1 = item.milestone.id
}

pub fn milestones_filters_hide_completed_when_disabled_test() {
  let items = [
    progress(1, "Ready milestone", 1, Ready, 1, 0),
    progress(2, "Completed milestone", 1, Completed, 1, 0),
  ]

  let filtered = filters.apply(items, config("", False, True))

  let assert [item] = filtered
  let assert 1 = item.milestone.id
}

pub fn milestones_filters_hide_empty_when_disabled_test() {
  let items = [
    progress(1, "Empty milestone", 1, Ready, 0, 0),
    progress(2, "Loose task milestone", 1, Ready, 0, 2),
    progress(3, "Card milestone", 1, Ready, 1, 0),
  ]

  let filtered = filters.apply(items, config("", True, False))

  let assert [loose, card] = filtered
  let assert 2 = loose.milestone.id
  let assert 3 = card.milestone.id
}

pub fn milestones_filters_by_project_keeps_only_selected_project_test() {
  let items = [
    progress(1, "Project one", 1, Ready, 1, 0),
    progress(2, "Project two", 2, Ready, 1, 0),
    progress(3, "Project one again", 1, Ready, 1, 0),
  ]

  let filtered = filters.by_project(items, Some(1))

  let assert [first, second] = filtered
  let assert 1 = first.milestone.id
  let assert 3 = second.milestone.id
}

pub fn milestones_filters_by_project_keeps_all_without_selected_project_test() {
  let items = [
    progress(1, "Project one", 1, Ready, 1, 0),
    progress(2, "Project two", 2, Ready, 1, 0),
  ]

  let filtered = filters.by_project(items, None)

  let assert [first, second] = filtered
  let assert 1 = first.milestone.id
  let assert 2 = second.milestone.id
}

pub fn milestones_filters_toggle_show_completed_state_test() {
  let model = member_pool.default_model()

  let next = filters.toggle_show_completed(model)

  let assert True = next.member_milestones_show_completed
}

pub fn milestones_filters_toggle_show_empty_state_test() {
  let model = member_pool.default_model()

  let next = filters.toggle_show_empty(model)

  let assert True = next.member_milestones_show_empty
}

pub fn milestones_filters_set_search_query_state_test() {
  let model = member_pool.default_model()

  let next = filters.set_search_query(model, "release")

  let assert "release" = next.member_milestones_search_query
}
