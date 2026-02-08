//// Scenario builders for seed data generation.
////
//// ## Mission
////
//// Provide configurable, realistic seed data generation with:
//// - Preset configuration (realistic)
//// - Variability in priorities, timestamps, creators
//// - Edge case coverage (empty projects, inactive workflows, etc.)
////
//// ## Responsibilities
////
//// - Define seed configuration preset
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

/// Seed metadata for task event generation.
pub type TaskSeedInfo {
  TaskSeedInfo(
    task_id: Int,
    project_id: Int,
    status: String,
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
    task_events_count: Int,
    rule_executions_count: Int,
  )
}

// =============================================================================
// Configuration Presets
// =============================================================================

/// Realistic configuration with edge cases and variability.
pub fn realistic_config() -> SeedConfig {
  SeedConfig(
    user_count: 6,
    inactive_user_count: 2,
    project_count: 3,
    empty_project_count: 1,
    tasks_per_project: 18,
    priority_distribution: [1, 2, 3, 3, 3, 4, 5],
    status_distribution: StatusDistribution(
      available: 35,
      claimed: 40,
      completed: 25,
    ),
    cards_per_project: 4,
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
    "member@example.com", "pm@example.com", "beta@example.com",
    "dev@example.com", "qa@example.com", "lead@example.com",
    "intern@example.com", "contractor@example.com",
  ]
}

/// Pool of workflow names.
fn workflow_name_pool() -> List(String) {
  [
    "Bug Resolution", "Feature Development", "Card Automation",
    "Simple Bug Flow", "Code Review", "QA Process", "Release Pipeline",
    "Hotfix Flow",
  ]
}

