//// Database operations for milestones.

import domain/milestone as milestone_domain
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
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
  InvalidState(String)
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
      |> list.try_map(from_list_row)
  }
}

pub fn get_milestone(
  db: pog.Connection,
  milestone_id: Int,
) -> Result(milestone_domain.Milestone, MilestoneError) {
  case sql.milestones_get(db, milestone_id) {
    Error(e) -> Error(DbError(e))
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Ok(pog.Returned(rows: [row, ..], ..)) -> from_base_row(row)
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
      description_text(description),
      created_by,
    )
  {
    Error(e) -> Error(DbError(e))
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Ok(pog.Returned(rows: [row, ..], ..)) -> from_create_row(row)
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
      use milestone <- result.try(from_activate_row(row))
      Ok(ActivationSnapshot(
        milestone: milestone,
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
  let name_value = text_update_value(name)
  let description_value = text_update_value(description)

  case sql.milestones_update(db, milestone_id, name_value, description_value) {
    Error(e) -> Error(DbError(e))
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Ok(pog.Returned(rows: [row, ..], ..)) -> from_update_row(row)
  }
}

fn description_text(description: Option(String)) -> String {
  option_helpers.option_to_value(description, "")
}

fn text_update_value(value: Option(String)) -> String {
  option_helpers.option_to_value(value, "__unset__")
}

pub fn delete_milestone(
  db: pog.Connection,
  milestone_id: Int,
) -> Result(Nil, MilestoneError) {
  case get_milestone(db, milestone_id) {
    Error(NotFound) -> Error(NotFound)
    Error(DeleteNotAllowed) -> Error(DeleteNotAllowed)
    Error(InvalidState(state)) -> Error(InvalidState(state))
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
    Ok(pog.Returned(rows: [row, ..], ..)) -> {
      use milestone <- result.try(from_recompute_row(row))
      Ok(Some(milestone))
    }
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

fn parse_state(
  state: String,
) -> Result(milestone_domain.MilestoneState, MilestoneError) {
  case milestone_domain.state_from_string(state) {
    Ok(parsed) -> Ok(parsed)
    Error(milestone_domain.UnknownMilestoneState(raw)) ->
      Error(InvalidState(raw))
  }
}

fn milestone_from_fields(
  id: Int,
  project_id: Int,
  name: String,
  description: String,
  state: String,
  position: Int,
  created_by: Int,
  created_at: String,
  activated_at: String,
  completed_at: String,
) -> Result(milestone_domain.Milestone, MilestoneError) {
  use parsed_state <- result.try(parse_state(state))
  Ok(milestone_domain.Milestone(
    id: id,
    project_id: project_id,
    name: name,
    description: option_helpers.string_to_option(description),
    state: parsed_state,
    position: position,
    created_by: created_by,
    created_at: created_at,
    activated_at: option_helpers.string_to_option(activated_at),
    completed_at: option_helpers.string_to_option(completed_at),
  ))
}

fn from_list_row(
  row: sql.MilestonesListRow,
) -> Result(MilestoneWithProgress, MilestoneError) {
  use milestone <- result.try(milestone_from_fields(
    row.id,
    row.project_id,
    row.name,
    row.description,
    row.state,
    row.position,
    row.created_by,
    row.created_at,
    row.activated_at,
    row.completed_at,
  ))
  Ok(MilestoneWithProgress(
    milestone: milestone,
    cards_total: row.cards_total,
    cards_completed: row.cards_completed,
    tasks_total: row.tasks_total,
    tasks_completed: row.tasks_completed,
  ))
}

fn from_base_row(
  row: sql.MilestonesGetRow,
) -> Result(milestone_domain.Milestone, MilestoneError) {
  milestone_from_fields(
    row.id,
    row.project_id,
    row.name,
    row.description,
    row.state,
    row.position,
    row.created_by,
    row.created_at,
    row.activated_at,
    row.completed_at,
  )
}

fn from_create_row(
  row: sql.MilestonesCreateRow,
) -> Result(milestone_domain.Milestone, MilestoneError) {
  milestone_from_fields(
    row.id,
    row.project_id,
    row.name,
    row.description,
    row.state,
    row.position,
    row.created_by,
    row.created_at,
    row.activated_at,
    row.completed_at,
  )
}

fn from_update_row(
  row: sql.MilestonesUpdateRow,
) -> Result(milestone_domain.Milestone, MilestoneError) {
  milestone_from_fields(
    row.id,
    row.project_id,
    row.name,
    row.description,
    row.state,
    row.position,
    row.created_by,
    row.created_at,
    row.activated_at,
    row.completed_at,
  )
}

fn from_activate_row(
  row: sql.MilestonesActivateRow,
) -> Result(milestone_domain.Milestone, MilestoneError) {
  milestone_from_fields(
    row.id,
    row.project_id,
    row.name,
    row.description,
    row.state,
    row.position,
    row.created_by,
    row.created_at,
    row.activated_at,
    row.completed_at,
  )
}

fn from_recompute_row(
  row: sql.MilestonesRecomputeCompletionRow,
) -> Result(milestone_domain.Milestone, MilestoneError) {
  milestone_from_fields(
    row.id,
    row.project_id,
    row.name,
    row.description,
    row.state,
    row.position,
    row.created_by,
    row.created_at,
    row.activated_at,
    row.completed_at,
  )
}
