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
//// - Build complete scenarios with proper relationships
//// - Manage data pools for realistic names/titles
//// - HT-12 coverage: root pool, parent_card_id, due_date, closed, healthy,
////   saturated, hierarchy, manager, member, capability
////
//// ## Non-responsibilities
////
//// - Direct SQL operations (see seed_db.gleam)
//// - CLI or output (see seed.gleam)

import domain/automation
import domain/card
import domain/org_role
import domain/project_role
import domain/task_status.{
  type TaskPhase, Available, Claimed, Done, Ongoing, Taken,
}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import pog
import scrumbringer_server/seed_db
import scrumbringer_server/use_case/audit_events_db
import scrumbringer_server/use_case/rules_engine

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
    audit_events: Int,
  )
}

/// Seed metadata for task event generation.
pub type TaskSeedInfo {
  TaskSeedInfo(
    task_id: Int,
    project_id: Int,
    status: TaskPhase,
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
      completed: 25,
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
pub fn card_color_pool() -> List(card.CardColor) {
  [
    card.Gray,
    card.Red,
    card.Orange,
    card.Yellow,
    card.Green,
    card.Blue,
    card.Purple,
    card.Pink,
  ]
}

/// Pool of user emails for generated users.
fn user_email_pool() -> List(String) {
  [
    "member@example.com", "pm@example.com", "beta@example.com",
    "dev@example.com", "qa@example.com", "lead@example.com",
    "intern@example.com", "contractor@example.com", "ops@example.com",
    "design@example.com", "data@example.com",
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
      audit_events_count: 0,
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
  use state <- result.try(build_plan_qa_scenarios(db, state, config))
  use state <- result.try(build_people_qa_scenarios(db, state, config))
  use state <- result.try(build_root_cards(db, state, config))
  use state <- result.try(build_audit_events(db, state, config))
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
    audit_events: state.audit_events_count,
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
          org_role: org_role.Member,
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
  let project_names = [
    "Healthy Validation Project",
    "Stress Validation Project",
    "Project Gamma",
  ]
  let names = list.take(project_names, config.project_count)
  let empty_start = int.max(0, list.length(names) - config.empty_project_count)
  let other_users = list.drop(state.user_ids, 1)
  let assignable_users = other_users
  let default_project_members = [state.admin_id, ..assignable_users]

  use _ <- result.try(
    list.try_map(default_project_members, fn(user_id) {
      let role = case user_id == state.admin_id {
        True -> project_role.Manager
        False -> project_role.Member
      }
      seed_db.insert_member(db, default_project_id, user_id, role)
    }),
  )

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
            project_role.Manager,
          ))

          use _ <- result.try(
            list.try_map(assignable_users, fn(user_id) {
              seed_db.insert_member(
                db,
                project_id,
                user_id,
                project_role.Member,
              )
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

  use _ <- result.try(
    list.index_map(project_ids, fn(project_id, idx) {
      seed_db.upsert_project_settings(
        db,
        project_id,
        seeded_healthy_pool_limit(idx),
      )
    })
    |> result.all,
  )

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
        True -> #(project_id, default_project_members)
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

fn seeded_healthy_pool_limit(project_index: Int) -> Int {
  case project_index {
    1 -> 40
    2 -> 6
    _ -> 20
  }
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
          let color = Some(list_at_helper(colors, idx, card.Gray))
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
            seed_rule_options(
              workflow_id: active_wf,
              name: "On Task Done (Active)",
              goal: Some("Auto action on completion"),
              trigger: automation.TaskCompleted(Some(bug_id)),
              active: True,
              created_at: None,
            ),
          ))

          use inactive_rule <- result.try(seed_db.insert_rule(
            db,
            seed_rule_options(
              workflow_id: inactive_wf,
              name: "On Task Done (Inactive)",
              goal: Some("Should not trigger"),
              trigger: automation.TaskCompleted(Some(feature_id)),
              active: True,
              created_at: None,
            ),
          ))

          Ok(#(project_id, [active_rule, inactive_rule]))
        }
        [single_wf], Some(#(bug_id, _feature_id, _task_id)) ->
          seed_db.insert_rule(
            db,
            seed_rule_options(
              workflow_id: single_wf,
              name: "On Task Done",
              goal: Some("Auto action on completion"),
              trigger: automation.TaskCompleted(Some(bug_id)),
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

fn seed_rule_options(
  workflow_id workflow_id: Int,
  name name: String,
  goal goal: Option(String),
  trigger trigger: automation.AutomationTrigger,
  active active: Bool,
  created_at created_at: Option(String),
) -> seed_db.RuleInsertOptions {
  let #(resource_type, _task_type_id, card_depth, to_state) =
    automation.trigger_to_db_values(trigger)

  seed_db.RuleInsertOptions(
    workflow_id: workflow_id,
    name: name,
    goal: goal,
    resource_type: resource_type,
    trigger_kind: automation.trigger_kind(trigger),
    task_type_id: automation.trigger_task_type_id(trigger),
    card_depth: option_from_positive_int(card_depth),
    to_state: to_state,
    active: active,
    created_at: created_at,
  )
}

fn option_from_positive_int(value: Int) -> Option(Int) {
  case value {
    n if n > 0 -> Some(n)
    _ -> None
  }
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
        #(title_for(base_idx, "Task A"), bug_id, Done, Some(card_all_done)),
        #(
          title_for(base_idx + 1, "Task B"),
          feature_id,
          Done,
          Some(card_all_done),
        ),
        #(title_for(base_idx + 2, "Task C"), bug_id, Done, Some(card_mixed)),
        #(
          title_for(base_idx + 3, "Task D"),
          feature_id,
          Claimed(Taken),
          Some(card_mixed),
        ),
        #(
          title_for(base_idx + 4, "Task E"),
          task_id,
          Available,
          Some(card_single),
        ),
        #(title_for(base_idx + 5, "Task F"), bug_id, Available, None),
        #(title_for(base_idx + 6, "Task G"), feature_id, Available, None),
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
          Claimed(_) -> #(
            Some(claimed_user_for),
            Some(days_ago_timestamp(int.max(1, base_days - { idx % 7 }))),
            None,
          )
          Done -> #(
            None,
            None,
            Some(days_ago_timestamp(int.max(1, base_days - { idx % 11 }))),
          )
          Available -> #(None, None, None)
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
            due_date: None,
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

fn build_plan_qa_scenarios(
  db: pog.Connection,
  state: BuildState,
  _config: SeedConfig,
) -> Result(BuildState, String) {
  case active_project_ids(state) {
    [] -> Ok(state)
    [project_id, ..] -> {
      case task_types_for_project(state.task_type_ids, project_id) {
        None -> Ok(state)
        Some(#(bug_id, feature_id, task_id)) -> {
          let member_id = claimed_member_id(state, project_id, state.admin_id)
          use no_capability_type_id <- result.try(seed_db.insert_task_type(
            db,
            project_id,
            "Plan QA - No capability",
            "document-text",
          ))

          use direct_id <- result.try(insert_seed_root_card(
            db,
            state,
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
            state,
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
            state,
            project_id,
            "Plan QA - Closed outcome",
            Some(
              "Closed Plan fixture with completed work for show-closed validation.",
            ),
            card.Closed,
            18,
            Some(days_ago_timestamp(16)),
            Some(days_ago_timestamp(2)),
          ))
          use activation_impact_id <- result.try(insert_seed_root_card(
            db,
            state,
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
            state,
            project_id,
            matrix_id,
            "Plan QA - API lane",
            card.Blue,
          ))
          use ui_id <- result.try(insert_plan_qa_child_card(
            db,
            state,
            project_id,
            matrix_id,
            "Plan QA - UI lane",
            card.Green,
          ))
          use docs_id <- result.try(insert_plan_qa_child_card(
            db,
            state,
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
            Available,
            state.admin_id,
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
            Claimed(Taken),
            state.admin_id,
            Some(member_id),
            5,
            3,
          ))
          use direct_done <- result.try(insert_plan_qa_task(
            db,
            project_id,
            direct_id,
            no_capability_type_id,
            "Plan QA - Direct done no capability",
            Done,
            state.admin_id,
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
            Available,
            state.admin_id,
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
            Available,
            state.admin_id,
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
            Available,
            state.admin_id,
            None,
            5,
            1,
            Some("CURRENT_DATE - 4"),
          ))
          use _ <- result.try(seed_db.insert_task_dependency(
            db,
            api_blocked.task_id,
            api_dependency.task_id,
            state.admin_id,
          ))
          use ui_ongoing <- result.try(insert_plan_qa_task(
            db,
            project_id,
            ui_id,
            feature_id,
            "Plan QA - UI ongoing",
            Claimed(Ongoing),
            state.admin_id,
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
            Available,
            state.admin_id,
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
            Available,
            state.admin_id,
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
            Available,
            state.admin_id,
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
            Available,
            state.admin_id,
            None,
            5,
            1,
            Some("CURRENT_DATE - 2"),
          ))
          use _ <- result.try(seed_db.insert_task_dependency(
            db,
            pool_blocked_overdue.task_id,
            pool_dependency.task_id,
            state.admin_id,
          ))
          use closed_done <- result.try(insert_plan_qa_task(
            db,
            project_id,
            closed_id,
            task_id,
            "Plan QA - Closed done task",
            Done,
            state.admin_id,
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
            Available,
            state.admin_id,
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
            Available,
            state.admin_id,
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
            Available,
            state.admin_id,
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
            Available,
            state.admin_id,
            None,
            2,
            2,
          ))

          let new_card_ids = [
            direct_id,
            matrix_id,
            closed_id,
            activation_impact_id,
            api_id,
            ui_id,
            docs_id,
          ]
          let new_task_seeds = [
            direct_available,
            direct_claimed,
            direct_done,
            api_available,
            api_dependency,
            api_blocked,
            ui_ongoing,
            docs_no_capability,
            pool_ready_due_today,
            pool_dependency,
            pool_blocked_overdue,
            closed_done,
            impact_backend,
            impact_frontend,
            impact_qa,
            impact_docs,
          ]
          let new_task_ids = list.map(new_task_seeds, fn(seed) { seed.task_id })

          Ok(
            BuildState(
              ..state,
              card_ids: list.append(state.card_ids, new_card_ids),
              card_ids_by_project: append_cards_for_project(
                state.card_ids_by_project,
                project_id,
                new_card_ids,
              ),
              task_ids: list.append(state.task_ids, new_task_ids),
              task_seeds: list.append(state.task_seeds, new_task_seeds),
            ),
          )
        }
      }
    }
  }
}

fn build_people_qa_scenarios(
  db: pog.Connection,
  state: BuildState,
  _config: SeedConfig,
) -> Result(BuildState, String) {
  case active_project_ids(state) {
    [] -> Ok(state)
    [project_id, ..] -> {
      case task_types_for_project(state.task_type_ids, project_id) {
        None -> Ok(state)
        Some(#(bug_id, feature_id, task_id)) -> {
          let members =
            members_for_project(state.project_member_ids, project_id)
          let non_admins =
            list.filter(members, fn(user_id) { user_id != state.admin_id })
          let api_owner = list_at_int(non_admins, 0, state.admin_id)
          let blocked_owner = list_at_int(non_admins, 1, state.admin_id)
          let loaded_owner = list_at_int(non_admins, 2, state.admin_id)
          let review_owner = list_at_int(non_admins, 3, state.admin_id)
          let support_owner = list_at_int(non_admins, 4, state.admin_id)

          use coordination_id <- result.try(insert_seed_root_card(
            db,
            state,
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
            state,
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
            state,
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
            state,
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
            state,
            project_id,
            coordination_id,
            "People QA - Review support",
            Some("Task leaf for review and support load distribution."),
            card.Active,
            2,
            Some(days_ago_timestamp(2)),
            None,
          ))

          use admin_ongoing <- result.try(insert_plan_qa_task(
            db,
            project_id,
            release_id,
            task_id,
            "People QA - Facilitate rollout sync",
            Claimed(Ongoing),
            state.admin_id,
            Some(state.admin_id),
            4,
            2,
          ))
          use api_ongoing <- result.try(insert_plan_qa_task(
            db,
            project_id,
            api_id,
            bug_id,
            "People QA - API handoff ongoing",
            Claimed(Ongoing),
            state.admin_id,
            Some(api_owner),
            5,
            2,
          ))
          use api_claimed <- result.try(insert_plan_qa_task(
            db,
            project_id,
            api_id,
            task_id,
            "People QA - API cleanup claimed",
            Claimed(Taken),
            state.admin_id,
            Some(api_owner),
            3,
            1,
          ))
          use release_blocker <- result.try(insert_plan_qa_task(
            db,
            project_id,
            release_id,
            task_id,
            "People QA - Release checklist blocker",
            Available,
            state.admin_id,
            None,
            4,
            1,
          ))
          use blocked_claim <- result.try(insert_plan_qa_task(
            db,
            project_id,
            release_id,
            feature_id,
            "People QA - Blocked deploy approval",
            Claimed(Taken),
            state.admin_id,
            Some(blocked_owner),
            5,
            1,
          ))
          use _ <- result.try(seed_db.insert_task_dependency(
            db,
            blocked_claim.task_id,
            release_blocker.task_id,
            state.admin_id,
          ))
          use loaded_one <- result.try(insert_plan_qa_task(
            db,
            project_id,
            ui_id,
            feature_id,
            "People QA - Polish empty state copy",
            Claimed(Taken),
            state.admin_id,
            Some(loaded_owner),
            3,
            2,
          ))
          use loaded_two <- result.try(insert_plan_qa_task(
            db,
            project_id,
            ui_id,
            feature_id,
            "People QA - Polish mobile wrapping",
            Claimed(Taken),
            state.admin_id,
            Some(loaded_owner),
            3,
            2,
          ))
          use loaded_three <- result.try(insert_plan_qa_task(
            db,
            project_id,
            ui_id,
            bug_id,
            "People QA - Verify filter contrast",
            Claimed(Taken),
            state.admin_id,
            Some(loaded_owner),
            2,
            1,
          ))
          use loaded_four <- result.try(insert_plan_qa_task(
            db,
            project_id,
            ui_id,
            task_id,
            "People QA - Review scope labels",
            Claimed(Taken),
            state.admin_id,
            Some(loaded_owner),
            2,
            1,
          ))
          use review_ongoing <- result.try(insert_plan_qa_task(
            db,
            project_id,
            support_id,
            feature_id,
            "People QA - Review dependency notes",
            Claimed(Ongoing),
            state.admin_id,
            Some(review_owner),
            4,
            2,
          ))
          use review_claimed <- result.try(insert_plan_qa_task(
            db,
            project_id,
            support_id,
            bug_id,
            "People QA - Review blocked owner summary",
            Claimed(Taken),
            state.admin_id,
            Some(review_owner),
            3,
            1,
          ))
          use support_claimed <- result.try(insert_plan_qa_task(
            db,
            project_id,
            support_id,
            task_id,
            "People QA - Support async handoff",
            Claimed(Taken),
            state.admin_id,
            Some(support_owner),
            2,
            1,
          ))
          use support_available <- result.try(insert_plan_qa_task(
            db,
            project_id,
            support_id,
            task_id,
            "People QA - Support intake available",
            Available,
            state.admin_id,
            None,
            2,
            1,
          ))

          let new_card_ids = [
            coordination_id,
            api_id,
            ui_id,
            release_id,
            support_id,
          ]
          let new_task_seeds = [
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
          ]
          let new_task_ids = list.map(new_task_seeds, fn(seed) { seed.task_id })

          Ok(
            BuildState(
              ..state,
              card_ids: list.append(state.card_ids, new_card_ids),
              card_ids_by_project: append_cards_for_project(
                state.card_ids_by_project,
                project_id,
                new_card_ids,
              ),
              task_ids: list.append(state.task_ids, new_task_ids),
              task_seeds: list.append(state.task_seeds, new_task_seeds),
            ),
          )
        }
      }
    }
  }
}

fn insert_plan_qa_child_card(
  db: pog.Connection,
  state: BuildState,
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
      created_by: state.admin_id,
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
  status: TaskPhase,
  created_by: Int,
  claimed_by: Option(Int),
  priority: Int,
  created_days_ago: Int,
) -> Result(TaskSeedInfo, String) {
  insert_plan_qa_task_with_due(
    db,
    project_id,
    card_id,
    type_id,
    title,
    status,
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
  status: TaskPhase,
  created_by: Int,
  claimed_by: Option(Int),
  priority: Int,
  created_days_ago: Int,
  due_date: Option(String),
) -> Result(TaskSeedInfo, String) {
  let created_at = days_ago_timestamp(created_days_ago)
  let #(claimed_by, claimed_at, completed_at) = case status {
    Claimed(_) -> #(
      claimed_by,
      Some(days_ago_timestamp(int.max(1, created_days_ago - 1))),
      None,
    )
    Done -> #(
      None,
      None,
      Some(days_ago_timestamp(int.max(1, created_days_ago - 1))),
    )
    Available -> #(None, None, None)
  }

  use task_id <- result.try(seed_db.insert_task(
    db,
    seed_db.TaskInsertOptions(
      project_id: project_id,
      type_id: type_id,
      title: title,
      description: "Plan QA fixture task",
      priority: priority,
      status: status,
      created_by: created_by,
      claimed_by: claimed_by,
      card_id: Some(card_id),
      created_from_rule_id: None,
      pool_lifetime_s: 3600 * created_days_ago,
      due_date: due_date,
      created_at: Some(created_at),
      claimed_at: claimed_at,
      completed_at: completed_at,
      last_entered_pool_at: Some(created_at),
    ),
  ))

  Ok(TaskSeedInfo(
    task_id: task_id,
    project_id: project_id,
    status: status,
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
  status: TaskPhase,
  created_by: Int,
  claimed_by: Option(Int),
  priority: Int,
  created_days_ago: Int,
  due_date: Option(String),
) -> Result(TaskSeedInfo, String) {
  let created_at = days_ago_timestamp(created_days_ago)
  let #(claimed_by, claimed_at, completed_at) = case status {
    Claimed(_) -> #(
      claimed_by,
      Some(days_ago_timestamp(int.max(1, created_days_ago - 1))),
      None,
    )
    Done -> #(
      None,
      None,
      Some(days_ago_timestamp(int.max(1, created_days_ago - 1))),
    )
    Available -> #(None, None, None)
  }

  use task_id <- result.try(seed_db.insert_task(
    db,
    seed_db.TaskInsertOptions(
      project_id: project_id,
      type_id: type_id,
      title: title,
      description: "Pool QA fixture task",
      priority: priority,
      status: status,
      created_by: created_by,
      claimed_by: claimed_by,
      card_id: None,
      created_from_rule_id: None,
      pool_lifetime_s: 3600 * created_days_ago,
      due_date: due_date,
      created_at: Some(created_at),
      claimed_at: claimed_at,
      completed_at: completed_at,
      last_entered_pool_at: Some(created_at),
    ),
  ))

  Ok(TaskSeedInfo(
    task_id: task_id,
    project_id: project_id,
    status: status,
    created_at: created_at,
    created_by: created_by,
    claimed_by: claimed_by,
  ))
}

