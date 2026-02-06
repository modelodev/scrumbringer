//// Database operations for milestones.

import domain/milestone as milestone_domain
import gleam/list
import gleam/option.{type Option, None, Some}
import helpers/option as option_helpers
import pog
import scrumbringer_server/sql

pub type MilestoneWithProgress {
  MilestoneWithProgress(
    milestone: milestone_domain.Milestone,
    cards_total: Int,
    cards_completed: Int,
    tasks_total: Int,
    tasks_completed: Int,
  )
}

pub type ActivationSnapshot {
  ActivationSnapshot(
    milestone: milestone_domain.Milestone,
    cards_released: Int,
    tasks_released: Int,
  )
}

pub type MilestoneError {
  NotFound
  DeleteNotAllowed
  DbError(pog.QueryError)
}

pub fn is_completed(row: MilestoneWithProgress) -> Bool {
  milestone_domain.MilestoneProgress(
    milestone: row.milestone,
    cards_total: row.cards_total,
    cards_completed: row.cards_completed,
    tasks_total: row.tasks_total,
    tasks_completed: row.tasks_completed,
  )
  |> milestone_domain.progress_is_completed
}

pub fn list_milestones(
  db: pog.Connection,
  project_id: Int,
) -> Result(List(MilestoneWithProgress), MilestoneError) {
  case sql.milestones_list(db, project_id) {
    Error(e) -> Error(DbError(e))
    Ok(returned) ->
      returned.rows
      |> list.map(from_list_row)
      |> Ok
  }
}

pub fn get_milestone(
  db: pog.Connection,
  milestone_id: Int,
) -> Result(milestone_domain.Milestone, MilestoneError) {
  case sql.milestones_get(db, milestone_id) {
    Error(e) -> Error(DbError(e))
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(from_base_row(row))
  }
}

pub fn create_milestone(
  db: pog.Connection,
  project_id: Int,
  name: String,
  description: Option(String),
  created_by: Int,
) -> Result(milestone_domain.Milestone, MilestoneError) {
  case
    sql.milestones_create(
      db,
      project_id,
      name,
      option.unwrap(description, ""),
      created_by,
    )
  {
    Error(e) -> Error(DbError(e))
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(from_create_row(row))
  }
}

pub fn activate_milestone(
  db: pog.Connection,
  milestone_id: Int,
  project_id: Int,
) -> Result(ActivationSnapshot, MilestoneError) {
  case sql.milestones_activate(db, milestone_id, project_id) {
    Error(e) -> Error(DbError(e))
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Ok(pog.Returned(rows: [row, ..], ..)) -> {
      Ok(ActivationSnapshot(
        milestone: from_activate_row(row),
        cards_released: row.cards_released,
        tasks_released: row.tasks_released,
      ))
    }
  }
}

pub fn update_milestone(
  db: pog.Connection,
  milestone_id: Int,
  name: Option(String),
  description: Option(String),
) -> Result(milestone_domain.Milestone, MilestoneError) {
  let name_value = option.unwrap(name, "__unset__")
  let description_value = option.unwrap(description, "__unset__")

  case sql.milestones_update(db, milestone_id, name_value, description_value) {
    Error(e) -> Error(DbError(e))
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(from_update_row(row))
  }
}

pub fn delete_milestone(
  db: pog.Connection,
  milestone_id: Int,
) -> Result(Nil, MilestoneError) {
  case get_milestone(db, milestone_id) {
    Error(NotFound) -> Error(NotFound)
    Error(DeleteNotAllowed) -> Error(DeleteNotAllowed)
    Error(DbError(e)) -> Error(DbError(e))
    Ok(_) ->
      case sql.milestones_delete(db, milestone_id) {
        Error(e) -> Error(DbError(e))
        Ok(pog.Returned(rows: [], ..)) -> Error(DeleteNotAllowed)
        Ok(_) -> Ok(Nil)
      }
  }
}

pub fn recompute_completion(
  db: pog.Connection,
  milestone_id: Int,
) -> Result(Option(milestone_domain.Milestone), MilestoneError) {
  case sql.milestones_recompute_completion(db, milestone_id) {
    Error(e) -> Error(DbError(e))
    Ok(pog.Returned(rows: [], ..)) -> Ok(None)
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(Some(from_recompute_row(row)))
  }
}

