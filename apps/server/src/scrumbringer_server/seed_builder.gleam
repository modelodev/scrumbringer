//// Dev/test scenario builders for seed data generation.
////
//// ## Mission
////
//// Provide configurable, realistic seed data generation for local/dev/test use
//// with:
//// - Preset configuration (realistic)
//// - Variability in priorities, timestamps, creators
//// - Edge case coverage (empty projects, inactive workflows, etc.)
////
//// ## Responsibilities
////
//// - Define seed configuration preset
//// - Build full scenarios with proper relationships
//// - Manage data pools for realistic names/titles
//// - HT-12 coverage: root pool, parent_card_id, due_date, closed, healthy,
////   saturated, hierarchy, manager, member, capability
////
//// ## Non-responsibilities
////
//// - Direct SQL operations (see seed_db.gleam)
//// - CLI or output (see seed.gleam)

import domain/task/state as task_state
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import pog
import scrumbringer_server/seed_activity_scenarios
import scrumbringer_server/seed_audit_events
import scrumbringer_server/seed_automation_definitions
import scrumbringer_server/seed_automation_diagnostics
import scrumbringer_server/seed_automation_executions
import scrumbringer_server/seed_capability_scenarios
import scrumbringer_server/seed_card_scenarios
import scrumbringer_server/seed_people_scenarios
import scrumbringer_server/seed_plan_scenarios
import scrumbringer_server/seed_root_card_scenarios
import scrumbringer_server/seed_task_scenarios
import scrumbringer_server/seed_workspace_scenarios

// =============================================================================
// Types
// =============================================================================

/// Configuration for seed generation.
pub type SeedConfig {
  SeedConfig(
    // Users
    user_count: Int,
    inactive_user_count: Int,
    // Projects
    project_count: Int,
    empty_project_count: Int,
    // Tasks
    tasks_per_project: Int,
    priority_distribution: List(Int),
    status_distribution: StatusDistribution,
    // Cards
    cards_per_project: Int,
    empty_card_count: Int,
    // Workflows
    workflows_per_project: Int,
    inactive_workflow_count: Int,
    empty_workflow_count: Int,
    // Time
    date_range_days: Int,
  )
}

/// Distribution of task statuses.
pub type StatusDistribution {
  StatusDistribution(available: Int, claimed: Int, closed: Int)
}

/// Result of a seed run.
pub type SeedResult {
  SeedResult(
    projects: Int,
    users: Int,
    task_types: Int,
    workflows: Int,
    rules: Int,
    tasks: Int,
    cards: Int,
    rule_executions: Int,
    audit_events: Int,
  )
}

/// Seed metadata for audit event generation.
pub type TaskSeedInfo {
  TaskSeedInfo(
    task_id: Int,
    project_id: Int,
    execution_state: task_state.TaskExecutionState,
    created_at: String,
    created_by: Int,
    claimed_by: Option(Int),
  )
}

