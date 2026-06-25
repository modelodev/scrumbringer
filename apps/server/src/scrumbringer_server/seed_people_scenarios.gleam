//// People QA seed scenario.
////
//// Creates focused People fixtures for distributed ownership, overloaded
//// members, blocked claimed work, ongoing work, and available support intake.

import domain/card
import domain/task/state as task_state
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import pog
import scrumbringer_server/seed_db

pub type Context {
  Context(
    admin_id: Int,
    active_project_ids: List(Int),
    task_type_ids: List(#(Int, Int, Int, Int)),
    project_member_ids: List(#(Int, List(Int))),
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

pub type PeopleResult {
  PeopleResult(
    project_id: Option(Int),
    card_ids: List(Int),
    task_seeds: List(TaskSeed),
  )
}

pub fn build(
  db: pog.Connection,
  context: Context,
) -> Result(PeopleResult, String) {
  case context.active_project_ids {
    [] -> Ok(PeopleResult(project_id: None, card_ids: [], task_seeds: []))
    [project_id, ..] -> {
      case task_types_for_project(context.task_type_ids, project_id) {
        None -> Ok(PeopleResult(project_id: None, card_ids: [], task_seeds: []))
        Some(#(bug_id, feature_id, task_id)) ->
          build_for_project(
            db,
            context,
            project_id,
            bug_id,
            feature_id,
            task_id,
          )
      }
    }
  }
}

fn build_for_project(
  db: pog.Connection,
  context: Context,
  project_id: Int,
  bug_id: Int,
  feature_id: Int,
  task_id: Int,
) -> Result(PeopleResult, String) {
  let members = members_for_project(context.project_member_ids, project_id)
  let non_admins =
    list.filter(members, fn(user_id) { user_id != context.admin_id })
  let api_owner = list_at_int(non_admins, 0, context.admin_id)
  let blocked_owner = list_at_int(non_admins, 1, context.admin_id)
  let loaded_owner = list_at_int(non_admins, 2, context.admin_id)
  let review_owner = list_at_int(non_admins, 3, context.admin_id)
  let support_owner = list_at_int(non_admins, 4, context.admin_id)

  use coordination_id <- result.try(insert_seed_root_card(
    db,
    context.admin_id,
    project_id,
    "People QA - Coordination stream",
    Some(
      "Active people-coordination fixture with distributed claimed, ongoing, blocked and free-person states.",
    ),
    card.Active,
    3,
    Some(days_ago_timestamp(2)),
    None,
  ))
  use api_id <- result.try(insert_seed_child_card(
    db,
    context.admin_id,
    project_id,
    coordination_id,
    "People QA - API handoff",
    Some("Task leaf for API handoff coordination."),
    card.Active,
    2,
    Some(days_ago_timestamp(2)),
    None,
  ))
  use ui_id <- result.try(insert_seed_child_card(
    db,
    context.admin_id,
    project_id,
    coordination_id,
    "People QA - UI polish",
    Some("Task leaf for UI polish coordination."),
    card.Active,
    2,
    Some(days_ago_timestamp(2)),
    None,
  ))
  use release_id <- result.try(insert_seed_child_card(
    db,
    context.admin_id,
    project_id,
    coordination_id,
    "People QA - Release readiness",
    Some("Task leaf for release readiness coordination."),
    card.Active,
    2,
    Some(days_ago_timestamp(2)),
    None,
  ))
  use support_id <- result.try(insert_seed_child_card(
    db,
    context.admin_id,
    project_id,
    coordination_id,
    "People QA - Review support",
    Some("Task leaf for review and support load distribution."),
    card.Active,
    2,
    Some(days_ago_timestamp(2)),
    None,
  ))

  use admin_ongoing <- result.try(insert_people_task(
    db,
    project_id,
    release_id,
    task_id,
    "People QA - Facilitate rollout sync",
    claimed_state_template(task_state.Ongoing),
    context.admin_id,
    Some(context.admin_id),
    4,
    2,
  ))
  use api_ongoing <- result.try(insert_people_task(
    db,
    project_id,
    api_id,
    bug_id,
    "People QA - API handoff ongoing",
    claimed_state_template(task_state.Ongoing),
    context.admin_id,
    Some(api_owner),
    5,
    2,
  ))
  use api_claimed <- result.try(insert_people_task(
    db,
    project_id,
    api_id,
    task_id,
    "People QA - API cleanup claimed",
    claimed_state_template(task_state.Taken),
    context.admin_id,
    Some(api_owner),
    3,
    1,
  ))
  use release_blocker <- result.try(insert_people_task(
    db,
    project_id,
    release_id,
    task_id,
    "People QA - Release checklist blocker",
    task_state.Available,
    context.admin_id,
    None,
    4,
    1,
  ))
  use blocked_claim <- result.try(insert_people_task(
    db,
    project_id,
    release_id,
    feature_id,
    "People QA - Blocked deploy approval",
    claimed_state_template(task_state.Taken),
    context.admin_id,
    Some(blocked_owner),
    5,
    1,
  ))
  use _ <- result.try(seed_db.insert_task_dependency(
    db,
    blocked_claim.task_id,
    release_blocker.task_id,
    context.admin_id,
  ))
  use loaded_one <- result.try(insert_people_task(
    db,
    project_id,
    ui_id,
    feature_id,
    "People QA - Polish empty state copy",
    claimed_state_template(task_state.Taken),
    context.admin_id,
    Some(loaded_owner),
    3,
    2,
  ))
  use loaded_two <- result.try(insert_people_task(
    db,
    project_id,
    ui_id,
    feature_id,
    "People QA - Polish mobile wrapping",
    claimed_state_template(task_state.Taken),
    context.admin_id,
    Some(loaded_owner),
    3,
    2,
  ))
  use loaded_three <- result.try(insert_people_task(
    db,
    project_id,
    ui_id,
    bug_id,
    "People QA - Verify filter contrast",
    claimed_state_template(task_state.Taken),
    context.admin_id,
    Some(loaded_owner),
    2,
    1,
  ))
  use loaded_four <- result.try(insert_people_task(
    db,
    project_id,
    ui_id,
    task_id,
    "People QA - Review scope labels",
    claimed_state_template(task_state.Taken),
    context.admin_id,
    Some(loaded_owner),
    2,
    1,
  ))
  use review_ongoing <- result.try(insert_people_task(
    db,
    project_id,
    support_id,
    feature_id,
    "People QA - Review dependency notes",
    claimed_state_template(task_state.Ongoing),
    context.admin_id,
    Some(review_owner),
    4,
    2,
  ))
  use review_claimed <- result.try(insert_people_task(
    db,
    project_id,
    support_id,
    bug_id,
    "People QA - Review blocked owner summary",
    claimed_state_template(task_state.Taken),
    context.admin_id,
    Some(review_owner),
    3,
    1,
  ))
  use support_claimed <- result.try(insert_people_task(
    db,
    project_id,
    support_id,
    task_id,
    "People QA - Support async handoff",
    claimed_state_template(task_state.Taken),
    context.admin_id,
    Some(support_owner),
    2,
    1,
  ))
  use support_available <- result.try(insert_people_task(
    db,
    project_id,
    support_id,
    task_id,
    "People QA - Support intake available",
    task_state.Available,
    context.admin_id,
    None,
    2,
    1,
  ))

  Ok(
    PeopleResult(
      project_id: Some(project_id),
      card_ids: [
        coordination_id,
        api_id,
        ui_id,
        release_id,
        support_id,
      ],
      task_seeds: [
        admin_ongoing,
        api_ongoing,
        api_claimed,
        release_blocker,
        blocked_claim,
        loaded_one,
        loaded_two,
        loaded_three,
        loaded_four,
        review_ongoing,
        review_claimed,
        support_claimed,
        support_available,
      ],
    ),
  )
}

fn insert_people_task(
  db: pog.Connection,
  project_id: Int,
  card_id: Int,
  type_id: Int,
  title: String,
  execution_state: task_state.TaskExecutionState,
  created_by: Int,
  claimed_by: Option(Int),
  priority: Int,
  created_days_ago: Int,
) -> Result(TaskSeed, String) {
  let created_at = days_ago_timestamp(created_days_ago)
  let #(claimed_by, claimed_at, completed_at) = case execution_state {
    task_state.Claimed(..) -> #(
      claimed_by,
      Some(days_ago_timestamp(int.max(1, created_days_ago - 1))),
      None,
    )
    task_state.Closed(..) -> #(
      None,
      None,
      Some(days_ago_timestamp(int.max(1, created_days_ago - 1))),
    )
    task_state.Available -> #(None, None, None)
  }
  let hydrated_execution_state =
    hydrate_seed_execution_state(
      execution_state,
      created_by,
      claimed_by,
      claimed_at,
      completed_at,
    )

  use task_id <- result.try(seed_db.insert_task(
    db,
    seed_db.TaskInsertOptions(
      project_id: project_id,
      type_id: type_id,
      title: title,
      description: "People QA fixture task",
      priority: priority,
      execution_state: hydrated_execution_state,
      created_by: created_by,
      card_id: Some(card_id),
      created_from_rule_id: None,
      pool_lifetime_s: 3600 * created_days_ago,
      due_date: None,
      created_at: Some(created_at),
      last_entered_pool_at: Some(created_at),
    ),
  ))

  Ok(TaskSeed(
    task_id: task_id,
    project_id: project_id,
    execution_state: hydrated_execution_state,
    created_at: created_at,
    created_by: created_by,
    claimed_by: claimed_by,
  ))
}

fn insert_seed_root_card(
  db: pog.Connection,
  admin_id: Int,
  project_id: Int,
  name: String,
  description: Option(String),
  root_card_state: card.CardPhase,
  created_days_ago: Int,
  activated_at: Option(String),
  completed_at: Option(String),
) -> Result(Int, String) {
  seed_db.insert_root_card(
    db,
    seed_db.RootCardInsertOptions(
      project_id: project_id,
      name: name,
      description: description,
      state: root_card_state,
      created_by: admin_id,
      created_at: Some(days_ago_timestamp(created_days_ago)),
      activated_at: activated_at,
      completed_at: completed_at,
    ),
  )
}

fn insert_seed_child_card(
  db: pog.Connection,
  admin_id: Int,
  project_id: Int,
  parent_card_id: Int,
  name: String,
  description: Option(String),
  child_card_state: card.CardPhase,
  created_days_ago: Int,
  activated_at: Option(String),
  completed_at: Option(String),
) -> Result(Int, String) {
  use child_id <- result.try(insert_seed_root_card(
    db,
    admin_id,
    project_id,
    name,
    description,
    child_card_state,
    created_days_ago,
    activated_at,
    completed_at,
  ))
  use _ <- result.try(seed_db.assign_card_to_parent_card(
    db,
    child_id,
    parent_card_id,
  ))
  Ok(child_id)
}

fn task_types_for_project(
  task_type_ids: List(#(Int, Int, Int, Int)),
  project_id: Int,
) -> Option(#(Int, Int, Int)) {
  case
    list.find(task_type_ids, fn(entry) {
      let #(pid, _bug, _feature, _task) = entry
      pid == project_id
    })
  {
    Ok(#(_pid, bug_id, feature_id, task_id)) ->
      Some(#(bug_id, feature_id, task_id))
    Error(_) -> None
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