fn build_audit_events(
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
            event_type: audit_events_db.TaskCreated,
            created_at: Some(seed.created_at),
          )
        })

      let per_audit_events =
        seeds
        |> list.index_map(fn(seed, idx) {
          task_event_options_for_seed(seed, idx, state, config)
        })
        |> list.flatten

      let per_user_events = first_claim_events_for_users(state, seeds, config)

      let all_events =
        created_events
        |> list.append(per_audit_events)
        |> list.append(per_user_events)

      use _ <- result.try(
        list.try_map(all_events, fn(opts) {
          seed_db.insert_task_event(db, opts)
        }),
      )

      Ok(BuildState(..state, audit_events_count: list.length(all_events)))
    }
  }
}

fn build_root_cards(
  db: pog.Connection,
  state: BuildState,
  _config: SeedConfig,
) -> Result(BuildState, String) {
  let active_projects = active_project_ids(state)

  use _ <- result.try(
    list.index_map(active_projects, fn(project_id, idx) {
      case idx {
        0 -> {
          use discovery_id <- result.try(insert_seed_root_card(
            db,
            state,
            project_id,
            "Discovery - Research stream",
            Some(
              "Early planning root card with exploratory cards, loose research tasks and an explicit empty slot for future work.",
            ),
            card.Draft,
            21,
            None,
            None,
          ))
          use _ <- result.try(seed_db.assign_cards_to_parent_card(
            db,
            project_id,
            discovery_id,
            2,
          ))
          use discovery_tasks_id <- result.try(insert_seed_child_card(
            db,
            state,
            project_id,
            discovery_id,
            "Discovery - Research tasks",
            Some(
              "Task leaf for loose research work while the root remains a pure card group.",
            ),
            card.Draft,
            20,
            None,
            None,
          ))
          use _ <- result.try(
            seed_db.assign_available_pool_tasks_to_parent_card(
              db,
              project_id,
              discovery_tasks_id,
              4,
            ),
          )

          use empty_slot_id <- result.try(insert_seed_root_card(
            db,
            state,
            project_id,
            "Release shell - Empty placeholder",
            Some(
              "Intentional empty root card to exercise empty-state UX and show upcoming planning space.",
            ),
            card.Draft,
            15,
            None,
            None,
          ))
          let _ = empty_slot_id

          use hardening_id <- result.try(insert_seed_root_card(
            db,
            state,
            project_id,
            "Hardening - Pre-release QA",
            Some(
              "Root card packed with QA, polish and rollout preparation so the new root cards UI shows a realistic planning queue.",
            ),
            card.Draft,
            9,
            None,
            None,
          ))
          use _ <- result.try(seed_db.assign_cards_to_parent_card(
            db,
            project_id,
            hardening_id,
            2,
          ))
          use hardening_tasks_id <- result.try(insert_seed_child_card(
            db,
            state,
            project_id,
            hardening_id,
            "Hardening - QA tasks",
            Some(
              "Task leaf for QA and rollout work while the root remains a pure card group.",
            ),
            card.Draft,
            8,
            None,
            None,
          ))
          use _ <- result.try(
            seed_db.assign_available_pool_tasks_to_parent_card(
              db,
              project_id,
              hardening_tasks_id,
              3,
            ),
          )

          use compliance_id <- result.try(insert_seed_root_card(
            db,
            state,
            project_id,
            "Compliance - Documentation sweep",
            Some(
              "Ready root card dominated by loose documentation and compliance tasks, useful to validate the exception treatment in the new view.",
            ),
            card.Draft,
            5,
            None,
            None,
          ))
          use _ <- result.try(seed_db.assign_cards_to_parent_card(
            db,
            project_id,
            compliance_id,
            1,
          ))
          use compliance_tasks_id <- result.try(insert_seed_child_card(
            db,
            state,
            project_id,
            compliance_id,
            "Compliance - Review tasks",
            Some(
              "Task leaf for documentation checks while the root remains a pure card group.",
            ),
            card.Draft,
            4,
            None,
            None,
          ))
          use _ <- result.try(
            seed_db.assign_available_pool_tasks_to_parent_card(
              db,
              project_id,
              compliance_tasks_id,
              2,
            ),
          )
          Ok(Nil)
        }

        1 -> {
          use completed_id <- result.try(insert_seed_root_card(
            db,
            state,
            project_id,
            "Release 1.4 - Closed",
            Some(
              "Recently completed root card used to exercise historical metrics and completed content sections.",
            ),
            card.Closed,
            28,
            Some(days_ago_timestamp(18)),
            Some(days_ago_timestamp(6)),
          ))
          use _ <- result.try(seed_db.assign_cards_to_parent_card(
            db,
            project_id,
            completed_id,
            2,
          ))
          use completed_tasks_id <- result.try(insert_seed_child_card(
            db,
            state,
            project_id,
            completed_id,
            "Release 1.4 - Completion tasks",
            Some(
              "Closed task leaf preserving completed task coverage without mixing child kinds.",
            ),
            card.Closed,
            17,
            Some(days_ago_timestamp(16)),
            Some(days_ago_timestamp(6)),
          ))
          use _ <- result.try(
            seed_db.assign_completed_pool_tasks_to_parent_card(
              db,
              project_id,
              completed_tasks_id,
              4,
            ),
          )

          use active_id <- result.try(insert_seed_root_card(
            db,
            state,
            project_id,
            "Release 1.5 - Launch train",
            Some(
              "The currently active root card with in-flight delivery cards and a dedicated task leaf.",
            ),
            card.Active,
            12,
            Some(days_ago_timestamp(3)),
            None,
          ))
          use _ <- result.try(seed_db.assign_cards_to_parent_card(
            db,
            project_id,
            active_id,
            2,
          ))
          use active_tasks_id <- result.try(insert_seed_child_card(
            db,
            state,
            project_id,
            active_id,
            "Release 1.5 - Delivery tasks",
            Some(
              "Active task leaf with launch-train work while the root remains a pure card group.",
            ),
            card.Active,
            10,
            Some(days_ago_timestamp(3)),
            None,
          ))
          use _ <- result.try(seed_db.assign_claimed_pool_tasks_to_parent_card(
            db,
            project_id,
            active_tasks_id,
            2,
          ))
          use _ <- result.try(
            seed_db.assign_available_pool_tasks_to_parent_card(
              db,
              project_id,
              active_tasks_id,
              3,
            ),
          )

          use backlog_id <- result.try(insert_seed_root_card(
            db,
            state,
            project_id,
            "Release 1.6 - Next wave",
            Some(
              "A ready root card with enough queued cards and a task leaf to preview the upcoming tranche of work.",
            ),
            card.Draft,
            6,
            None,
            None,
          ))
          use _ <- result.try(seed_db.assign_cards_to_parent_card(
            db,
            project_id,
            backlog_id,
            2,
          ))
          use backlog_tasks_id <- result.try(insert_seed_child_card(
            db,
            state,
            project_id,
            backlog_id,
            "Release 1.6 - Queued tasks",
            Some(
              "Task leaf for upcoming loose work while the root remains a pure card group.",
            ),
            card.Draft,
            5,
            None,
            None,
          ))
          use _ <- result.try(
            seed_db.assign_available_pool_tasks_to_parent_card(
              db,
              project_id,
              backlog_tasks_id,
              3,
            ),
          )

          use design_spike_id <- result.try(insert_seed_root_card(
            db,
            state,
            project_id,
            "Design spike - Future experiments",
            Some(
              "Small ready root card with discovery cards and a task leaf to keep the list visually varied.",
            ),
            card.Draft,
            2,
            None,
            None,
          ))
          use _ <- result.try(seed_db.assign_cards_to_parent_card(
            db,
            project_id,
            design_spike_id,
            1,
          ))
          use design_spike_tasks_id <- result.try(insert_seed_child_card(
            db,
            state,
            project_id,
            design_spike_id,
            "Design spike - Research tasks",
            Some(
              "Task leaf for discovery work while the root remains a pure card group.",
            ),
            card.Draft,
            2,
            None,
            None,
          ))
          use _ <- result.try(
            seed_db.assign_available_pool_tasks_to_parent_card(
              db,
              project_id,
              design_spike_tasks_id,
              2,
            ),
          )

          use placeholder_id <- result.try(insert_seed_root_card(
            db,
            state,
            project_id,
            "Partner rollout - Placeholder",
            Some(
              "Explicitly empty ready root card reserved for partner rollout planning and empty-state validation.",
            ),
            card.Draft,
            2,
            None,
            None,
          ))
          let _ = placeholder_id
          Ok(Nil)
        }

        _ -> {
          use prep_id <- result.try(insert_seed_root_card(
            db,
            state,
            project_id,
            "Client refresh - Preparation",
            Some(
              "Primary ready root card with several child cards and a task leaf for visual inspection of the new split view.",
            ),
            card.Draft,
            11,
            None,
            None,
          ))
          use _ <- result.try(seed_db.assign_cards_to_parent_card(
            db,
            project_id,
            prep_id,
            3,
          ))
          use prep_tasks_id <- result.try(insert_seed_child_card(
            db,
            state,
            project_id,
            prep_id,
            "Client refresh - Prep tasks",
            Some(
              "Task leaf for preparation work while the root remains a pure card group.",
            ),
            card.Draft,
            10,
            None,
            None,
          ))
          use _ <- result.try(
            seed_db.assign_available_pool_tasks_to_parent_card(
              db,
              project_id,
              prep_tasks_id,
              4,
            ),
          )

          use active_bugfix_id <- result.try(insert_seed_root_card(
            db,
            state,
            project_id,
            "Hotfix train - Active",
            Some(
              "Active bugfix root card so the seed includes another project with live root card context.",
            ),
            card.Active,
            5,
            Some(days_ago_timestamp(1)),
            None,
          ))
          use _ <- result.try(seed_db.assign_cards_to_parent_card(
            db,
            project_id,
            active_bugfix_id,
            1,
          ))
          use active_bugfix_tasks_id <- result.try(insert_seed_child_card(
            db,
            state,
            project_id,
            active_bugfix_id,
            "Hotfix train - Repair tasks",
            Some(
              "Task leaf for active bugfix work while the root remains a pure card group.",
            ),
            card.Active,
            4,
            Some(days_ago_timestamp(1)),
            None,
          ))
          use _ <- result.try(seed_db.assign_claimed_pool_tasks_to_parent_card(
            db,
            project_id,
            active_bugfix_tasks_id,
            1,
          ))
          use _ <- result.try(
            seed_db.assign_available_pool_tasks_to_parent_card(
              db,
              project_id,
              active_bugfix_tasks_id,
              1,
            ),
          )

          use follow_up_id <- result.try(insert_seed_root_card(
            db,
            state,
            project_id,
            "Follow-up polish",
            Some(
              "Secondary ready root card with a small amount of work to make the root card list feel more realistic.",
            ),
            card.Draft,
            3,
            None,
            None,
          ))
          use _ <- result.try(
            seed_db.assign_available_pool_tasks_to_parent_card(
              db,
              project_id,
              follow_up_id,
              2,
            ),
          )

          use card_heavy_id <- result.try(insert_seed_root_card(
            db,
            state,
            project_id,
            "Ops cleanup - Ready",
            Some(
              "Card-heavy ready root card, useful to contrast against the more ad-hoc planning root cards.",
            ),
            card.Draft,
            2,
            None,
            None,
          ))
          use _ <- result.try(seed_db.assign_cards_to_parent_card(
            db,
            project_id,
            card_heavy_id,
            1,
          ))

          use empty_ready_id <- result.try(insert_seed_root_card(
            db,
            state,
            project_id,
            "Archive prep - Empty",
            Some(
              "Another ready-but-empty root card so the left pane shows multiple realistic placeholders instead of a single artificial case.",
            ),
            card.Draft,
            1,
            None,
            None,
          ))
          let _ = empty_ready_id
          Ok(Nil)
        }
      }
    })
    |> result.all,
  )

  Ok(state)
}

