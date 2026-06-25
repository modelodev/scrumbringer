//// Plan QA seed scenario.
////
//// Creates focused Plan fixtures for direct-task cards, capability matrix
//// rows, blocked dependencies, due-date states, and draft activation impact.

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

pub type PlanResult {
  PlanResult(
    project_id: Option(Int),
    card_ids: List(Int),
    task_seeds: List(TaskSeed),
  )
}

pub fn build(db: pog.Connection, context: Context) -> Result(PlanResult, String) {
  case context.active_project_ids {
    [] -> Ok(PlanResult(project_id: None, card_ids: [], task_seeds: []))
    [project_id, ..] -> {
      case task_types_for_project(context.task_type_ids, project_id) {
        None -> Ok(PlanResult(project_id: None, card_ids: [], task_seeds: []))
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
) -> Result(PlanResult, String) {
  let member_id =
    claimed_member_id(
      context.project_member_ids,
      context.admin_id,
      project_id,
      context.admin_id,
    )
  use no_capability_type_id <- result.try(seed_db.insert_task_type(
    db,
    project_id,
    "Plan QA - No capability",
    "document-text",
  ))

  use direct_id <- result.try(insert_seed_root_card(
    db,
    context.admin_id,
    project_id,
    "Plan QA - Direct task card",
    Some(
      "Direct-task fixture for card-scope Kanban: no child cards, mixed statuses and a default-closed card scope.",
    ),
    card.Active,
    4,
    Some(days_ago_timestamp(3)),
    None,
  ))
  use matrix_id <- result.try(insert_seed_root_card(
    db,
    context.admin_id,
    project_id,
    "Plan QA - Multi-capability matrix",
    Some(
      "Capability-board fixture with child cards, empty matrix cells, no-capability tasks and an explicit blocked task.",
    ),
    card.Active,
    5,
    Some(days_ago_timestamp(4)),
    None,
  ))
  use closed_id <- result.try(insert_seed_root_card(
    db,
    context.admin_id,
    project_id,
    "Plan QA - Closed outcome",
    Some("Closed Plan fixture with completed work for show-closed validation."),
    card.Closed,
    18,
    Some(days_ago_timestamp(16)),
    Some(days_ago_timestamp(2)),
  ))
  use activation_impact_id <- result.try(insert_seed_root_card(
    db,
    context.admin_id,
    project_id,
    "Plan QA - Draft activation impact",
    Some(
      "Draft fixture with four prepared tasks so Plan can show a meaningful +4 activation impact.",
    ),
    card.Draft,
    8,
    Some(days_ago_timestamp(2)),
    None,
  ))

  use api_id <- result.try(insert_plan_qa_child_card(
    db,
    context.admin_id,
    project_id,
    matrix_id,
    "Plan QA - API lane",
    card.Blue,
  ))
  use ui_id <- result.try(insert_plan_qa_child_card(
    db,
    context.admin_id,
    project_id,
    matrix_id,
    "Plan QA - UI lane",
    card.Green,
  ))
  use docs_id <- result.try(insert_plan_qa_child_card(
    db,
    context.admin_id,
    project_id,
    matrix_id,
    "Plan QA - Docs lane",
    card.Purple,
  ))

  use direct_available <- result.try(insert_plan_qa_task_with_due(
    db,
    project_id,
    direct_id,
    bug_id,
    "Plan QA - Direct available backend",
    task_state.Available,
    context.admin_id,
    None,
    4,
    4,
    Some("CURRENT_DATE"),
  ))
  use direct_claimed <- result.try(insert_plan_qa_task(
    db,
    project_id,
    direct_id,
    feature_id,
    "Plan QA - Direct claimed frontend",
    claimed_state_template(task_state.Taken),
    context.admin_id,
    Some(member_id),
    5,
    3,
  ))
  use direct_closed <- result.try(insert_plan_qa_task(
    db,
    project_id,
    direct_id,
    no_capability_type_id,
    "Plan QA - Direct done no capability",
    closed_outcome_state_template(),
    context.admin_id,
    None,
    2,
    2,
  ))
  use api_available <- result.try(insert_plan_qa_task(
    db,
    project_id,
    api_id,
    bug_id,
    "Plan QA - API available",
    task_state.Available,
    context.admin_id,
    None,
    3,
    3,
  ))
  use api_dependency <- result.try(insert_plan_qa_task_with_due(
    db,
    project_id,
    api_id,
    task_id,
    "Plan QA - Missing contract dependency",
    task_state.Available,
    context.admin_id,
    None,
    5,
    2,
    Some("CURRENT_DATE + 3"),
  ))
  use api_blocked <- result.try(insert_plan_qa_task_with_due(
    db,
    project_id,
    api_id,
    feature_id,
    "Plan QA - Blocked integration",
    task_state.Available,
    context.admin_id,
    None,
    5,
    1,
    Some("CURRENT_DATE - 4"),
  ))
  use _ <- result.try(seed_db.insert_task_dependency(
    db,
    api_blocked.task_id,
    api_dependency.task_id,
    context.admin_id,
  ))
  use ui_ongoing <- result.try(insert_plan_qa_task(
    db,
    project_id,
    ui_id,
    feature_id,
    "Plan QA - UI ongoing",
    claimed_state_template(task_state.Ongoing),
    context.admin_id,
    Some(member_id),
    4,
    2,
  ))
  use docs_no_capability <- result.try(insert_plan_qa_task_with_due(
    db,
    project_id,
    docs_id,
    no_capability_type_id,
    "Plan QA - Docs no capability",
    task_state.Available,
    context.admin_id,
    None,
    2,
    1,
    Some("CURRENT_DATE + 5"),
  ))
  use pool_ready_due_today <- result.try(insert_pool_qa_task_with_due(
    db,
    project_id,
    bug_id,
    "Pool QA - Ready due today",
    task_state.Available,
    context.admin_id,
    None,
    4,
    1,
    Some("CURRENT_DATE"),
  ))
  use pool_dependency <- result.try(insert_pool_qa_task_with_due(
    db,
    project_id,
    task_id,
    "Pool QA - Blocking dependency",
    task_state.Available,
    context.admin_id,
    None,
    3,
    2,
    Some("CURRENT_DATE + 2"),
  ))
  use pool_blocked_overdue <- result.try(insert_pool_qa_task_with_due(
    db,
    project_id,
    feature_id,
    "Pool QA - Blocked overdue",
    task_state.Available,
    context.admin_id,
    None,
    5,
    1,
    Some("CURRENT_DATE - 2"),
  ))
  use _ <- result.try(seed_db.insert_task_dependency(
    db,
    pool_blocked_overdue.task_id,
    pool_dependency.task_id,
    context.admin_id,
  ))
  use closed_outcome_task <- result.try(insert_plan_qa_task(
    db,
    project_id,
    closed_id,
    task_id,
    "Plan QA - Closed done task",
    closed_outcome_state_template(),
    context.admin_id,
    None,
    1,
    2,
  ))
  use impact_backend <- result.try(insert_plan_qa_task(
    db,
    project_id,
    activation_impact_id,
    bug_id,
    "Plan QA - Draft impact backend",
    task_state.Available,
    context.admin_id,
    None,
    4,
    2,
  ))
  use impact_frontend <- result.try(insert_plan_qa_task(
    db,
    project_id,
    activation_impact_id,
    feature_id,
    "Plan QA - Draft impact frontend",
    task_state.Available,
    context.admin_id,
    None,
    4,
    2,
  ))
  use impact_qa <- result.try(insert_plan_qa_task(
    db,
    project_id,
    activation_impact_id,
    task_id,
    "Plan QA - Draft impact QA",
    task_state.Available,
    context.admin_id,
    None,
    3,
    2,
  ))
  use impact_docs <- result.try(insert_plan_qa_task(
    db,
    project_id,
    activation_impact_id,
    no_capability_type_id,
    "Plan QA - Draft impact docs",
    task_state.Available,
    context.admin_id,
    None,
    2,
    2,
  ))

  Ok(
    PlanResult(
      project_id: Some(project_id),
      card_ids: [
        direct_id,
        matrix_id,
        closed_id,
        activation_impact_id,
        api_id,
        ui_id,
        docs_id,
      ],
      task_seeds: [
        direct_available,
        direct_claimed,
        direct_closed,
        api_available,
        api_dependency,
        api_blocked,
        ui_ongoing,
        docs_no_capability,
        pool_ready_due_today,
        pool_dependency,
        pool_blocked_overdue,
        closed_outcome_task,
        impact_backend,
        impact_frontend,
        impact_qa,
        impact_docs,
      ],
    ),
  )
}

fn insert_plan_qa_child_card(
  db: pog.Connection,
  admin_id: Int,
  project_id: Int,
  parent_card_id: Int,
  title: String,
  color: card.CardColor,
) -> Result(Int, String) {
  use card_id <- result.try(seed_db.insert_card(
    db,
    seed_db.CardInsertOptions(
      project_id: project_id,
      title: title,
      description: "Plan QA child card for matrix row coverage.",
      color: Some(color),
      created_by: admin_id,
      created_at: Some(days_ago_timestamp(3)),
    ),
  ))
  use _ <- result.try(seed_db.assign_card_to_parent_card(
    db,
    card_id,
    parent_card_id,
  ))
  Ok(card_id)
}

fn insert_plan_qa_task(
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
  insert_plan_qa_task_with_due(
    db,
    project_id,
    card_id,
    type_id,
    title,
    execution_state,
    created_by,
    claimed_by,
    priority,
    created_days_ago,
    None,
  )
}

fn insert_plan_qa_task_with_due(
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
  due_date: Option(String),
) -> Result(TaskSeed, String) {
  let created_at = days_ago_timestamp(created_days_ago)
  let #(claimed_by, claimed_at, closed_at) = case execution_state {
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
      closed_at,
    )

  use task_id <- result.try(seed_db.insert_task(
    db,
    seed_db.TaskInsertOptions(
      project_id: project_id,
      type_id: type_id,
      title: title,
      description: "Plan QA fixture task",
      priority: priority,
      execution_state: hydrated_execution_state,
      created_by: created_by,
      card_id: Some(card_id),
      created_from_rule_id: None,
      pool_lifetime_s: 3600 * created_days_ago,
      due_date: due_date,
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

fn insert_pool_qa_task_with_due(
  db: pog.Connection,
  project_id: Int,
  type_id: Int,
  title: String,
  execution_state: task_state.TaskExecutionState,
  created_by: Int,
  claimed_by: Option(Int),
  priority: Int,
  created_days_ago: Int,
  due_date: Option(String),
) -> Result(TaskSeed, String) {
  let created_at = days_ago_timestamp(created_days_ago)
  let #(claimed_by, claimed_at, closed_at) = case execution_state {
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
      closed_at,
    )

  use task_id <- result.try(seed_db.insert_task(
    db,
    seed_db.TaskInsertOptions(
      project_id: project_id,
      type_id: type_id,
      title: title,
      description: "Pool QA fixture task",
      priority: priority,
      execution_state: hydrated_execution_state,
      created_by: created_by,
      card_id: None,
      created_from_rule_id: None,
      pool_lifetime_s: 3600 * created_days_ago,
      due_date: due_date,
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
  closed_at: Option(String),
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
      completed_at: closed_at,
    ),
  )
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
  closed_at: Option(String),
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
        closed_at: option_string(closed_at, "NOW()"),
        closed_by: created_by,
      )
  }
}

fn claimed_state_template(
  mode: task_state.TaskClaimMode,
) -> task_state.TaskExecutionState {
  task_state.Claimed(claimed_by: 0, claimed_at: "", mode: mode)
}

fn closed_outcome_state_template() -> task_state.TaskExecutionState {
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
