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

/// Internal state during seed building.
type BuildState {
  BuildState(
    org_id: Int,
    admin_id: Int,
    user_ids: List(Int),
    project_ids: List(Int),
    project_member_ids: List(#(Int, List(Int))),
    capability_ids: List(#(Int, Int, Int, Int)),
    task_type_ids: List(#(Int, Int, Int, Int)),
    card_ids: List(Int),
    card_ids_by_project: List(#(Int, List(Int))),
    workflow_ids: List(Int),
    workflow_ids_by_project: List(#(Int, List(Int))),
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

/// Realistic configuration with edge cases and variability.
pub fn realistic_config() -> SeedConfig {
  SeedConfig(
    user_count: 6,
    inactive_user_count: 2,
    project_count: 3,
    empty_project_count: 0,
    tasks_per_project: 7,
    priority_distribution: [1, 2, 3, 3, 3, 4, 5],
    status_distribution: StatusDistribution(
      available: 25,
      claimed: 45,
      completed: 30,
    ),
    cards_per_project: 4,
    empty_card_count: 1,
    workflows_per_project: 2,
    inactive_workflow_count: 1,
    empty_workflow_count: 0,
    date_range_days: 30,
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
    "pm@example.com", "member@example.com", "beta@example.com",
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
      project_member_ids: [],
      capability_ids: [],
      task_type_ids: [],
      card_ids: [],
      card_ids_by_project: [],
      workflow_ids: [],
      workflow_ids_by_project: [],
      rule_ids: [],
      task_ids: [],
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
  let other_users = list.drop(state.user_ids, 1)
  let assignable_users = case list.reverse(other_users) {
    [] -> []
    [_unassigned, ..rest] -> list.reverse(rest)
  }

  use project_ids <- result.try(
    list.index_map(names, fn(name, idx) {
      let days_ago = config.date_range_days - { idx * 5 }
      use project_id <- result.try(seed_db.insert_project(
        db,
        state.org_id,
        name,
        Some(days_ago_timestamp(days_ago)),
      ))

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

      Ok(project_id)
    })
    |> result.all,
  )

  let project_ids = [default_project_id, ..project_ids]
  let project_members =
    list.map(project_ids, fn(project_id) {
      case project_id == default_project_id {
        True -> #(project_id, [])
        False -> #(project_id, [state.admin_id, ..assignable_users])
      }
    })

  Ok(
    BuildState(
      ..state,
      project_ids: project_ids,
      project_member_ids: project_members,
    ),
  )
}

fn build_capabilities(
  db: pog.Connection,
  state: BuildState,
  _config: SeedConfig,
) -> Result(BuildState, String) {
  let active_projects = state.project_ids
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
  let active_projects = state.project_ids
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
  let active_projects = state.project_ids
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
  _config: SeedConfig,
) -> Result(BuildState, String) {
  use rule_ids_nested <- result.try(
    list.try_map(state.workflow_ids_by_project, fn(pair) {
      let #(project_id, wf_ids) = pair
      let task_types = task_types_for_project(state.task_type_ids, project_id)

      case wf_ids, task_types {
        [], _ -> Ok([])
        _, None -> Ok([])
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

          Ok([active_rule, inactive_rule])
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
          |> result.map(fn(id) { [id] })
        _, _ -> Ok([])
      }
    }),
  )

  Ok(BuildState(..state, rule_ids: list.flatten(rule_ids_nested)))
}

fn build_tasks(
  db: pog.Connection,
  state: BuildState,
  config: SeedConfig,
) -> Result(BuildState, String) {
  let titles = task_title_pool()
  let priorities = config.priority_distribution

  use task_ids_nested <- result.try(
    list.index_map(state.task_type_ids, fn(types, proj_idx) {
      let #(project_id, bug_id, feature_id, task_id) = types
      let cards_for_project =
        cards_for_project(state.card_ids_by_project, project_id)

      let _card_empty = list_at_int(cards_for_project, 0, 0)
      let card_all_done = list_at_int(cards_for_project, 1, 0)
      let card_mixed = list_at_int(cards_for_project, 2, 0)
      let card_single = list_at_int(cards_for_project, 3, 0)

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

      list.index_map(tasks, fn(task_def, idx) {
        let #(title, type_id, status, card_id) = task_def
        let priority = list_at_int(priorities, idx % list.length(priorities), 3)
        let claimed_by = case status {
          "claimed" -> Some(creator_id)
          _ -> None
        }
        let claimed_at = case status {
          "claimed" -> Some(days_ago_timestamp(config.date_range_days / 2))
          _ -> None
        }
        let completed_at = case status {
          "completed" -> Some(days_ago_timestamp(config.date_range_days / 4))
          _ -> None
        }

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
      |> result.all
    })
    |> result.all,
  )

  Ok(BuildState(..state, task_ids: list.flatten(task_ids_nested)))
}

fn build_task_events(
  db: pog.Connection,
  state: BuildState,
  _config: SeedConfig,
) -> Result(BuildState, String) {
  let active_projects = state.project_ids

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
  let tasks = list.take(state.task_ids, 6)
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
  let active_projects = state.project_ids

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