fn insert_seed_root_card(
  db: pog.Connection,
  state: BuildState,
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
      created_by: state.admin_id,
      created_at: Some(days_ago_timestamp(created_days_ago)),
      activated_at: activated_at,
      completed_at: completed_at,
    ),
  )
}

fn insert_seed_child_card(
  db: pog.Connection,
  state: BuildState,
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
    state,
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

fn build_task_positions(
  db: pog.Connection,
  state: BuildState,
  _config: SeedConfig,
) -> Result(BuildState, String) {
  let tasks =
    state.task_seeds
    |> list.filter(fn(seed) { seed.status == Available })
    |> list.map(fn(seed) { seed.task_id })
  let users = list.take(state.user_ids, 3)

  case tasks, users {
    [], _ -> Ok(state)
    _, [] -> Ok(state)
    _, _ -> {
      use _ <- result.try(
        list.index_map(tasks, fn(task_id, idx) {
          let x = { idx % 4 } * 156
          let y = { idx / 4 } * 152

          list.try_map(users, fn(user_id) {
            seed_db.insert_task_position(db, task_id, user_id, x, y)
          })
        })
        |> result.all
        |> result.map(list.flatten),
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
    |> list.filter(fn(seed) { is_claimed_status(seed.status) })
    |> list.map(fn(seed) { seed.task_id })
  let completed_tasks =
    state.task_seeds
    |> list.filter(fn(seed) { is_completed_status(seed.status) })
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
              ended_reason: Some("task_closed"),
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
              Some(Claimed(Taken)),
              Done,
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

fn status_pool_from(distribution: StatusDistribution) -> List(TaskPhase) {
  let StatusDistribution(
    available: available,
    claimed: claimed,
    completed: completed,
  ) = distribution
  list.append(
    repeat_value(Available, available),
    list.append(
      repeat_value(Claimed(Taken), claimed),
      repeat_value(Done, completed),
    ),
  )
}

fn status_from_pool(pool: List(TaskPhase), idx: Int) -> TaskPhase {
  case pool {
    [] -> Available
    _ -> list_at_helper(pool, idx % list.length(pool), Available)
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
    Claimed(_) ->
      Some(seed_db.TaskEventInsertOptions(
        org_id: state.org_id,
        project_id: seed.project_id,
        task_id: seed.task_id,
        actor_user_id: actor_id,
        event_type: audit_events_db.TaskClaimed,
        created_at: Some(claim_time),
      ))
    Done ->
      Some(seed_db.TaskEventInsertOptions(
        org_id: state.org_id,
        project_id: seed.project_id,
        task_id: seed.task_id,
        actor_user_id: actor_id,
        event_type: audit_events_db.TaskClaimed,
        created_at: Some(claim_time),
      ))
    Available -> None
  }

  let release_event = case idx % 4 == 0 {
    True ->
      Some(seed_db.TaskEventInsertOptions(
        org_id: state.org_id,
        project_id: seed.project_id,
        task_id: seed.task_id,
        actor_user_id: actor_id,
        event_type: audit_events_db.TaskReleased,
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
        event_type: audit_events_db.TaskClaimed,
        created_at: Some(reclaim_time),
      ))
    False -> None
  }

  let complete_event = case seed.status {
    Done ->
      Some(seed_db.TaskEventInsertOptions(
        org_id: state.org_id,
        project_id: seed.project_id,
        task_id: seed.task_id,
        actor_user_id: actor_id,
        event_type: audit_events_db.TaskClosed,
        created_at: Some(complete_time),
      ))
    Available | Claimed(_) -> None
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
          status: Claimed(Taken),
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
      event_type: audit_events_db.TaskClaimed,
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
  status: TaskPhase,
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
    Available -> base
    Claimed(_) -> int.max(300, base)
    Done -> int.max(900, base)
  }
}

fn seeded_last_entered_pool_at(
  status: TaskPhase,
  pool_lifetime_s: Int,
  base_days: Int,
  task_idx: Int,
) -> Option(String) {
  case status {
    Available ->
      case pool_lifetime_s > 0 {
        True ->
          Some(days_ago_timestamp(int.max(1, base_days - { task_idx % 5 })))
        False -> None
      }
    Claimed(_) | Done -> None
  }
}

fn is_claimed_status(status: TaskPhase) -> Bool {
  case status {
    Claimed(_) -> True
    Available | Done -> False
  }
}

fn is_completed_status(status: TaskPhase) -> Bool {
  case status {
    Done -> True
    Available | Claimed(_) -> False
  }
}
