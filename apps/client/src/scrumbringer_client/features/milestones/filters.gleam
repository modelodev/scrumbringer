//// Milestone list filters and filter state transitions.

import gleam/list
import gleam/option
import gleam/string

import domain/milestone.{type MilestoneProgress, Completed}
import scrumbringer_client/client_state/member/pool as member_pool

/// Current filter settings for the member milestone list.
pub type Config {
  Config(search_query: String, show_completed: Bool, show_empty: Bool)
}

/// Apply search, completed, and empty filters to a milestone progress list.
pub fn apply(
  items: List(MilestoneProgress),
  config: Config,
) -> List(MilestoneProgress) {
  items
  |> list.filter(fn(progress) { matches_search(progress, config.search_query) })
  |> list.filter(fn(progress) {
    config.show_completed || progress.milestone.state != Completed
  })
  |> list.filter(fn(progress) { config.show_empty || has_work(progress) })
}

pub fn by_project(
  items: List(MilestoneProgress),
  project_id: option.Option(Int),
) -> List(MilestoneProgress) {
  case project_id {
    option.Some(id) ->
      list.filter(items, fn(progress) { progress.milestone.project_id == id })
    option.None -> items
  }
}

pub fn toggle_show_completed(model: member_pool.Model) -> member_pool.Model {
  member_pool.Model(
    ..model,
    member_milestones_show_completed: !model.member_milestones_show_completed,
  )
}

pub fn toggle_show_empty(model: member_pool.Model) -> member_pool.Model {
  member_pool.Model(
    ..model,
    member_milestones_show_empty: !model.member_milestones_show_empty,
  )
}

pub fn set_search_query(
  model: member_pool.Model,
  query: String,
) -> member_pool.Model {
  member_pool.Model(..model, member_milestones_search_query: query)
}

fn matches_search(progress: MilestoneProgress, query: String) -> Bool {
  case string.trim(query) {
    "" -> True
    trimmed ->
      string.contains(
        string.lowercase(progress.milestone.name),
        string.lowercase(trimmed),
      )
  }
}

fn has_work(progress: MilestoneProgress) -> Bool {
  case progress.cards_total == 0 {
    True -> progress.tasks_total != 0
    False -> True
  }
}
