//// Base task seed scenario.
////
//// Creates project tasks with card attachment, execution-state distribution,
//// workflow provenance, and pool lifetime coverage for product validation.

import domain/task/state as task_state
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import pog
import scrumbringer_server/seed_db
import scrumbringer_server/seed_pools

pub type StatusDistribution {
  StatusDistribution(available: Int, claimed: Int, completed: Int)
}

pub type Context {
  Context(
    admin_id: Int,
    user_ids: List(Int),
    active_task_types: List(#(Int, Int, Int, Int)),
    card_ids_by_project: List(#(Int, List(Int))),
    project_member_ids: List(#(Int, List(Int))),
    rule_ids_by_project: List(#(Int, List(Int))),
    tasks_per_project: Int,
    priority_distribution: List(Int),
    status_distribution: StatusDistribution,
    empty_card_count: Int,
    date_range_days: Int,
  )
}

pub type TaskSeed {
  TaskSeed(
    task_id: Int,
    project_id: Int,
    execution_state: task_state.TaskExecutionState,
    created_at: String,
    created_by: Int,
    claimed_by: Option(Int),
  )
}

pub type TaskResult {
  TaskResult(task_ids: List(Int), task_seeds: List(TaskSeed))
}

pub fn build(db: pog.Connection, context: Context) -> Result(TaskResult, String) {
  let titles = seed_pools.task_titles()
  let execution_state_pool =
    execution_state_pool_from(context.status_distribution)

  use task_results_nested <- result.try(
    list.index_map(context.active_task_types, fn(types, project_idx) {
      let #(project_id, bug_id, feature_id, task_id) = types
      let cards = cards_for_project(context.card_ids_by_project, project_id)
      let usable_cards = case context.empty_card_count > 0 {
        True -> list.drop(cards, context.empty_card_count)
        False -> cards
      }

      let card_all_done = list_at_int(usable_cards, 0, 0)
      let card_mixed = list_at_int(usable_cards, 1, 0)
      let card_single = list_at_int(usable_cards, 2, 0)

      let base_idx = project_idx * context.tasks_per_project
      let title_for = fn(idx, fallback) {
        let base = list_at(titles, idx, fallback)
        "P"
        <> int.to_string(project_id)
        <> " - "
        <> base
        <> " #"
        <> int.to_string(idx + 1)
      }

      let creator_id =
        list_at_int(context.user_ids, project_idx, context.admin_id)
      let claimed_user_id =
        claimed_member_id(
          context.project_member_ids,
          context.admin_id,
          project_id,
          creator_id,
        )
      let members = members_for_project(context.project_member_ids, project_id)
      let project_rule_ids =
        rule_ids_for_project(context.rule_ids_by_project, project_id)
      let base_days = int.max(1, context.date_range_days - { project_idx * 3 })

      let base_tasks = [
        #(
          title_for(base_idx, "Task A"),
          bug_id,
          done_state_template(),
          Some(card_all_done),
        ),
        #(
          title_for(base_idx + 1, "Task B"),
          feature_id,
          done_state_template(),
          Some(card_all_done),
        ),
        #(
          title_for(base_idx + 2, "Task C"),
          bug_id,
          done_state_template(),
          Some(card_mixed),
        ),
        #(
          title_for(base_idx + 3, "Task D"),
          feature_id,
          claimed_state_template(task_state.Taken),
          Some(card_mixed),
        ),
        #(
          title_for(base_idx + 4, "Task E"),
          task_id,
          task_state.Available,
          Some(card_single),
        ),
        #(title_for(base_idx + 5, "Task F"), bug_id, task_state.Available, None),
        #(
          title_for(base_idx + 6, "Task G"),
          feature_id,
          task_state.Available,
          None,
        ),
      ]

      let extra_tasks =
        extra_task_indexes(context.tasks_per_project, list.length(base_tasks))
        |> list.map(fn(extra_idx) {
          let idx = base_idx + list.length(base_tasks) + extra_idx
          let type_id = case extra_idx % 3 {
            0 -> bug_id
            1 -> feature_id
            _ -> task_id
          }
          let execution_state =
            execution_state_from_pool(execution_state_pool, idx)
          let card_id = case extra_idx % 4 {
            0 -> Some(card_mixed)
            1 -> Some(card_single)
            _ -> None
          }
          #(title_for(idx, "Task Extra"), type_id, execution_state, card_id)
        })

      list.index_map(list.append(base_tasks, extra_tasks), fn(task_def, idx) {
        let #(title, type_id, execution_state, card_id) = task_def
        let priority =
          list_at_int(
            context.priority_distribution,
            idx % list.length(context.priority_distribution),
            3,
          )
        let creator_for = list_at_int(context.user_ids, idx, context.admin_id)
        let claimed_user_for = member_for_index(members, idx, claimed_user_id)
        let created_from_rule_id = seeded_rule_for_task(project_rule_ids, idx)
        let pool_lifetime_s =
          seeded_pool_lifetime_s(execution_state, idx, project_idx)
        let last_entered_pool_at =
          seeded_last_entered_pool_at(
            execution_state,
            pool_lifetime_s,
            base_days,
            idx,
          )
        let #(claimed_by, claimed_at, completed_at) = case execution_state {
          task_state.Claimed(..) -> #(
            Some(claimed_user_for),
            Some(days_ago_timestamp(int.max(1, base_days - { idx % 7 }))),
            None,
          )
          task_state.Closed(..) -> #(
            None,
            None,
            Some(days_ago_timestamp(int.max(1, base_days - { idx % 11 }))),
          )
          task_state.Available -> #(None, None, None)
        }
        let hydrated_execution_state =
          hydrate_seed_execution_state(
            execution_state,
            creator_for,
            claimed_by,
            claimed_at,
            completed_at,
          )
        let created_at =
          days_ago_timestamp(int.max(1, base_days - { idx % 13 }))

        seed_db.insert_task(
          db,
          seed_db.TaskInsertOptions(
            project_id: project_id,
            type_id: type_id,
            title: title,
            description: "Seeded task",
            priority: priority,
            execution_state: hydrated_execution_state,
            created_by: creator_for,
            card_id: card_id,
            created_from_rule_id: created_from_rule_id,
            pool_lifetime_s: pool_lifetime_s,
            due_date: None,
            created_at: Some(created_at),
            last_entered_pool_at: last_entered_pool_at,
          ),
        )
        |> result.map(fn(task_id) {
          TaskSeed(
            task_id: task_id,
            project_id: project_id,
            execution_state: hydrated_execution_state,
            created_at: created_at,
            created_by: creator_for,
            claimed_by: claimed_by,
          )
        })
      })
      |> result.all
    })
    |> result.all,
  )

  let task_seeds = list.flatten(task_results_nested)
  let task_ids = list.map(task_seeds, fn(seed) { seed.task_id })

  Ok(TaskResult(task_ids: task_ids, task_seeds: task_seeds))
}