/// Pool of capability names.
fn capability_name_pool() -> List(String) {
  [
    "Engineering", "Product", "Operations", "Security", "Design", "QA",
    "Platform", "Data",
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
      task_events_count: 0,
      rule_executions_count: 0,
    )

  // Build in order: users -> projects -> capabilities -> task types -> cards -> tasks -> workflows -> rules
  use state <- result.try(build_users(db, state, config))
  use state <- result.try(build_projects(db, state, config))
  use state <- result.try(build_capabilities(db, state, config))
  use state <- result.try(build_task_types(db, state, config))
  use state <- result.try(build_member_capabilities(db, state, config))
  use state <- result.try(build_cards(db, state, config))
  use state <- result.try(build_templates(db, state, config))
  use state <- result.try(build_workflows(db, state, config))
  use state <- result.try(build_rules(db, state, config))
  use state <- result.try(build_tasks(db, state, config))
  use state <- result.try(build_milestones(db, state, config))
  use state <- result.try(build_task_events(db, state, config))
  use state <- result.try(build_task_positions(db, state, config))
  use state <- result.try(build_work_sessions(db, state, config))
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
  let default_project_id = 1
  let project_names = ["Project Alpha", "Project Beta", "Project Gamma"]
  let names = list.take(project_names, config.project_count)
  let empty_start = int.max(0, list.length(names) - config.empty_project_count)
  let other_users = list.drop(state.user_ids, 1)
  let assignable_users = case list.reverse(other_users) {
    [] -> []
    [_unassigned, ..rest] -> list.reverse(rest)
  }

  use project_results <- result.try(
    list.index_map(names, fn(name, idx) {
      let is_empty = idx >= empty_start
      let days_ago = config.date_range_days - { idx * 5 }
      use project_id <- result.try(seed_db.insert_project(
        db,
        state.org_id,
        name,
        Some(days_ago_timestamp(days_ago)),
      ))

      case is_empty {
        True -> Ok(#(project_id, True))
        False -> {
          // Add admin as manager for visibility in admin views
          use _ <- result.try(seed_db.insert_member(
            db,
            project_id,
            state.admin_id,
            "manager",
          ))

          use _ <- result.try(
            list.try_map(assignable_users, fn(user_id) {
              seed_db.insert_member(db, project_id, user_id, "member")
            }),
          )

          Ok(#(project_id, False))
        }
      }
    })
    |> result.all,
  )

  let project_ids = [
    default_project_id,
    ..list.map(project_results, fn(pair) {
      let #(id, _) = pair
      id
    })
  ]

  let empty_project_ids =
    project_results
    |> list.fold([], fn(acc, pair) {
      let #(id, is_empty) = pair
      case is_empty {
        True -> [id, ..acc]
        False -> acc
      }
    })
    |> list.reverse

  let project_members =
    list.map(project_ids, fn(project_id) {
      case project_id == default_project_id {
        True -> #(project_id, [])
        False ->
          case list.contains(empty_project_ids, project_id) {
            True -> #(project_id, [])
            False -> #(project_id, [state.admin_id, ..assignable_users])
          }
      }
    })

  Ok(
    BuildState(
      ..state,
      project_ids: project_ids,
      empty_project_ids: empty_project_ids,
      project_member_ids: project_members,
    ),
  )
}

fn build_capabilities(
  db: pog.Connection,
  state: BuildState,
  _config: SeedConfig,
) -> Result(BuildState, String) {
  let active_projects = active_project_ids(state)
  let names = capability_name_pool()

  use capability_ids <- result.try(
    list.index_map(active_projects, fn(project_id, proj_idx) {
      let bug_name = list_at(names, proj_idx, "Engineering")
      let feature_name = list_at(names, proj_idx + 1, "Product")
      let task_name = list_at(names, proj_idx + 2, "Operations")

      use bug_cap <- result.try(seed_db.insert_capability(
        db,
        project_id,
        bug_name,
      ))
      use feature_cap <- result.try(seed_db.insert_capability(
        db,
        project_id,
        feature_name,
      ))
      use task_cap <- result.try(seed_db.insert_capability(
        db,
        project_id,
        task_name,
      ))
      Ok(#(project_id, bug_cap, feature_cap, task_cap))
    })
    |> result.all,
  )

  Ok(BuildState(..state, capability_ids: capability_ids))
}

fn build_task_types(
  db: pog.Connection,
  state: BuildState,
  _config: SeedConfig,
) -> Result(BuildState, String) {
  use task_type_ids <- result.try(
    list.try_map(state.capability_ids, fn(caps) {
      let #(project_id, bug_cap, feature_cap, task_cap) = caps
      use bug_id <- result.try(seed_db.insert_task_type_with_capability(
        db,
        project_id,
        "Bug",
        "bug-ant",
        Some(bug_cap),
      ))
      use feature_id <- result.try(seed_db.insert_task_type_with_capability(
        db,
        project_id,
        "Feature",
        "sparkles",
        Some(feature_cap),
      ))
      use task_id <- result.try(seed_db.insert_task_type_with_capability(
        db,
        project_id,
        "Task",
        "clipboard-document-check",
        Some(task_cap),
      ))
      Ok(#(project_id, bug_id, feature_id, task_id))
    }),
  )

  Ok(BuildState(..state, task_type_ids: task_type_ids))
}

fn build_member_capabilities(
  db: pog.Connection,
  state: BuildState,
  _config: SeedConfig,
) -> Result(BuildState, String) {
  use _ <- result.try(
    list.try_map(state.capability_ids, fn(caps) {
      let #(project_id, bug_cap, feature_cap, task_cap) = caps
      let members = members_for_project(state.project_member_ids, project_id)

      case members {
        [] -> Ok(Nil)
        _ ->
          list.index_map(members, fn(user_id, idx) {
            let cap_id = case idx % 3 {
              0 -> bug_cap
              1 -> feature_cap
              _ -> task_cap
            }
            seed_db.insert_project_member_capability(
              db,
              project_id,
              user_id,
              cap_id,
            )
          })
          |> result.all
          |> result.map(fn(_) { Nil })
      }
    }),
  )

  Ok(state)
}

fn build_cards(
  db: pog.Connection,
  state: BuildState,
  config: SeedConfig,
) -> Result(BuildState, String) {
  let active_projects = active_project_ids(state)
  let titles = card_title_pool()
  let colors = card_color_pool()

  use card_ids_by_project <- result.try(
    list.try_map(active_projects, fn(project_id) {
      let card_count = config.cards_per_project
      use card_ids <- result.try(
        list.range(0, card_count - 1)
        |> list.try_map(fn(idx) {
          let base_title =
            list_at(titles, idx, "Card " <> int.to_string(idx + 1))
          let title =
            "P"
            <> int.to_string(project_id)
            <> " - "
            <> base_title
            <> " #"
            <> int.to_string(idx + 1)
          let color = Some(list_at(colors, idx, "gray"))
          let creator_idx = idx % list.length(state.user_ids)
          let creator_id =
            list_at_int(state.user_ids, creator_idx, state.admin_id)

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
        }),
      )
      Ok(#(project_id, card_ids))
    }),
  )

  let card_ids =
    list.map(card_ids_by_project, fn(pair) {
      let #(_project_id, ids) = pair
      ids
    })
    |> list.flatten

  Ok(
    BuildState(
      ..state,
      card_ids: card_ids,
      card_ids_by_project: card_ids_by_project,
    ),
  )
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
  let active_projects = active_project_ids(state)
  let wf_names = workflow_name_pool()

  use workflow_ids_by_project <- result.try(
    list.index_map(active_projects, fn(project_id, proj_idx) {
      let wf_count = config.workflows_per_project
      use wf_ids <- result.try(
        list.range(0, wf_count - 1)
        |> list.try_map(fn(idx) {
          let name =
            list_at(wf_names, idx, "Workflow " <> int.to_string(idx + 1))
          let is_inactive = idx >= wf_count - config.inactive_workflow_count

          seed_db.insert_workflow(
            db,
            seed_db.WorkflowInsertOptions(
              org_id: state.org_id,
              project_id: project_id,
              name: name <> " " <> int.to_string(proj_idx + 1),
              description: None,
              active: !is_inactive,
              created_by: state.admin_id,
              created_at: None,
            ),
          )
        }),
      )
      Ok(#(project_id, wf_ids))
    })
    |> result.all,
  )

  let workflow_ids =
    list.map(workflow_ids_by_project, fn(pair) {
      let #(_project_id, ids) = pair
      ids
    })
    |> list.flatten

  Ok(
    BuildState(
      ..state,
      workflow_ids: workflow_ids,
      workflow_ids_by_project: workflow_ids_by_project,
    ),
  )
}

fn build_rules(
  db: pog.Connection,
  state: BuildState,
  config: SeedConfig,
) -> Result(BuildState, String) {
  use rule_ids_by_project <- result.try(
    list.try_map(state.workflow_ids_by_project, fn(pair) {
      let #(project_id, wf_ids) = pair
      let task_types = task_types_for_project(state.task_type_ids, project_id)
      let wf_ids = list.drop(wf_ids, config.empty_workflow_count)

      case wf_ids, task_types {
        [], _ -> Ok(#(project_id, []))
        _, None -> Ok(#(project_id, []))
        [active_wf, inactive_wf], Some(#(bug_id, feature_id, _task_id)) -> {
          use active_rule <- result.try(seed_db.insert_rule(
            db,
            seed_db.RuleInsertOptions(
              workflow_id: active_wf,
              name: "On Task Completed (Active)",
              goal: Some("Auto action on completion"),
              resource_type: "task",
              task_type_id: Some(bug_id),
              to_state: "completed",
              active: True,
              created_at: None,
            ),
          ))

          use inactive_rule <- result.try(seed_db.insert_rule(
            db,
            seed_db.RuleInsertOptions(
              workflow_id: inactive_wf,
              name: "On Task Completed (Inactive)",
              goal: Some("Should not trigger"),
              resource_type: "task",
              task_type_id: Some(feature_id),
              to_state: "completed",
              active: True,
              created_at: None,
            ),
          ))

          Ok(#(project_id, [active_rule, inactive_rule]))
        }
        [single_wf], Some(#(bug_id, _feature_id, _task_id)) ->
          seed_db.insert_rule(
            db,
            seed_db.RuleInsertOptions(
              workflow_id: single_wf,
              name: "On Task Completed",
              goal: Some("Auto action on completion"),
              resource_type: "task",
              task_type_id: Some(bug_id),
              to_state: "completed",
              active: True,
              created_at: None,
            ),
          )
          |> result.map(fn(id) { #(project_id, [id]) })
        _, _ -> Ok(#(project_id, []))
      }
    }),
  )

  let rule_ids =
    rule_ids_by_project
    |> list.map(fn(pair) {
      let #(_project_id, ids) = pair
      ids
    })
    |> list.flatten

  Ok(
    BuildState(
      ..state,
      rule_ids: rule_ids,
      rule_ids_by_project: rule_ids_by_project,
    ),
  )
}

fn build_tasks(
  db: pog.Connection,
  state: BuildState,
  config: SeedConfig,
) -> Result(BuildState, String) {
  let titles = task_title_pool()
  let priorities = config.priority_distribution
  let status_pool = status_pool_from(config.status_distribution)

  let active_task_types = task_types_for_active_projects(state)
  use task_results_nested <- result.try(
    list.index_map(active_task_types, fn(types, proj_idx) {
      let #(project_id, bug_id, feature_id, task_id) = types
      let cards_for_project =
        cards_for_project(state.card_ids_by_project, project_id)
      let usable_cards = case config.empty_card_count > 0 {
        True -> list.drop(cards_for_project, config.empty_card_count)
        False -> cards_for_project
      }

      let card_all_done = list_at_int(usable_cards, 0, 0)
      let card_mixed = list_at_int(usable_cards, 1, 0)
      let card_single = list_at_int(usable_cards, 2, 0)

      let base_idx = proj_idx * config.tasks_per_project

      let title_for = fn(idx, fallback) {
        let base = list_at(titles, idx, fallback)
        "P"
        <> int.to_string(project_id)
        <> " - "
        <> base
        <> " #"
        <> int.to_string(idx + 1)
      }

      let creator_id = list_at_int(state.user_ids, proj_idx, state.admin_id)
      let claimed_user_id = claimed_member_id(state, project_id, creator_id)
      let members = members_for_project(state.project_member_ids, project_id)
      let project_rule_ids =
        rule_ids_for_project(state.rule_ids_by_project, project_id)
      let base_days = int.max(1, config.date_range_days - { proj_idx * 3 })

      let tasks = [
        #(
          title_for(base_idx, "Task A"),
          bug_id,
          "completed",
          Some(card_all_done),
        ),
        #(
          title_for(base_idx + 1, "Task B"),
          feature_id,
          "completed",
          Some(card_all_done),
        ),
        #(
          title_for(base_idx + 2, "Task C"),
          bug_id,
          "completed",
          Some(card_mixed),
        ),
        #(
          title_for(base_idx + 3, "Task D"),
          feature_id,
          "claimed",
          Some(card_mixed),
        ),
        #(
          title_for(base_idx + 4, "Task E"),
          task_id,
          "available",
          Some(card_single),
        ),
        #(title_for(base_idx + 5, "Task F"), bug_id, "available", None),
        #(title_for(base_idx + 6, "Task G"), feature_id, "available", None),
      ]

      let extra_count =
        int.max(0, config.tasks_per_project - list.length(tasks))
      let extra_indexes = case extra_count > 0 {
        True -> list.range(0, extra_count - 1)
        False -> []
      }
      let extra_tasks =
        extra_indexes
        |> list.map(fn(extra_idx) {
          let idx = base_idx + list.length(tasks) + extra_idx
          let type_id = case extra_idx % 3 {
            0 -> bug_id
            1 -> feature_id
            _ -> task_id
          }
          let status = status_from_pool(status_pool, idx)
          let card_id = case extra_idx % 4 {
            0 -> Some(card_mixed)
            1 -> Some(card_single)
            _ -> None
          }
          #(title_for(idx, "Task Extra"), type_id, status, card_id)
        })

      let all_tasks = list.append(tasks, extra_tasks)

      list.index_map(all_tasks, fn(task_def, idx) {
        let #(title, type_id, status, card_id) = task_def
        let priority = list_at_int(priorities, idx % list.length(priorities), 3)
        let creator_for = list_at_int(state.user_ids, idx, state.admin_id)
        let claimed_user_for = member_for_index(members, idx, claimed_user_id)
        let created_from_rule_id =
          seeded_rule_for_task(project_rule_ids, idx, proj_idx)
        let pool_lifetime_s = seeded_pool_lifetime_s(status, idx, proj_idx)
        let last_entered_pool_at =
          seeded_last_entered_pool_at(status, pool_lifetime_s, base_days, idx)
        let #(claimed_by, claimed_at, completed_at) = case status {
          "claimed" -> #(
            Some(claimed_user_for),
            Some(days_ago_timestamp(int.max(1, base_days - { idx % 7 }))),
            None,
          )
          "completed" -> #(
            None,
            None,
            Some(days_ago_timestamp(int.max(1, base_days - { idx % 11 }))),
          )
          _ -> #(None, None, None)
        }

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
            status: status,
            created_by: creator_for,
            claimed_by: claimed_by,
            card_id: card_id,
            created_from_rule_id: created_from_rule_id,
            pool_lifetime_s: pool_lifetime_s,
            created_at: Some(created_at),
            claimed_at: claimed_at,
            completed_at: completed_at,
            last_entered_pool_at: last_entered_pool_at,
          ),
        )
        |> result.map(fn(task_id) {
          TaskSeedInfo(
            task_id: task_id,
            project_id: project_id,
            status: status,
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
  let task_ids =
    task_seeds
    |> list.map(fn(seed) { seed.task_id })

  Ok(BuildState(..state, task_ids: task_ids, task_seeds: task_seeds))
}

fn build_task_events(
  db: pog.Connection,
  state: BuildState,
  config: SeedConfig,
) -> Result(BuildState, String) {
  case state.task_seeds {
    [] -> Ok(state)
    seeds -> {
      let created_events =
        seeds
        |> list.map(fn(seed) {
          seed_db.TaskEventInsertOptions(
            org_id: state.org_id,
            project_id: seed.project_id,
            task_id: seed.task_id,
            actor_user_id: seed.created_by,
            event_type: task_events_db.event_type_to_string(
              task_events_db.TaskCreated,
            ),
            created_at: Some(seed.created_at),
          )
        })

      let per_task_events =
        seeds
        |> list.index_map(fn(seed, idx) {
          task_event_options_for_seed(seed, idx, state, config)
        })
        |> list.flatten

      let per_user_events = first_claim_events_for_users(state, seeds, config)

      let all_events =
        created_events
        |> list.append(per_task_events)
        |> list.append(per_user_events)

      use _ <- result.try(
        list.try_map(all_events, fn(opts) {
          seed_db.insert_task_event(db, opts)
        }),
      )

      Ok(BuildState(..state, task_events_count: list.length(all_events)))
    }
  }
}

fn build_milestones(
  db: pog.Connection,
  state: BuildState,
  _config: SeedConfig,
) -> Result(BuildState, String) {
  let active_projects =
    active_project_ids(state)
    |> list.filter(fn(project_id) { project_id != 1 })

  use _ <- result.try(
    list.index_map(active_projects, fn(project_id, idx) {
      // Scenario A (idx 0): only ready milestones
      // - one empty ready milestone
      // - one ready milestone with available pool tasks + one card
      // Scenario B (idx 1): full lifecycle
      // - completed milestone with completed tasks + one card
      // - active milestone with claimed/available tasks + one card
      // - ready backlog milestone with available tasks
      // Scenario C+ (idx >= 2): single ready milestone with available tasks
      case idx {
        0 -> {
          use empty_ready_id <- result.try(seed_db.insert_milestone(
            db,
            seed_db.MilestoneInsertOptions(
              project_id: project_id,
              name: "M0 - Hito vacio",
              description: Some("Hito listo sin asignaciones"),
              state: "ready",
              position: 0,
              created_by: state.admin_id,
              created_at: Some(days_ago_timestamp(12)),
              activated_at: None,
              completed_at: None,
            ),
          ))
          let _ = empty_ready_id

          use ready_seeded_id <- result.try(seed_db.insert_milestone(
            db,
            seed_db.MilestoneInsertOptions(
              project_id: project_id,
              name: "M1 - Hito planificado",
              description: Some("Hito listo con trabajo pendiente"),
              state: "ready",
              position: 1,
              created_by: state.admin_id,
              created_at: Some(days_ago_timestamp(10)),
              activated_at: None,
              completed_at: None,
            ),
          ))
          use _ <- result.try(seed_db.assign_cards_to_milestone(
            db,
            project_id,
            ready_seeded_id,
            1,
          ))
          use _ <- result.try(seed_db.assign_available_pool_tasks_to_milestone(
            db,
            project_id,
            ready_seeded_id,
            2,
          ))
          Ok(Nil)
        }

        1 -> {
          use completed_id <- result.try(seed_db.insert_milestone(
            db,
            seed_db.MilestoneInsertOptions(
              project_id: project_id,
              name: "M0 - Completed",
              description: Some("Completed milestone for historical metrics"),
              state: "completed",
              position: 0,
              created_by: state.admin_id,
              created_at: Some(days_ago_timestamp(18)),
              activated_at: Some(days_ago_timestamp(12)),
              completed_at: Some(days_ago_timestamp(3)),
            ),
          ))
          use _ <- result.try(seed_db.assign_cards_to_milestone(
            db,
            project_id,
            completed_id,
            1,
          ))
          use _ <- result.try(seed_db.assign_completed_pool_tasks_to_milestone(
            db,
            project_id,
            completed_id,
            2,
          ))

          use active_id <- result.try(seed_db.insert_milestone(
            db,
            seed_db.MilestoneInsertOptions(
              project_id: project_id,
              name: "M1 - Active",
              description: Some("Current active delivery milestone"),
              state: "active",
              position: 1,
              created_by: state.admin_id,
              created_at: Some(days_ago_timestamp(9)),
              activated_at: Some(days_ago_timestamp(2)),
              completed_at: None,
            ),
          ))
          use _ <- result.try(seed_db.assign_cards_to_milestone(
            db,
            project_id,
            active_id,
            1,
          ))
          use _ <- result.try(seed_db.assign_claimed_pool_tasks_to_milestone(
            db,
            project_id,
            active_id,
            1,
          ))
          use _ <- result.try(seed_db.assign_available_pool_tasks_to_milestone(
            db,
            project_id,
            active_id,
            1,
          ))

          use backlog_id <- result.try(seed_db.insert_milestone(
            db,
            seed_db.MilestoneInsertOptions(
              project_id: project_id,
              name: "M2 - Ready Backlog",
              description: Some("Next milestone planned but not active"),
              state: "ready",
              position: 2,
              created_by: state.admin_id,
              created_at: Some(days_ago_timestamp(1)),
              activated_at: None,
              completed_at: None,
            ),
          ))
          use _ <- result.try(seed_db.assign_available_pool_tasks_to_milestone(
            db,
            project_id,
            backlog_id,
            1,
          ))
          Ok(Nil)
        }

        _ -> {
          use ready_id <- result.try(seed_db.insert_milestone(
            db,
            seed_db.MilestoneInsertOptions(
              project_id: project_id,
              name: "M0 - Ready",
              description: Some("Single ready milestone scenario"),
              state: "ready",
              position: 0,
              created_by: state.admin_id,
              created_at: Some(days_ago_timestamp(7)),
              activated_at: None,
              completed_at: None,
            ),
          ))
          use _ <- result.try(seed_db.assign_available_pool_tasks_to_milestone(
            db,
            project_id,
            ready_id,
            2,
          ))
          Ok(Nil)
        }
      }
    })
    |> result.all,
  )

  Ok(state)
}

fn build_task_positions(
  db: pog.Connection,
  state: BuildState,
  _config: SeedConfig,
) -> Result(BuildState, String) {
  let tasks = list.take(state.task_ids, 9)
  let users = list.take(state.user_ids, 3)

  case tasks, users {
    [], _ -> Ok(state)
    _, [] -> Ok(state)
    _, _ -> {
      use _ <- result.try(
        list.index_map(tasks, fn(task_id, idx) {
          let user_id =
            list_at_int(users, idx % list.length(users), state.admin_id)
          let x = { idx % 3 } * 120
          let y = { idx / 3 } * 80
          seed_db.insert_task_position(db, task_id, user_id, x, y)
        })
        |> result.all,
      )
      Ok(state)
    }
  }
}

fn build_work_sessions(
  db: pog.Connection,
  state: BuildState,
  _config: SeedConfig,
) -> Result(BuildState, String) {
  let claimed_tasks =
    state.task_seeds
    |> list.filter(fn(seed) { seed.status == "claimed" })
    |> list.map(fn(seed) { seed.task_id })
  let completed_tasks =
    state.task_seeds
    |> list.filter(fn(seed) { seed.status == "completed" })
    |> list.map(fn(seed) { seed.task_id })
  let tasks = list.append(claimed_tasks, completed_tasks)
  let tasks = list.take(tasks, 8)
  let users = state.user_ids

  case tasks, users {
    [], _ -> Ok(state)
    _, [] -> Ok(state)
    _, _ -> {
      let active_tasks = list.take(tasks, 3)
      let ended_tasks = list.drop(tasks, 3)

      use _ <- result.try(
        list.index_map(active_tasks, fn(task_id, idx) {
          let user_id = list_at_int(users, idx, state.admin_id)
          use _ <- result.try(seed_db.insert_work_session_entry(
            db,
            seed_db.WorkSessionInsertOptions(
              user_id: user_id,
              task_id: task_id,
              started_at: Some("NOW() - INTERVAL '2 hours'"),
              last_heartbeat_at: Some("NOW() - INTERVAL '5 minutes'"),
              ended_at: None,
              ended_reason: None,
              created_at: None,
            ),
          ))
          seed_db.insert_work_session(
            db,
            user_id,
            task_id,
            1200 + { idx * 300 },
          )
        })
        |> result.all,
      )

      use _ <- result.try(
        list.index_map(ended_tasks, fn(task_id, idx) {
          let user_id = list_at_int(users, idx + 1, state.admin_id)
          use _ <- result.try(seed_db.insert_work_session_entry(
            db,
            seed_db.WorkSessionInsertOptions(
              user_id: user_id,
              task_id: task_id,
              started_at: Some("NOW() - INTERVAL '2 days'"),
              last_heartbeat_at: Some("NOW() - INTERVAL '1 day'"),
              ended_at: Some("NOW() - INTERVAL '1 day'"),
              ended_reason: Some("task_completed"),
              created_at: None,
            ),
          ))
          seed_db.insert_work_session(
            db,
            user_id,
            task_id,
            7200 + { idx * 600 },
          )
        })
        |> result.all,
      )

      Ok(state)
    }
  }
}

fn trigger_rule_executions(
  db: pog.Connection,
  state: BuildState,
  _config: SeedConfig,
) -> Result(BuildState, String) {
  // Trigger some rule executions for tasks
  let tasks_to_trigger = list.take(state.task_ids, 3)
  let active_projects = active_project_ids(state)

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
              Some("claimed"),
              "completed",
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

fn repeat_value(value: a, count: Int) -> List(a) {
  case count <= 0 {
    True -> []
    False -> [value, ..repeat_value(value, count - 1)]
  }
}

fn status_pool_from(distribution: StatusDistribution) -> List(String) {
  let StatusDistribution(
    available: available,
    claimed: claimed,
    completed: completed,
  ) = distribution
  list.append(
    repeat_value("available", available),
    list.append(
      repeat_value("claimed", claimed),
      repeat_value("completed", completed),
    ),
  )
}

fn status_from_pool(pool: List(String), idx: Int) -> String {
  case pool {
    [] -> "available"
    _ -> list_at(pool, idx % list.length(pool), "available")
  }
}

fn member_for_index(members: List(Int), idx: Int, fallback: Int) -> Int {
  list_at_int(members, idx % int.max(1, list.length(members)), fallback)
}

fn timestamp_days_hours(days: Int, hours: Int) -> String {
  "NOW() - INTERVAL '"
  <> int.to_string(days)
  <> " days' + INTERVAL '"
  <> int.to_string(hours)
  <> " hours'"
}

fn compact_options(items: List(Option(a))) -> List(a) {
  items
  |> list.fold([], fn(acc, item) {
    case item {
      Some(value) -> [value, ..acc]
      None -> acc
    }
  })
  |> list.reverse
}

fn task_seed_at(
  items: List(TaskSeedInfo),
  idx: Int,
  default: TaskSeedInfo,
) -> TaskSeedInfo {
  list_at_helper(items, idx, default)
}

fn task_event_options_for_seed(
  seed: TaskSeedInfo,
  idx: Int,
  state: BuildState,
  config: SeedConfig,
) -> List(seed_db.TaskEventInsertOptions) {
  let actor_id = case seed.claimed_by {
    Some(user_id) -> user_id
    None -> seed.created_by
  }
  let days_ago = int.max(1, { idx % config.date_range_days } + 1)
  let claim_time = timestamp_days_hours(days_ago, 2 + { idx % 4 })
  let release_time = timestamp_days_hours(days_ago, 6 + { idx % 5 })
  let reclaim_time = timestamp_days_hours(days_ago, 10 + { idx % 6 })
  let complete_time = timestamp_days_hours(days_ago, 14 + { idx % 8 })

  let claim_event = case seed.status {
    "claimed" ->
      Some(seed_db.TaskEventInsertOptions(
        org_id: state.org_id,
        project_id: seed.project_id,
        task_id: seed.task_id,
        actor_user_id: actor_id,
        event_type: task_events_db.event_type_to_string(
          task_events_db.TaskClaimed,
        ),
        created_at: Some(claim_time),
      ))
    "completed" ->
      Some(seed_db.TaskEventInsertOptions(
        org_id: state.org_id,
        project_id: seed.project_id,
        task_id: seed.task_id,
        actor_user_id: actor_id,
        event_type: task_events_db.event_type_to_string(
          task_events_db.TaskClaimed,
        ),
        created_at: Some(claim_time),
      ))
    _ -> None
  }

  let release_event = case idx % 4 == 0 {
    True ->
      Some(seed_db.TaskEventInsertOptions(
        org_id: state.org_id,
        project_id: seed.project_id,
        task_id: seed.task_id,
        actor_user_id: actor_id,
        event_type: task_events_db.event_type_to_string(
          task_events_db.TaskReleased,
        ),
        created_at: Some(release_time),
      ))
    False -> None
  }

  let reclaim_event = case idx % 6 == 0 {
    True ->
      Some(seed_db.TaskEventInsertOptions(
        org_id: state.org_id,
        project_id: seed.project_id,
        task_id: seed.task_id,
        actor_user_id: actor_id,
        event_type: task_events_db.event_type_to_string(
          task_events_db.TaskClaimed,
        ),
        created_at: Some(reclaim_time),
      ))
    False -> None
  }

  let complete_event = case seed.status {
    "completed" ->
      Some(seed_db.TaskEventInsertOptions(
        org_id: state.org_id,
        project_id: seed.project_id,
        task_id: seed.task_id,
        actor_user_id: actor_id,
        event_type: task_events_db.event_type_to_string(
          task_events_db.TaskCompleted,
        ),
        created_at: Some(complete_time),
      ))
    _ -> None
  }

  compact_options([claim_event, release_event, reclaim_event, complete_event])
}

fn first_claim_events_for_users(
  state: BuildState,
  seeds: List(TaskSeedInfo),
  config: SeedConfig,
) -> List(seed_db.TaskEventInsertOptions) {
  let active_count = config.user_count - 1 - config.inactive_user_count
  let active_users =
    list.drop(state.user_ids, 1)
    |> list.take(active_count)
  let login_days = config.date_range_days / 2
  let offsets = [1, 2, 8, 30]

  active_users
  |> list.index_map(fn(user_id, idx) {
    let seed: TaskSeedInfo =
      task_seed_at(
        seeds,
        idx,
        TaskSeedInfo(
          task_id: list_at_int(state.task_ids, 0, 0),
          project_id: state.org_id,
          status: "claimed",
          created_at: timestamp_days_hours(login_days, 0),
          created_by: state.admin_id,
          claimed_by: Some(user_id),
        ),
      )
    let hours = list_at_int(offsets, idx, 2)
    seed_db.TaskEventInsertOptions(
      org_id: state.org_id,
      project_id: seed.project_id,
      task_id: seed.task_id,
      actor_user_id: user_id,
      event_type: task_events_db.event_type_to_string(
        task_events_db.TaskClaimed,
      ),
      created_at: Some(timestamp_days_hours(login_days, hours)),
    )
  })
}

fn active_project_ids(state: BuildState) -> List(Int) {
  list.filter(state.project_ids, fn(project_id) {
    !list.contains(state.empty_project_ids, project_id)
  })
}

fn claimed_member_id(state: BuildState, project_id: Int, fallback: Int) -> Int {
  let members = members_for_project(state.project_member_ids, project_id)
  let non_admins =
    list.filter(members, fn(user_id) { user_id != state.admin_id })
  case non_admins {
    [first, ..] -> first
    [] -> fallback
  }
}

fn task_types_for_active_projects(
  state: BuildState,
) -> List(#(Int, Int, Int, Int)) {
  list.filter(state.task_type_ids, fn(entry) {
    let #(project_id, _, _, _) = entry
    !list.contains(state.empty_project_ids, project_id)
  })
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
  _project_idx: Int,
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
  status: String,
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

  case status {
    "available" -> base
    "claimed" -> int.max(300, base)
    "completed" -> int.max(900, base)
    _ -> base
  }
}

fn seeded_last_entered_pool_at(
  status: String,
  pool_lifetime_s: Int,
  base_days: Int,
  task_idx: Int,
) -> Option(String) {
  case status {
    "available" ->
      case pool_lifetime_s > 0 {
        True ->
          Some(days_ago_timestamp(int.max(1, base_days - { task_idx % 5 })))
        False -> None
      }
    _ -> None
  }
}