pub fn get_effective_milestone_for_task(
  db: pog.Connection,
  task_id: Int,
) -> Result(Option(Int), MilestoneError) {
  case sql.milestones_get_effective_for_task(db, task_id) {
    Error(e) -> Error(DbError(e))
    Ok(pog.Returned(rows: [], ..)) -> Ok(None)
    Ok(pog.Returned(rows: [row, ..], ..)) ->
      Ok(option_helpers.int_to_option(row.milestone_id))
  }
}

fn from_list_row(row: sql.MilestonesListRow) -> MilestoneWithProgress {
  MilestoneWithProgress(
    milestone: milestone_domain.Milestone(
      id: row.id,
      project_id: row.project_id,
      name: row.name,
      description: option_helpers.string_to_option(row.description),
      state: milestone_domain.state_from_string(row.state),
      position: row.position,
      created_by: row.created_by,
      created_at: row.created_at,
      activated_at: option_helpers.string_to_option(row.activated_at),
      completed_at: option_helpers.string_to_option(row.completed_at),
    ),
    cards_total: row.cards_total,
    cards_completed: row.cards_completed,
    tasks_total: row.tasks_total,
    tasks_completed: row.tasks_completed,
  )
}

fn from_base_row(row: sql.MilestonesGetRow) -> milestone_domain.Milestone {
  milestone_domain.Milestone(
    id: row.id,
    project_id: row.project_id,
    name: row.name,
    description: option_helpers.string_to_option(row.description),
    state: milestone_domain.state_from_string(row.state),
    position: row.position,
    created_by: row.created_by,
    created_at: row.created_at,
    activated_at: option_helpers.string_to_option(row.activated_at),
    completed_at: option_helpers.string_to_option(row.completed_at),
  )
}

fn from_create_row(row: sql.MilestonesCreateRow) -> milestone_domain.Milestone {
  milestone_domain.Milestone(
    id: row.id,
    project_id: row.project_id,
    name: row.name,
    description: option_helpers.string_to_option(row.description),
    state: milestone_domain.state_from_string(row.state),
    position: row.position,
    created_by: row.created_by,
    created_at: row.created_at,
    activated_at: option_helpers.string_to_option(row.activated_at),
    completed_at: option_helpers.string_to_option(row.completed_at),
  )
}

fn from_update_row(row: sql.MilestonesUpdateRow) -> milestone_domain.Milestone {
  milestone_domain.Milestone(
    id: row.id,
    project_id: row.project_id,
    name: row.name,
    description: option_helpers.string_to_option(row.description),
    state: milestone_domain.state_from_string(row.state),
    position: row.position,
    created_by: row.created_by,
    created_at: row.created_at,
    activated_at: option_helpers.string_to_option(row.activated_at),
    completed_at: option_helpers.string_to_option(row.completed_at),
  )
}

fn from_activate_row(
  row: sql.MilestonesActivateRow,
) -> milestone_domain.Milestone {
  milestone_domain.Milestone(
    id: row.id,
    project_id: row.project_id,
    name: row.name,
    description: option_helpers.string_to_option(row.description),
    state: milestone_domain.state_from_string(row.state),
    position: row.position,
    created_by: row.created_by,
    created_at: row.created_at,
    activated_at: option_helpers.string_to_option(row.activated_at),
    completed_at: option_helpers.string_to_option(row.completed_at),
  )
}

fn from_recompute_row(
  row: sql.MilestonesRecomputeCompletionRow,
) -> milestone_domain.Milestone {
  milestone_domain.Milestone(
    id: row.id,
    project_id: row.project_id,
    name: row.name,
    description: option_helpers.string_to_option(row.description),
    state: milestone_domain.state_from_string(row.state),
    position: row.position,
    created_by: row.created_by,
    created_at: row.created_at,
    activated_at: option_helpers.string_to_option(row.activated_at),
    completed_at: option_helpers.string_to_option(row.completed_at),
  )
}
