//// Scenario builders for seed data generation.
////
//// ## Mission
////
//// Provide configurable, realistic seed data generation with:
//// - Preset configurations (default, realistic, minimal)
//// - Variability in priorities, timestamps, creators
//// - Edge case coverage (empty projects, inactive workflows, etc.)
////
//// ## Responsibilities
////
//// - Define seed configurations and presets
//// - Build complete scenarios with proper relationships
//// - Manage data pools for realistic names/titles
////
//// ## Non-responsibilities
////
//// - Direct SQL operations (see seed_db.gleam)
//// - CLI or output (see seed.gleam)

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import pog
import scrumbringer_server/seed_db
import scrumbringer_server/services/rules_engine
import scrumbringer_server/services/task_events_db

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
  StatusDistribution(available: Int, claimed: Int, completed: Int)
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
    task_events: Int,
  )
}

/// Internal state during seed building.
type BuildState {
  BuildState(
    org_id: Int,
    admin_id: Int,
    user_ids: List(Int),
    project_ids: List(Int),
    task_type_ids: List(#(Int, Int, Int, Int)),
    card_ids: List(Int),
    workflow_ids: List(Int),
    rule_ids: List(Int),
    task_ids: List(Int),
    template_ids: List(Int),
    task_events_count: Int,
    rule_executions_count: Int,
  )
}

// =============================================================================
// Configuration Presets
// =============================================================================

/// Default configuration - equivalent to current seed behavior.
pub fn default_config() -> SeedConfig {
  SeedConfig(
    user_count: 4,
    inactive_user_count: 0,
    project_count: 2,
    empty_project_count: 0,
    tasks_per_project: 8,
    priority_distribution: [3, 3, 3, 3, 3],
    status_distribution: StatusDistribution(
      available: 30,
      claimed: 50,
      completed: 20,
    ),
    cards_per_project: 4,
    empty_card_count: 1,
    workflows_per_project: 3,
    inactive_workflow_count: 0,
    empty_workflow_count: 0,
    date_range_days: 1,
  )
}

/// Realistic configuration with edge cases and variability.
pub fn realistic_config() -> SeedConfig {
  SeedConfig(
    user_count: 6,
    inactive_user_count: 2,
    project_count: 3,
    empty_project_count: 1,
    tasks_per_project: 12,
    priority_distribution: [1, 2, 3, 3, 3, 4, 5],
    status_distribution: StatusDistribution(
      available: 25,
      claimed: 45,
      completed: 30,
    ),
    cards_per_project: 5,
    empty_card_count: 2,
    workflows_per_project: 4,
    inactive_workflow_count: 1,
    empty_workflow_count: 1,
    date_range_days: 30,
  )
}

/// Minimal configuration for fast tests.
pub fn minimal_config() -> SeedConfig {
  SeedConfig(
    user_count: 2,
    inactive_user_count: 0,
    project_count: 1,
    empty_project_count: 0,
    tasks_per_project: 3,
    priority_distribution: [3],
    status_distribution: StatusDistribution(
      available: 34,
      claimed: 33,
      completed: 33,
    ),
    cards_per_project: 1,
    empty_card_count: 0,
    workflows_per_project: 1,
    inactive_workflow_count: 0,
    empty_workflow_count: 0,
    date_range_days: 1,
  )
}

// =============================================================================
// Data Pools
// =============================================================================

/// Pool of realistic task titles.
pub fn task_title_pool() -> List(String) {
  [
    "Fix login button", "Dashboard slow", "Upload fails", "Session timeout",
    "Email delayed", "Dark mode support", "Export to PDF", "Notifications",
    "User profile bug", "Search not working", "API rate limiting",
    "Mobile responsive", "Password reset", "Two-factor auth", "Audit logging",
    "Performance tuning", "Cache invalidation", "Database indexing",
    "Error handling", "Input validation",
  ]
}

/// Pool of realistic card titles.
pub fn card_title_pool() -> List(String) {
  [
    "Sprint Planning", "Architecture", "Retrospective", "Release Notes",
    "Backend Refactor", "API Cleanup", "DB Migration", "Documentation",
    "Security Audit", "Performance",
  ]
}

/// Pool of valid card colors.
pub fn card_color_pool() -> List(String) {
  ["gray", "red", "orange", "yellow", "green", "blue", "purple", "pink"]
}

/// Pool of user emails for generated users.
fn user_email_pool() -> List(String) {
  [
    "pm@example.com", "member@example.com", "beta@example.com", "dev@example.com",
    "qa@example.com", "lead@example.com", "intern@example.com",
    "contractor@example.com",
  ]
}

/// Pool of workflow names.
fn workflow_name_pool() -> List(String) {
  [
    "Bug Resolution", "Feature Development", "Card Automation", "Simple Bug Flow",
    "Code Review", "QA Process", "Release Pipeline", "Hotfix Flow",
  ]
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
      task_type_ids: [],
      card_ids: [],
      workflow_ids: [],
      rule_ids: [],
      task_ids: [],
      template_ids: [],
      task_events_count: 0,
      rule_executions_count: 0,
    )

  // Build in order: users -> projects -> task types -> cards -> tasks -> workflows -> rules
  use state <- result.try(build_users(db, state, config))
  use state <- result.try(build_projects(db, state, config))
  use state <- result.try(build_task_types(db, state, config))
  use state <- result.try(build_cards(db, state, config))
  use state <- result.try(build_templates(db, state, config))
  use state <- result.try(build_workflows(db, state, config))
  use state <- result.try(build_rules(db, state, config))
  use state <- result.try(build_tasks(db, state, config))
  use state <- result.try(build_task_events(db, state, config))
  use state <- result.try(trigger_rule_executions(db, state, config))

  Ok(SeedResult(
    projects: list.length(state.project_ids),
    users: list.length(state.user_ids),
    task_types: list.length(state.task_type_ids),
    workflows: list.length(state.workflow_ids),
    rules: list.length(state.rule_ids),
    tasks: list.length(state.task_ids),
    cards: list.length(state.card_ids),
    rule_executions: state.rule_executions_count,
    task_events: state.task_events_count,
  ))
}

