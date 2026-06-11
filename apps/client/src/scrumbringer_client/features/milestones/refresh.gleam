//// Pure member-milestone refresh derivations for multi-project fetches.

import gleam/list
import gleam/option as opt

import domain/api_error.{type ApiError}
import domain/milestone.{type MilestoneProgress, Active, Ready}
import domain/remote.{type Remote, Failed, Loaded, Loading}
import scrumbringer_client/state/normalized_store as store

pub type ProjectFetched {
  ProjectFetched(
    milestones_store: store.NormalizedStore(Int, MilestoneProgress),
    milestones: Remote(List(MilestoneProgress)),
    selected_milestone_id: opt.Option(Int),
  )
}

pub fn mark_pending(
  milestones_store: store.NormalizedStore(Int, MilestoneProgress),
  project_count: Int,
) -> store.NormalizedStore(Int, MilestoneProgress) {
  store.with_pending(milestones_store, project_count)
}

pub fn loading_unless_loaded(
  milestones: Remote(List(MilestoneProgress)),
) -> Remote(List(MilestoneProgress)) {
  case milestones {
    Loaded(_) -> milestones
    _ -> Loading
  }
}

pub fn project_fetched(
  milestones_store: store.NormalizedStore(Int, MilestoneProgress),
  current: Remote(List(MilestoneProgress)),
  current_selected_id: opt.Option(Int),
  project_id: Int,
  milestones: List(MilestoneProgress),
) -> ProjectFetched {
  let next_store =
    milestones_store
    |> store.upsert(project_id, milestones, milestone_id)
    |> store.decrement_pending
  let next_milestones = case store.is_ready(next_store) {
    True -> Loaded(store.to_list(next_store))
    False -> current
  }
  let next_selected_id =
    keep_selected_milestone(next_milestones, current_selected_id)

  ProjectFetched(
    milestones_store: next_store,
    milestones: next_milestones,
    selected_milestone_id: next_selected_id,
  )
}

pub fn project_failed(
  milestones_store: store.NormalizedStore(Int, MilestoneProgress),
  current: Remote(List(MilestoneProgress)),
  err: ApiError,
) -> #(
  store.NormalizedStore(Int, MilestoneProgress),
  Remote(List(MilestoneProgress)),
) {
  let next_store = store.decrement_pending(milestones_store)
  let next_milestones = case current {
    Loaded(_) -> current
    _ -> Failed(err)
  }

  #(next_store, next_milestones)
}

fn keep_selected_milestone(
  milestones: Remote(List(MilestoneProgress)),
  selected: opt.Option(Int),
) -> opt.Option(Int) {
  case milestones, selected {
    Loaded(items), opt.Some(selected_id) ->
      case
        list.any(items, fn(progress) { milestone_id(progress) == selected_id })
      {
        True -> selected
        False -> default_selected_milestone(items)
      }
    Loaded(items), opt.None -> default_selected_milestone(items)
    _, _ -> selected
  }
}

fn default_selected_milestone(items: List(MilestoneProgress)) -> opt.Option(Int) {
  case list.find(items, fn(progress) { progress.milestone.state == Active }) {
    Ok(progress) -> opt.Some(milestone_id(progress))
    Error(_) ->
      case
        list.find(items, fn(progress) { progress.milestone.state == Ready })
      {
        Ok(progress) -> opt.Some(milestone_id(progress))
        Error(_) ->
          list.first(items)
          |> opt.from_result
          |> opt.map(milestone_id)
      }
  }
}

fn milestone_id(progress: MilestoneProgress) -> Int {
  progress.milestone.id
}
