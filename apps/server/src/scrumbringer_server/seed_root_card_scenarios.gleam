//// Root-card seed scenario.
////
//// Creates hierarchy fixtures with root cards, child task leaves, empty
//// placeholders, and pool-task assignments for Plan and root-card validation.

import domain/card
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import pog
import scrumbringer_server/seed_db

pub type Context {
  Context(admin_id: Int, active_project_ids: List(Int))
}

pub fn build(db: pog.Connection, context: Context) -> Result(Nil, String) {
  use _ <- result.try(
    list.index_map(context.active_project_ids, fn(project_id, idx) {
      case idx {
        0 -> build_default_project(db, context.admin_id, project_id)
        1 -> build_release_project(db, context.admin_id, project_id)
        _ -> build_followup_project(db, context.admin_id, project_id)
      }
    })
    |> result.all,
  )

  Ok(Nil)
}

fn build_default_project(
  db: pog.Connection,
  admin_id: Int,
  project_id: Int,
) -> Result(Nil, String) {
  use discovery_id <- result.try(insert_seed_root_card(
    db,
    admin_id,
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
    admin_id,
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
  use _ <- result.try(seed_db.assign_available_pool_tasks_to_parent_card(
    db,
    project_id,
    discovery_tasks_id,
    4,
  ))

  use empty_slot_id <- result.try(insert_seed_root_card(
    db,
    admin_id,
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
    admin_id,
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
    admin_id,
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
  use _ <- result.try(seed_db.assign_available_pool_tasks_to_parent_card(
    db,
    project_id,
    hardening_tasks_id,
    3,
  ))

  use compliance_id <- result.try(insert_seed_root_card(
    db,
    admin_id,
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
    admin_id,
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
  use _ <- result.try(seed_db.assign_available_pool_tasks_to_parent_card(
    db,
    project_id,
    compliance_tasks_id,
    2,
  ))

  Ok(Nil)
}

fn build_release_project(
  db: pog.Connection,
  admin_id: Int,
  project_id: Int,
) -> Result(Nil, String) {
  use completed_id <- result.try(insert_seed_root_card(
    db,
    admin_id,
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
    admin_id,
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
  use _ <- result.try(seed_db.assign_completed_pool_tasks_to_parent_card(
    db,
    project_id,
    completed_tasks_id,
    4,
  ))

  use active_id <- result.try(insert_seed_root_card(
    db,
    admin_id,
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
    admin_id,
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
  use _ <- result.try(seed_db.assign_available_pool_tasks_to_parent_card(
    db,
    project_id,
    active_tasks_id,
    3,
  ))

  use backlog_id <- result.try(insert_seed_root_card(
    db,
    admin_id,
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
    admin_id,
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
  use _ <- result.try(seed_db.assign_available_pool_tasks_to_parent_card(
    db,
    project_id,
    backlog_tasks_id,
    3,
  ))

  use design_spike_id <- result.try(insert_seed_root_card(
    db,
    admin_id,
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
    admin_id,
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
  use _ <- result.try(seed_db.assign_available_pool_tasks_to_parent_card(
    db,
    project_id,
    design_spike_tasks_id,
    2,
  ))

  use placeholder_id <- result.try(insert_seed_root_card(
    db,
    admin_id,
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

fn build_followup_project(
  db: pog.Connection,
  admin_id: Int,
  project_id: Int,
) -> Result(Nil, String) {
  use prep_id <- result.try(insert_seed_root_card(
    db,
    admin_id,
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
    admin_id,
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
  use _ <- result.try(seed_db.assign_available_pool_tasks_to_parent_card(
    db,
    project_id,
    prep_tasks_id,
    4,
  ))

  use active_bugfix_id <- result.try(insert_seed_root_card(
    db,
    admin_id,
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
    admin_id,
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
  use _ <- result.try(seed_db.assign_available_pool_tasks_to_parent_card(
    db,
    project_id,
    active_bugfix_tasks_id,
    1,
  ))

  use follow_up_id <- result.try(insert_seed_root_card(
    db,
    admin_id,
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
  use _ <- result.try(seed_db.assign_available_pool_tasks_to_parent_card(
    db,
    project_id,
    follow_up_id,
    2,
  ))

  use card_heavy_id <- result.try(insert_seed_root_card(
    db,
    admin_id,
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
    admin_id,
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

fn days_ago_timestamp(days: Int) -> String {
  "NOW() - INTERVAL '" <> int.to_string(days) <> " days'"
}