// =============================================================================
// Builder Steps
// =============================================================================

fn build_users(
  db: pog.Connection,
  state: BuildState,
  config: SeedConfig,
) -> Result(BuildState, String) {
  let emails = list.take(user_email_pool(), config.user_count - 1)
  let active_count = config.user_count - 1 - config.inactive_user_count

  use user_ids <- result.try(
    list.index_map(emails, fn(email, idx) {
      let first_login = case idx < active_count {
        True -> Some(days_ago_timestamp(config.date_range_days / 2))
        False -> None
      }
      seed_db.insert_user(
        db,
        seed_db.UserInsertOptions(
          org_id: state.org_id,
          email: email,
          org_role: "member",
          first_login_at: first_login,
          created_at: Some(days_ago_timestamp(config.date_range_days)),
        ),
      )
    })
    |> result.all,
  )

  Ok(BuildState(..state, user_ids: list.append(state.user_ids, user_ids)))
}

fn build_projects(
  db: pog.Connection,
  state: BuildState,
  config: SeedConfig,
) -> Result(BuildState, String) {
  let project_names = ["Project Alpha", "Project Beta", "Project Gamma"]
  let names = list.take(project_names, config.project_count)

  use project_ids <- result.try(
    list.index_map(names, fn(name, idx) {
      let days_ago = config.date_range_days - { idx * 5 }
      use project_id <- result.try(seed_db.insert_project(
        db,
        state.org_id,
        name,
        Some(days_ago_timestamp(days_ago)),
      ))

      // Add members to non-empty projects
      let is_empty = idx >= config.project_count - config.empty_project_count
      case is_empty {
        True -> Ok(project_id)
        False -> {
          // Add admin as manager
          use _ <- result.try(seed_db.insert_member(
            db,
            project_id,
            state.admin_id,
            "manager",
          ))
          // Add other users as members
          let other_users = list.drop(state.user_ids, 1)
          use _ <- result.try(
            list.try_map(other_users, fn(user_id) {
              seed_db.insert_member(db, project_id, user_id, "member")
            }),
          )
          Ok(project_id)
        }
      }
    })
    |> result.all,
  )

  Ok(BuildState(..state, project_ids: project_ids))
}