fn extra_task_indexes(tasks_per_project: Int, base_task_count: Int) -> List(Int) {
  let extra_count = int.max(0, tasks_per_project - base_task_count)
  case extra_count > 0 {
    True -> list.range(0, extra_count - 1)
    False -> []
  }
}

fn members_for_project(
  project_members: List(#(Int, List(Int))),
  project_id: Int,
) -> List(Int) {
  case
    list.find(project_members, fn(pair) {
      let #(pid, _members) = pair
      pid == project_id
    })
  {
    Ok(#(_pid, members)) -> members
    Error(_) -> []
  }
}

fn cards_for_project(
  card_ids_by_project: List(#(Int, List(Int))),
  project_id: Int,
) -> List(Int) {
  case
    list.find(card_ids_by_project, fn(pair) {
      let #(pid, _cards) = pair
      pid == project_id
    })
  {
    Ok(#(_pid, cards)) -> cards
    Error(_) -> []
  }
}

fn claimed_member_id(
  project_members: List(#(Int, List(Int))),
  admin_id: Int,
  project_id: Int,
  fallback: Int,
) -> Int {
  let members = members_for_project(project_members, project_id)
  let non_admins = list.filter(members, fn(user_id) { user_id != admin_id })
  case non_admins {
    [first, ..] -> first
    [] -> fallback
  }
}

fn rule_ids_for_project(
  rule_ids_by_project: List(#(Int, List(Int))),
  project_id: Int,
) -> List(Int) {
  case
    list.find(rule_ids_by_project, fn(pair) {
      let #(pid, _rule_ids) = pair
      pid == project_id
    })
  {
    Ok(#(_pid, rule_ids)) -> rule_ids
    Error(_) -> []
  }
}

fn seeded_rule_for_task(
  project_rule_ids: List(Int),
  task_idx: Int,
) -> Option(Int) {
  case project_rule_ids {
    [] -> None
    _ ->
      case task_idx % 5 == 0 {
        // Keep a stable "sin workflow" bucket for metrics tabs.
        True -> None
        False -> {
          let rule_idx = task_idx % list.length(project_rule_ids)
          Some(list_at_int(project_rule_ids, rule_idx, 0))
        }
      }
  }
}

fn seeded_pool_lifetime_s(
  execution_state: task_state.TaskExecutionState,
  task_idx: Int,
  project_idx: Int,
) -> Int {
  let base_idx = task_idx + project_idx
  let base = case base_idx % 4 {
    0 -> 0
    1 -> 900
    2 -> 3600
    _ -> 14_400
  }

  case execution_state {
    task_state.Available -> base
    task_state.Claimed(..) -> int.max(300, base)
    task_state.Closed(..) -> int.max(900, base)
  }
}

fn seeded_last_entered_pool_at(
  execution_state: task_state.TaskExecutionState,
  pool_lifetime_s: Int,
  base_days: Int,
  task_idx: Int,
) -> Option(String) {
  case execution_state {
    task_state.Available ->
      case pool_lifetime_s > 0 {
        True ->
          Some(days_ago_timestamp(int.max(1, base_days - { task_idx % 5 })))
        False -> None
      }
    task_state.Claimed(..) | task_state.Closed(..) -> None
  }
}

fn execution_state_pool_from(
  distribution: StatusDistribution,
) -> List(task_state.TaskExecutionState) {
  let StatusDistribution(
    available: available,
    claimed: claimed,
    completed: completed,
  ) = distribution
  list.append(
    repeat_value(task_state.Available, available),
    list.append(
      repeat_value(claimed_state_template(task_state.Taken), claimed),
      repeat_value(done_state_template(), completed),
    ),
  )
}

fn execution_state_from_pool(
  pool: List(task_state.TaskExecutionState),
  idx: Int,
) -> task_state.TaskExecutionState {
  case pool {
    [] -> task_state.Available
    _ -> list_at_helper(pool, idx % list.length(pool), task_state.Available)
  }
}

fn repeat_value(value: a, count: Int) -> List(a) {
  case count <= 0 {
    True -> []
    False -> [value, ..repeat_value(value, count - 1)]
  }
}

fn member_for_index(members: List(Int), idx: Int, fallback: Int) -> Int {
  list_at_int(members, idx % int.max(1, list.length(members)), fallback)
}

fn hydrate_seed_execution_state(
  execution_state: task_state.TaskExecutionState,
  created_by: Int,
  claimed_by: Option(Int),
  claimed_at: Option(String),
  completed_at: Option(String),
) -> task_state.TaskExecutionState {
  case execution_state {
    task_state.Available -> task_state.Available
    task_state.Claimed(mode: mode, ..) ->
      task_state.Claimed(
        claimed_by: option_int(claimed_by, created_by),
        claimed_at: option_string(claimed_at, "NOW()"),
        mode: mode,
      )
    task_state.Closed(reason: reason, ..) ->
      task_state.Closed(
        reason: reason,
        closed_at: option_string(completed_at, "NOW()"),
        closed_by: created_by,
      )
  }
}

fn claimed_state_template(
  mode: task_state.TaskClaimMode,
) -> task_state.TaskExecutionState {
  task_state.Claimed(claimed_by: 0, claimed_at: "", mode: mode)
}

fn done_state_template() -> task_state.TaskExecutionState {
  task_state.Closed(reason: task_state.Done, closed_at: "", closed_by: 0)
}

fn option_int(value: Option(Int), default: Int) -> Int {
  case value {
    Some(inner) -> inner
    None -> default
  }
}

fn option_string(value: Option(String), default: String) -> String {
  case value {
    Some(inner) -> inner
    None -> default
  }
}

fn days_ago_timestamp(days: Int) -> String {
  "NOW() - INTERVAL '" <> int.to_string(days) <> " days'"
}

fn list_at(items: List(String), idx: Int, default: String) -> String {
  list_at_helper(items, idx, default)
}

fn list_at_int(items: List(Int), idx: Int, default: Int) -> Int {
  list_at_helper(items, idx, default)
}

fn list_at_helper(items: List(a), idx: Int, default: a) -> a {
  case idx, items {
    _, [] -> default
    0, [first, ..] -> first
    n, [_, ..rest] -> list_at_helper(rest, n - 1, default)
  }
}
