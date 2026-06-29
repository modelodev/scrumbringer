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
//// - Minimal final-model demo data for local development
////
//// ## Non-responsibilities
////
//// - Direct SQL operations (see seed_db.gleam)
//// - CLI or output (see seed.gleam)

import gleam/list
import gleam/result
import pog
import scrumbringer_server/seed_automation_scenarios
import scrumbringer_server/seed_capability_scenarios
import scrumbringer_server/seed_card_scenarios
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
    task_templates: Int,
    workflows: Int,
    rules: Int,
    tasks: Int,
    cards: Int,
    rule_executions: Int,
    audit_events: Int,
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
    capability_ids: List(#(Int, List(Int))),
    task_type_ids: List(#(Int, List(Int))),
    workflow_ids: List(#(Int, List(Int))),
    template_ids: List(#(Int, List(Int))),
    rule_ids_by_project: List(#(Int, List(Int))),
    rule_seeds: List(seed_automation_scenarios.RuleSeed),
    rule_count: Int,
    card_ids: List(Int),
    card_ids_by_project: List(#(Int, List(Int))),
    task_ids: List(Int),
    task_seeds: List(seed_task_scenarios.TaskSeed),
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
    empty_card_count: 2,
    date_range_days: 30,
  )
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
      workflow_ids: [],
      template_ids: [],
      rule_ids_by_project: [],
      rule_seeds: [],
      rule_count: 0,
      card_ids: [],
      card_ids_by_project: [],
      task_ids: [],
      task_seeds: [],
    )

  // Build in dependency order: core records, then tasks.
  use state <- result.try(build_workspace_scenarios(db, state, config))
  use state <- result.try(build_capability_scenarios(db, state, config))
  use state <- result.try(build_cards(db, state, config))
  use state <- result.try(build_automation_config(db, state))
  use state <- result.try(build_tasks(db, state, config))
  use automation_history <- result.try(build_automation_history(db, state))

  Ok(SeedResult(
    projects: list.length(state.project_ids),
    users: list.length(state.user_ids),
    task_types: count_grouped_ids(state.task_type_ids),
    task_templates: count_grouped_ids(state.template_ids),
    workflows: count_grouped_ids(state.workflow_ids),
    rules: state.rule_count,
    tasks: list.length(state.task_ids),
    cards: list.length(state.card_ids),
    rule_executions: automation_history.rule_executions,
    audit_events: 0,
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

fn build_automation_config(
  db: pog.Connection,
  state: BuildState,
) -> Result(BuildState, String) {
  use automation <- result.try(seed_automation_scenarios.build_config(
    db,
    seed_automation_scenarios.ConfigContext(
      org_id: state.org_id,
      admin_id: state.admin_id,
      active_task_types: task_types_for_active_projects(state),
    ),
  ))

  Ok(
    BuildState(
      ..state,
      workflow_ids: automation.workflow_ids_by_project,
      template_ids: automation.template_ids_by_project,
      rule_ids_by_project: automation.rule_ids_by_project,
      rule_seeds: automation.rule_seeds,
      rule_count: automation.rule_count,
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

  Ok(
    BuildState(
      ..state,
      task_ids: task_result.task_ids,
      task_seeds: task_result.task_seeds,
    ),
  )
}

fn build_automation_history(
  db: pog.Connection,
  state: BuildState,
) -> Result(seed_automation_scenarios.HistoryResult, String) {
  seed_automation_scenarios.build_history(
    db,
    seed_automation_scenarios.HistoryContext(
      admin_id: state.admin_id,
      rule_seeds: state.rule_seeds,
      task_seeds: state.task_seeds,
      card_ids_by_project: state.card_ids_by_project,
    ),
  )
}

fn active_project_ids(state: BuildState) -> List(Int) {
  list.filter(state.project_ids, fn(project_id) {
    !list.contains(state.empty_project_ids, project_id)
  })
}

fn count_grouped_ids(groups: List(#(Int, List(Int)))) -> Int {
  groups
  |> list.map(fn(group) {
    let #(_, ids) = group
    list.length(ids)
  })
  |> list.fold(0, fn(total, count) { total + count })
}

fn task_types_for_active_projects(state: BuildState) -> List(#(Int, List(Int))) {
  list.filter(state.task_type_ids, fn(entry) {
    let #(project_id, _) = entry
    !list.contains(state.empty_project_ids, project_id)
  })
}