fn build_task_types(
  db: pog.Connection,
  state: BuildState,
  config: SeedConfig,
) -> Result(BuildState, String) {
  let active_projects =
    list.take(
      state.project_ids,
      config.project_count - config.empty_project_count,
    )

  use task_type_ids <- result.try(
    list.try_map(active_projects, fn(project_id) {
      use bug_id <- result.try(seed_db.insert_task_type(
        db,
        project_id,
        "Bug",
        "bug-ant",
      ))
      use feature_id <- result.try(seed_db.insert_task_type(
        db,
        project_id,
        "Feature",
        "sparkles",
      ))
      use task_id <- result.try(seed_db.insert_task_type(
        db,
        project_id,
        "Task",
        "clipboard-document-check",
      ))
      Ok(#(project_id, bug_id, feature_id, task_id))
    }),
  )

  Ok(BuildState(..state, task_type_ids: task_type_ids))
}

fn build_cards(
  db: pog.Connection,
  state: BuildState,
  config: SeedConfig,
) -> Result(BuildState, String) {
  let active_projects =
    list.take(
      state.project_ids,
      config.project_count - config.empty_project_count,
    )
  let titles = card_title_pool()
  let colors = card_color_pool()

  use card_ids_nested <- result.try(
    list.try_map(active_projects, fn(project_id) {
      let card_count = config.cards_per_project
      list.range(0, card_count - 1)
      |> list.try_map(fn(idx) {
        let title = list_at(titles, idx, "Card " <> int.to_string(idx + 1))
        let color = Some(list_at(colors, idx, "gray"))
        let creator_idx = idx % list.length(state.user_ids)
        let creator_id = list_at_int(state.user_ids, creator_idx, state.admin_id)

        seed_db.insert_card(
          db,
          seed_db.CardInsertOptions(
            project_id: project_id,
            title: title,
            description: "Seeded card",
            color: color,
            created_by: creator_id,
            created_at: Some(days_ago_timestamp(config.date_range_days - idx)),
          ),
        )
      })
    }),
  )

  Ok(BuildState(..state, card_ids: list.flatten(card_ids_nested)))
}

fn build_templates(
  db: pog.Connection,
  state: BuildState,
  _config: SeedConfig,
) -> Result(BuildState, String) {
  let template_names = ["Code Review", "QA Verification", "Deploy to Staging"]

  use template_ids_nested <- result.try(
    list.try_map(state.task_type_ids, fn(types) {
      let #(project_id, _bug_id, _feature_id, task_type_id) = types
      list.try_map(template_names, fn(name) {
        seed_db.insert_template(
          db,
          seed_db.TemplateInsertOptions(
            org_id: state.org_id,
            project_id: project_id,
            type_id: task_type_id,
            name: name,
            description: "Auto-created " <> name,
            priority: 3,
            created_by: state.admin_id,
            created_at: None,
          ),
        )
      })
    }),
  )

  Ok(BuildState(..state, template_ids: list.flatten(template_ids_nested)))
}

fn build_workflows(
  db: pog.Connection,
  state: BuildState,
  config: SeedConfig,
) -> Result(BuildState, String) {
  let active_projects =
    list.take(
      state.project_ids,
      config.project_count - config.empty_project_count,
    )
  let wf_names = workflow_name_pool()

  use workflow_ids_nested <- result.try(
    list.index_map(active_projects, fn(project_id, proj_idx) {
      let wf_count = config.workflows_per_project
      list.range(0, wf_count - 1)
      |> list.try_map(fn(idx) {
        let name = list_at(wf_names, idx, "Workflow " <> int.to_string(idx + 1))
        let is_inactive = idx >= wf_count - config.inactive_workflow_count
        let is_empty = idx >= wf_count - config.empty_workflow_count

        seed_db.insert_workflow(
          db,
          seed_db.WorkflowInsertOptions(
            org_id: state.org_id,
            project_id: project_id,
            name: name <> " " <> int.to_string(proj_idx + 1),
            description: case is_empty {
              True -> Some("Empty workflow for testing")
              False -> None
            },
            active: !is_inactive,
            created_by: state.admin_id,
            created_at: None,
          ),
        )
      })
    })
    |> result.all,
  )

  Ok(BuildState(..state, workflow_ids: list.flatten(workflow_ids_nested)))
}

fn build_rules(
  db: pog.Connection,
  state: BuildState,
  config: SeedConfig,
) -> Result(BuildState, String) {
  // Create rules for workflows that are not empty
  let non_empty_count =
    config.workflows_per_project - config.empty_workflow_count
  let active_workflows_per_project =
    list.take(state.workflow_ids, non_empty_count)

  case active_workflows_per_project {
    [] -> Ok(state)
    [wf_id, ..rest] -> {
      // Create rules for the first workflow (Bug Resolution pattern)
      use rule_ids <- result.try(build_rules_for_workflow(db, state, wf_id))

      // Create simple rules for remaining workflows
      use more_rules <- result.try(
        list.try_map(rest, fn(workflow_id) {
          seed_db.insert_rule(
            db,
            seed_db.RuleInsertOptions(
              workflow_id: workflow_id,
              name: "Auto Rule",
              goal: Some("Automated action"),
              resource_type: "task",
              task_type_id: None,
              to_state: "done",
              active: True,
              created_at: None,
            ),
          )
        }),
      )

      Ok(
        BuildState(
          ..state,
          rule_ids: list.append(rule_ids, more_rules),
        ),
      )
    }
  }
}

fn build_rules_for_workflow(
  db: pog.Connection,
  state: BuildState,
  workflow_id: Int,
) -> Result(List(Int), String) {
  // Get task type for this workflow's project
  let bug_type_id = case state.task_type_ids {
    [#(_project_id, bug_id, _feature_id, _task_id), ..] -> Some(bug_id)
    [] -> None
  }

  // Create rules
  use rule_resolved <- result.try(seed_db.insert_rule(
    db,
    seed_db.RuleInsertOptions(
      workflow_id: workflow_id,
      name: "On Bug Resolved",
      goal: Some("Create QA task"),
      resource_type: "task",
      task_type_id: bug_type_id,
      to_state: "resolved",
      active: True,
      created_at: None,
    ),
  ))

  use rule_closed <- result.try(seed_db.insert_rule(
    db,
    seed_db.RuleInsertOptions(
      workflow_id: workflow_id,
      name: "On Bug Closed",
      goal: Some("Create deploy task"),
      resource_type: "task",
      task_type_id: bug_type_id,
      to_state: "closed",
      active: True,
      created_at: None,
    ),
  ))

  use rule_card <- result.try(seed_db.insert_rule(
    db,
    seed_db.RuleInsertOptions(
      workflow_id: workflow_id,
      name: "On Card Archived",
      goal: Some("Card automation"),
      resource_type: "card",
      task_type_id: None,
      to_state: "archived",
      active: True,
      created_at: None,
    ),
  ))

  // Attach templates if available
  case state.template_ids {
    [tmpl_id, ..] -> {
      use _ <- result.try(seed_db.attach_template(db, rule_resolved, tmpl_id, 1))
      use _ <- result.try(seed_db.attach_template(db, rule_closed, tmpl_id, 1))
      Ok([rule_resolved, rule_closed, rule_card])
    }
    [] -> Ok([rule_resolved, rule_closed, rule_card])
  }
}

fn build_tasks(
  db: pog.Connection,
  state: BuildState,
  config: SeedConfig,
) -> Result(BuildState, String) {
  let titles = task_title_pool()
  let priorities = config.priority_distribution

  use task_ids_nested <- result.try(
    list.try_map(state.task_type_ids, fn(types) {
      let #(project_id, bug_id, feature_id, _task_id) = types
      let task_count = config.tasks_per_project
      let cards_for_project = get_project_cards(state.card_ids, config)

      list.range(0, task_count - 1)
      |> list.try_map(fn(idx) {
        let title = list_at(titles, idx, "Task " <> int.to_string(idx + 1))
        let priority = list_at_int(priorities, idx % list.length(priorities), 3)
        let type_id = case idx % 3 {
          0 -> bug_id
          1 -> feature_id
          _ -> bug_id
        }

        // Assign to card based on empty_card_count
        let card_count = list.length(cards_for_project)
        let card_id = case idx < card_count - config.empty_card_count, card_count > 0 {
          True, True -> Some(list_at_int(cards_for_project, idx % card_count, 0))
          _, _ -> None
        }

        // Determine status based on distribution
        let #(status, claimed_by, claimed_at, completed_at) =
          determine_task_status(state, idx, config)

        let creator_idx = idx % list.length(state.user_ids)
        let creator_id = list_at_int(state.user_ids, creator_idx, state.admin_id)

        seed_db.insert_task(
          db,
          seed_db.TaskInsertOptions(
            project_id: project_id,
            type_id: type_id,
            title: title,
            description: "Seeded task",
            priority: priority,
            status: status,
            created_by: creator_id,
            claimed_by: claimed_by,
            card_id: card_id,
            created_at: Some(days_ago_timestamp(config.date_range_days - idx)),
            claimed_at: claimed_at,
            completed_at: completed_at,
          ),
        )
      })
    }),
  )

  Ok(BuildState(..state, task_ids: list.flatten(task_ids_nested)))
}

fn build_task_events(
  db: pog.Connection,
  state: BuildState,
  config: SeedConfig,
) -> Result(BuildState, String) {
  let active_projects =
    list.take(
      state.project_ids,
      config.project_count - config.empty_project_count,
    )

  case active_projects {
    [] -> Ok(state)
    [project_id, ..] -> {
      // Create task_created events for all tasks
      use _ <- result.try(
        list.try_map(state.task_ids, fn(task_id) {
          seed_db.insert_task_event_simple(
            db,
            state.org_id,
            project_id,
            task_id,
            state.admin_id,
            task_events_db.event_type_to_string(task_events_db.TaskCreated),
          )
        }),
      )

      let events_count = list.length(state.task_ids)
      Ok(BuildState(..state, task_events_count: events_count))
    }
  }
}

fn trigger_rule_executions(
  db: pog.Connection,
  state: BuildState,
  config: SeedConfig,
) -> Result(BuildState, String) {
  // Trigger some rule executions for tasks
  let tasks_to_trigger = list.take(state.task_ids, 3)
  let active_projects =
    list.take(
      state.project_ids,
      config.project_count - config.empty_project_count,
    )

  case active_projects, state.task_type_ids {
    [project_id, ..], [#(_proj, bug_type_id, _feat, _task), ..] -> {
      use _ <- result.try(
        list.try_map(tasks_to_trigger, fn(task_id) {
          let event =
            rules_engine.task_event(
              rules_engine.TaskContext(
                task_id: task_id,
                project_id: project_id,
                org_id: state.org_id,
                type_id: bug_type_id,
                card_id: None,
              ),
              state.admin_id,
              Some("in_progress"),
              "resolved",
            )
          rules_engine.evaluate_rules(db, event)
          |> result.map_error(fn(_) { "Rule evaluation failed" })
        }),
      )

      Ok(
        BuildState(
          ..state,
          rule_executions_count: list.length(tasks_to_trigger),
        ),
      )
    }
    _, _ -> Ok(state)
  }
}

// =============================================================================
// Helpers
// =============================================================================

fn determine_task_status(
  state: BuildState,
  idx: Int,
  config: SeedConfig,
) -> #(String, Option(Int), Option(String), Option(String)) {
  let total = config.status_distribution.available
    + config.status_distribution.claimed
    + config.status_distribution.completed
  let pct = { idx * 100 } / config.tasks_per_project

  let available_threshold = { config.status_distribution.available * 100 } / total
  let claimed_threshold =
    available_threshold + { { config.status_distribution.claimed * 100 } / total }

  case pct < available_threshold {
    True -> #("available", None, None, None)
    False ->
      case pct < claimed_threshold {
        True -> {
          let claimer_idx = idx % list.length(state.user_ids)
          let claimer_id =
            list_at_int(state.user_ids, claimer_idx, state.admin_id)
          #(
            "claimed",
            Some(claimer_id),
            Some(days_ago_timestamp(config.date_range_days / 2)),
            None,
          )
        }
        False -> {
          let claimer_idx = idx % list.length(state.user_ids)
          let claimer_id =
            list_at_int(state.user_ids, claimer_idx, state.admin_id)
          #(
            "completed",
            Some(claimer_id),
            Some(days_ago_timestamp(config.date_range_days / 2)),
            Some(days_ago_timestamp(config.date_range_days / 4)),
          )
        }
      }
  }
}

fn get_project_cards(card_ids: List(Int), config: SeedConfig) -> List(Int) {
  list.take(card_ids, config.cards_per_project)
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