/// Internal state during seed building.
type BuildState {
  BuildState(
    org_id: Int,
    admin_id: Int,
    user_ids: List(Int),
    project_ids: List(Int),
    empty_project_ids: List(Int),
    project_member_ids: List(#(Int, List(Int))),
    capability_ids: List(#(Int, Int, Int, Int)),
    task_type_ids: List(#(Int, Int, Int, Int)),
    card_ids: List(Int),
    card_ids_by_project: List(#(Int, List(Int))),
    workflow_ids: List(Int),
    workflow_ids_by_project: List(#(Int, List(Int))),
    rule_ids: List(Int),
    rule_ids_by_project: List(#(Int, List(Int))),
    task_ids: List(Int),
    task_seeds: List(TaskSeedInfo),
    template_ids: List(Int),
    template_ids_by_project: List(#(Int, List(Int))),
    audit_events_count: Int,
    rule_executions_count: Int,
  )
}

// =============================================================================
// Configuration Presets
// =============================================================================

/// Realistic configuration with edge cases and variability.
pub fn realistic_config() -> SeedConfig {
  SeedConfig(
    user_count: 9,
    inactive_user_count: 2,
    project_count: 4,
    empty_project_count: 1,
    tasks_per_project: 24,
    priority_distribution: [1, 2, 3, 3, 3, 4, 5],
    status_distribution: StatusDistribution(
      available: 35,
      claimed: 40,
      closed: 25,
    ),
    cards_per_project: 6,
    empty_card_count: 1,
    workflows_per_project: 2,
    inactive_workflow_count: 1,
    empty_workflow_count: 1,
    date_range_days: 30,
  )
}

/// Visual QA configuration with explicit empty states.
pub fn visual_qa_config() -> SeedConfig {
  realistic_config()
}

// =============================================================================
// Main Builder
// =============================================================================

/// Build seed data according to the given configuration.
pub fn build_seed(
  db: pog.Connection,
  org_id: Int,
  admin_id: Int,
  config: SeedConfig,
) -> Result(SeedResult, String) {
  let state =
    BuildState(
      org_id: org_id,
      admin_id: admin_id,
      user_ids: [admin_id],
      project_ids: [],
      empty_project_ids: [],
      project_member_ids: [],
      capability_ids: [],
      task_type_ids: [],
      card_ids: [],
      card_ids_by_project: [],
      workflow_ids: [],
      workflow_ids_by_project: [],
      rule_ids: [],
      rule_ids_by_project: [],
      task_ids: [],
      task_seeds: [],
      template_ids: [],
      template_ids_by_project: [],
      audit_events_count: 0,
      rule_executions_count: 0,
    )

  // Build in dependency order: core records, automation definitions, tasks, QA
  // scenarios, then derived activity and diagnostics.
  use state <- result.try(build_workspace_scenarios(db, state, config))
  use state <- result.try(build_capability_scenarios(db, state, config))
  use state <- result.try(build_cards(db, state, config))
  use state <- result.try(build_automation_definitions(db, state, config))
  use state <- result.try(build_tasks(db, state, config))
  use state <- result.try(build_plan_qa_scenarios(db, state, config))
  use state <- result.try(build_people_qa_scenarios(db, state, config))
  use state <- result.try(build_root_cards(db, state, config))
  use state <- result.try(build_audit_events(db, state, config))
  use state <- result.try(build_activity_support_scenarios(db, state, config))
  use state <- result.try(build_automation_executions(db, state, config))
  use state <- result.try(build_automation_diagnostics(db, state, config))

  Ok(SeedResult(
    projects: list.length(state.project_ids),
    users: list.length(state.user_ids),
    task_types: list.length(state.task_type_ids),
    workflows: list.length(state.workflow_ids),
    rules: list.length(state.rule_ids),
    tasks: list.length(state.task_ids),
    cards: list.length(state.card_ids),
    rule_executions: state.rule_executions_count,
    audit_events: state.audit_events_count,
  ))
}

// =============================================================================
// Builder Steps
// =============================================================================

fn build_workspace_scenarios(
  db: pog.Connection,
  state: BuildState,
  config: SeedConfig,
) -> Result(BuildState, String) {
  use workspace <- result.try(seed_workspace_scenarios.build(
    db,
    seed_workspace_scenarios.Context(
      org_id: state.org_id,
      admin_id: state.admin_id,
      user_count: config.user_count,
      inactive_user_count: config.inactive_user_count,
      project_count: config.project_count,
      empty_project_count: config.empty_project_count,
      date_range_days: config.date_range_days,
    ),
  ))

  Ok(
    BuildState(
      ..state,
      user_ids: workspace.user_ids,
      project_ids: workspace.project_ids,
      empty_project_ids: workspace.empty_project_ids,
      project_member_ids: workspace.project_member_ids,
    ),
  )
}

fn build_capability_scenarios(
  db: pog.Connection,
  state: BuildState,
  _config: SeedConfig,
) -> Result(BuildState, String) {
  use capabilities <- result.try(seed_capability_scenarios.build(
    db,
    seed_capability_scenarios.Context(
      active_project_ids: active_project_ids(state),
      project_member_ids: state.project_member_ids,
    ),
  ))

  Ok(
    BuildState(
      ..state,
      capability_ids: capabilities.capability_ids,
      task_type_ids: capabilities.task_type_ids,
    ),
  )
}

fn build_cards(
  db: pog.Connection,
  state: BuildState,
  config: SeedConfig,
) -> Result(BuildState, String) {
  use cards <- result.try(seed_card_scenarios.build(
    db,
    seed_card_scenarios.Context(
      admin_id: state.admin_id,
      user_ids: state.user_ids,
      active_project_ids: active_project_ids(state),
      cards_per_project: config.cards_per_project,
      date_range_days: config.date_range_days,
    ),
  ))
  Ok(
    BuildState(
      ..state,
      card_ids: cards.card_ids,
      card_ids_by_project: cards.card_ids_by_project,
    ),
  )
}

fn build_automation_definitions(
  db: pog.Connection,
  state: BuildState,
  config: SeedConfig,
) -> Result(BuildState, String) {
  use definitions <- result.try(seed_automation_definitions.build(
    db,
    seed_automation_definitions.Context(
      org_id: state.org_id,
      admin_id: state.admin_id,
      active_project_ids: active_project_ids(state),
      workflows_per_project: config.workflows_per_project,
      inactive_workflow_count: config.inactive_workflow_count,
      empty_workflow_count: config.empty_workflow_count,
      task_type_ids: state.task_type_ids,
    ),
  ))
  Ok(
    BuildState(
      ..state,
      template_ids: definitions.template_ids,
      template_ids_by_project: definitions.template_ids_by_project,
      workflow_ids: definitions.workflow_ids,
      workflow_ids_by_project: definitions.workflow_ids_by_project,
      rule_ids: definitions.rule_ids,
      rule_ids_by_project: definitions.rule_ids_by_project,
    ),
  )
}

fn build_tasks(
  db: pog.Connection,
  state: BuildState,
  config: SeedConfig,
) -> Result(BuildState, String) {
  let StatusDistribution(available: available, claimed: claimed, closed: closed) =
    config.status_distribution
  use task_result <- result.try(seed_task_scenarios.build(
    db,
    seed_task_scenarios.Context(
      admin_id: state.admin_id,
      user_ids: state.user_ids,
      active_task_types: task_types_for_active_projects(state),
      card_ids_by_project: state.card_ids_by_project,
      project_member_ids: state.project_member_ids,
      rule_ids_by_project: state.rule_ids_by_project,
      tasks_per_project: config.tasks_per_project,
      priority_distribution: config.priority_distribution,
      status_distribution: seed_task_scenarios.StatusDistribution(
        available: available,
        claimed: claimed,
        closed: closed,
      ),
      empty_card_count: config.empty_card_count,
      date_range_days: config.date_range_days,
    ),
  ))

  let task_seeds =
    task_result.task_seeds
    |> list.map(fn(seed) {
      TaskSeedInfo(
        task_id: seed.task_id,
        project_id: seed.project_id,
        execution_state: seed.execution_state,
        created_at: seed.created_at,
        created_by: seed.created_by,
        claimed_by: seed.claimed_by,
      )
    })

  Ok(
    BuildState(..state, task_ids: task_result.task_ids, task_seeds: task_seeds),
  )
}

fn build_plan_qa_scenarios(
  db: pog.Connection,
  state: BuildState,
  _config: SeedConfig,
) -> Result(BuildState, String) {
  use plan_result <- result.try(seed_plan_scenarios.build(
    db,
    seed_plan_scenarios.Context(
      admin_id: state.admin_id,
      active_project_ids: active_project_ids(state),
      task_type_ids: state.task_type_ids,
      project_member_ids: state.project_member_ids,
    ),
  ))

  let new_task_seeds =
    plan_result.task_seeds
    |> list.map(fn(seed) {
      TaskSeedInfo(
        task_id: seed.task_id,
        project_id: seed.project_id,
        execution_state: seed.execution_state,
        created_at: seed.created_at,
        created_by: seed.created_by,
        claimed_by: seed.claimed_by,
      )
    })
  let new_task_ids = list.map(new_task_seeds, fn(seed) { seed.task_id })

  case plan_result.project_id {
    None -> Ok(state)
    Some(project_id) ->
      Ok(
        BuildState(
          ..state,
          card_ids: list.append(state.card_ids, plan_result.card_ids),
          card_ids_by_project: append_cards_for_project(
            state.card_ids_by_project,
            project_id,
            plan_result.card_ids,
          ),
          task_ids: list.append(state.task_ids, new_task_ids),
          task_seeds: list.append(state.task_seeds, new_task_seeds),
        ),
      )
  }
}

fn build_people_qa_scenarios(
  db: pog.Connection,
  state: BuildState,
  _config: SeedConfig,
) -> Result(BuildState, String) {
  use people_result <- result.try(seed_people_scenarios.build(
    db,
    seed_people_scenarios.Context(
      admin_id: state.admin_id,
      active_project_ids: active_project_ids(state),
      task_type_ids: state.task_type_ids,
      project_member_ids: state.project_member_ids,
    ),
  ))

  let new_task_seeds =
    people_result.task_seeds
    |> list.map(fn(seed) {
      TaskSeedInfo(
        task_id: seed.task_id,
        project_id: seed.project_id,
        execution_state: seed.execution_state,
        created_at: seed.created_at,
        created_by: seed.created_by,
        claimed_by: seed.claimed_by,
      )
    })
  let new_task_ids = list.map(new_task_seeds, fn(seed) { seed.task_id })

  case people_result.project_id {
    None -> Ok(state)
    Some(project_id) ->
      Ok(
        BuildState(
          ..state,
          card_ids: list.append(state.card_ids, people_result.card_ids),
          card_ids_by_project: append_cards_for_project(
            state.card_ids_by_project,
            project_id,
            people_result.card_ids,
          ),
          task_ids: list.append(state.task_ids, new_task_ids),
          task_seeds: list.append(state.task_seeds, new_task_seeds),
        ),
      )
  }
}

fn build_audit_events(
  db: pog.Connection,
  state: BuildState,
  config: SeedConfig,
) -> Result(BuildState, String) {
  use audit_events_count <- result.try(seed_audit_events.build(
    db,
    seed_audit_events.Context(
      org_id: state.org_id,
      admin_id: state.admin_id,
      user_ids: state.user_ids,
      task_ids: state.task_ids,
      task_refs: list.map(state.task_seeds, fn(seed) {
        seed_audit_events.TaskRef(
          task_id: seed.task_id,
          project_id: seed.project_id,
          execution_state: seed.execution_state,
          created_at: seed.created_at,
          created_by: seed.created_by,
          claimed_by: seed.claimed_by,
        )
      }),
      user_count: config.user_count,
      inactive_user_count: config.inactive_user_count,
      date_range_days: config.date_range_days,
    ),
  ))
  Ok(BuildState(..state, audit_events_count: audit_events_count))
}

fn build_activity_support_scenarios(
  db: pog.Connection,
  state: BuildState,
  config: SeedConfig,
) -> Result(BuildState, String) {
  use _ <- result.try(seed_activity_scenarios.build_all(
    db,
    seed_activity_scenarios.Context(
      admin_id: state.admin_id,
      user_ids: state.user_ids,
      active_project_ids: active_project_ids(state),
      card_ids_by_project: state.card_ids_by_project,
      task_refs: list.map(state.task_seeds, fn(seed) {
        seed_activity_scenarios.TaskRef(
          task_id: seed.task_id,
          execution_state: seed.execution_state,
        )
      }),
      date_range_days: config.date_range_days,
    ),
  ))
  Ok(state)
}

fn build_root_cards(
  db: pog.Connection,
  state: BuildState,
  _config: SeedConfig,
) -> Result(BuildState, String) {
  use _ <- result.try(seed_root_card_scenarios.build(
    db,
    seed_root_card_scenarios.Context(
      admin_id: state.admin_id,
      active_project_ids: active_project_ids(state),
    ),
  ))
  Ok(state)
}

fn build_automation_executions(
  db: pog.Connection,
  state: BuildState,
  _config: SeedConfig,
) -> Result(BuildState, String) {
  use context <- result.try(seed_automation_executions.build(
    db,
    seed_automation_executions.Context(
      org_id: state.org_id,
      admin_id: state.admin_id,
      task_ids: state.task_ids,
      active_project_ids: active_project_ids(state),
      task_type_ids: state.task_type_ids,
      rule_executions_count: state.rule_executions_count,
    ),
  ))

  Ok(BuildState(..state, rule_executions_count: context.rule_executions_count))
}

fn build_automation_diagnostics(
  db: pog.Connection,
  state: BuildState,
  _config: SeedConfig,
) -> Result(BuildState, String) {
  let active_projects = active_project_ids(state)

  case active_projects {
    [_default_project_id, _healthy_project_id, stress_project_id, ..] -> {
      use context <- result.try(seed_automation_diagnostics.build(
        db,
        seed_automation_diagnostics.Context(
          admin_id: state.admin_id,
          task_ids: state.task_ids,
          task_refs: list.map(state.task_seeds, fn(seed) {
            #(seed.project_id, seed.task_id)
          }),
          rule_ids_by_project: state.rule_ids_by_project,
          template_ids_by_project: state.template_ids_by_project,
          task_type_ids: state.task_type_ids,
          rule_executions_count: state.rule_executions_count,
        ),
        stress_project_id,
      ))
      Ok(
        BuildState(
          ..state,
          task_ids: context.task_ids,
          rule_executions_count: context.rule_executions_count,
        ),
      )
    }
    _ -> Ok(state)
  }
}

// =============================================================================
// Helpers
// =============================================================================

fn append_cards_for_project(
  card_ids_by_project: List(#(Int, List(Int))),
  project_id: Int,
  new_card_ids: List(Int),
) -> List(#(Int, List(Int))) {
  case card_ids_by_project {
    [] -> [#(project_id, new_card_ids)]
    [first, ..rest] -> {
      let #(existing_project_id, existing_card_ids) = first
      case existing_project_id == project_id {
        True -> [
          #(existing_project_id, list.append(existing_card_ids, new_card_ids)),
          ..rest
        ]
        False -> [
          first,
          ..append_cards_for_project(rest, project_id, new_card_ids)
        ]
      }
    }
  }
}

fn active_project_ids(state: BuildState) -> List(Int) {
  list.filter(state.project_ids, fn(project_id) {
    !list.contains(state.empty_project_ids, project_id)
  })
}

fn task_types_for_active_projects(
  state: BuildState,
) -> List(#(Int, Int, Int, Int)) {
  list.filter(state.task_type_ids, fn(entry) {
    let #(project_id, _, _, _) = entry
    !list.contains(state.empty_project_ids, project_id)
  })
}
