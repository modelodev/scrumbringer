//// Database operations for cards (fichas).
////
//// ## Mission
////
//// Manages CRUD operations for cards and their derived state.
////
//// ## Responsibilities
////
//// - List cards with derived state
//// - Create, update, delete cards
//// - Validate delete constraints (no tasks)
//// - Derive card state from task counts

import domain/card.{
  type CardState, Pendiente, derive_state as shared_derive_state,
  state_to_string as shared_state_to_string,
}
import domain/milestone
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import helpers/option as option_helpers
import pog
import scrumbringer_server/sql

// =============================================================================
// Types
// =============================================================================

/// A card with its derived state.
pub type Card {
  Card(
    id: Int,
    project_id: Int,
    milestone_id: Option(Int),
    title: String,
    description: String,
    color: String,
    state: CardState,
    task_count: Int,
    completed_count: Int,
    created_by: Int,
    created_at: String,
    has_new_notes: Bool,
  )
}

/// Errors for card operations.
pub type CardError {
  CardNotFound
  CardHasTasks(task_count: Int)
  InvalidMilestone
  InvalidMovePoolToMilestone
  DbError(pog.QueryError)
}

// =============================================================================
// Public API
// =============================================================================

/// List all cards for a project with derived state.
pub fn list_cards(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
) -> Result(List(Card), pog.QueryError) {
  use returned <- result.try(sql.cards_list(db, project_id, user_id))

  let cards =
    returned.rows
    |> list.map(fn(row) {
      card_from_counts(
        row.id,
        row.project_id,
        row.milestone_id,
        row.title,
        row.description,
        row.color,
        row.created_by,
        row.created_at,
        row.task_count,
        row.completed_count,
        row.available_count,
        row.has_new_notes,
      )
    })

  Ok(cards)
}

/// Get a single card by ID with derived state.
pub fn get_card(
  db: pog.Connection,
  card_id: Int,
  user_id: Int,
) -> Result(Card, CardError) {
  case sql.cards_get(db, card_id, user_id) {
    Error(e) -> Error(DbError(e))
    Ok(pog.Returned(rows: [], ..)) -> Error(CardNotFound)
    Ok(pog.Returned(rows: [row, ..], ..)) ->
      Ok(card_from_counts(
        row.id,
        row.project_id,
        row.milestone_id,
        row.title,
        row.description,
        row.color,
        row.created_by,
        row.created_at,
        row.task_count,
        row.completed_count,
        row.available_count,
        row.has_new_notes,
      ))
  }
}

fn card_from_counts(
  id: Int,
  project_id: Int,
  milestone_id: Int,
  title: String,
  description: String,
  color: String,
  created_by: Int,
  created_at: String,
  task_count: Int,
  completed_count: Int,
  available_count: Int,
  has_new_notes: Bool,
) -> Card {
  let state = derive_card_state(task_count, completed_count, available_count)

  Card(
    id: id,
    project_id: project_id,
    milestone_id: option_helpers.int_to_option(milestone_id),
    title: title,
    description: description,
    color: color,
    state: state,
    task_count: task_count,
    completed_count: completed_count,
    created_by: created_by,
    created_at: created_at,
    has_new_notes: has_new_notes,
  )
}

/// Create a new card.
pub fn create_card(
  db: pog.Connection,
  project_id: Int,
  milestone_id: Option(Int),
  title: String,
  description: Option(String),
  color: Option(String),
  created_by: Int,
) -> Result(Card, CardError) {
  case validate_milestone_for_create(db, project_id, milestone_id) {
    Error(e) -> Error(e)
    Ok(Nil) ->
      create_card_row(
        db,
        project_id,
        milestone_id,
        title,
        description,
        color,
        created_by,
      )
  }
}

fn create_card_row(
  db: pog.Connection,
  project_id: Int,
  milestone_id: Option(Int),
  title: String,
  description: Option(String),
  color: Option(String),
  created_by: Int,
) -> Result(Card, CardError) {
  let desc = option.unwrap(description, "")
  let col = option.unwrap(color, "")

  case
    sql.cards_create(
      db,
      project_id,
      title,
      desc,
      col,
      created_by,
      option_helpers.option_to_value(milestone_id, 0),
    )
  {
    Error(e) -> Error(DbError(e))
    Ok(returned) ->
      case returned.rows {
        [row, ..] -> {
          Ok(Card(
            id: row.id,
            project_id: row.project_id,
            milestone_id: option_helpers.int_to_option(row.milestone_id),
            title: row.title,
            description: row.description,
            color: row.color,
            state: Pendiente,
            task_count: 0,
            completed_count: 0,
            created_by: row.created_by,
            created_at: row.created_at,
            has_new_notes: False,
          ))
        }
        _ -> {
          // Should not happen, but handle gracefully
          Error(DbError(pog.UnexpectedArgumentCount(5, 0)))
        }
      }
  }
}

// Justification: nested case improves clarity for branching logic.
/// Update a card's title, description, and color.
pub fn update_card(
  db: pog.Connection,
  card_id: Int,
  milestone_id: Option(Int),
  title: String,
  description: Option(String),
  color: Option(String),
  user_id: Int,
) -> Result(Card, CardError) {
  use current <- result.try(get_card(db, card_id, user_id))
  use _ <- result.try(validate_milestone_for_update(
    db,
    current.project_id,
    current.milestone_id,
    milestone_id,
  ))

  let desc = option.unwrap(description, "")
  let col = option.unwrap(color, "")

  case
    sql.cards_update(db, card_id, title, desc, col, case milestone_id {
      Some(id) -> id
      None -> -1
    })
  {
    Error(e) -> Error(DbError(e))
    Ok(pog.Returned(rows: [], ..)) -> Error(CardNotFound)
    Ok(pog.Returned(rows: [row, ..], ..)) -> {
      // After update, we need to get current task counts
      case sql.cards_get(db, card_id, user_id) {
        Error(e) -> Error(DbError(e))
        Ok(pog.Returned(rows: [], ..)) -> Error(CardNotFound)
        Ok(pog.Returned(rows: [full_row, ..], ..)) -> {
          let state =
            derive_card_state(
              full_row.task_count,
              full_row.completed_count,
              full_row.available_count,
            )
          Ok(Card(
            id: row.id,
            project_id: row.project_id,
            milestone_id: option_helpers.int_to_option(row.milestone_id),
            title: row.title,
            description: row.description,
            color: row.color,
            state: state,
            task_count: full_row.task_count,
            completed_count: full_row.completed_count,
            created_by: row.created_by,
            created_at: row.created_at,
            has_new_notes: full_row.has_new_notes,
          ))
        }
      }
    }
  }
}

/// Delete a card (only if it has no tasks).
pub fn delete_card(db: pog.Connection, card_id: Int) -> Result(Nil, CardError) {
  // First check if card has tasks
  case sql.cards_task_count(db, card_id) {
    Error(e) -> Error(DbError(e))
    Ok(pog.Returned(rows: [row, ..], ..)) if row.task_count > 0 -> {
      Error(CardHasTasks(row.task_count))
    }
    _ -> {
      // No tasks, proceed with delete
      case sql.cards_delete(db, card_id) {
        Error(e) -> Error(DbError(e))
        Ok(_) -> Ok(Nil)
      }
    }
  }
}

// =============================================================================
// State Derivation (delegated to shared module)
// =============================================================================

/// Derive card state from task counts.
pub const derive_card_state = shared_derive_state

/// Convert CardState to string for API responses.
pub const state_to_string = shared_state_to_string

fn validate_milestone_for_create(
  db: pog.Connection,
  project_id: Int,
  milestone_id: Option(Int),
) -> Result(Nil, CardError) {
  case milestone_id {
    None -> Ok(Nil)
    Some(id) if id <= 0 -> Ok(Nil)
    Some(id) ->
      case get_milestone_state(db, id, project_id) {
        Ok(milestone.Ready) -> Ok(Nil)
        Ok(_) -> Error(InvalidMilestone)
        Error(e) -> Error(e)
      }
  }
}

fn validate_milestone_for_update(
  db: pog.Connection,
  project_id: Int,
  current_milestone_id: Option(Int),
  target_milestone_id: Option(Int),
) -> Result(Nil, CardError) {
  case target_milestone_id {
    None ->
      case current_milestone_id {
        Some(id) ->
          case get_milestone_state(db, id, project_id) {
            Ok(milestone.Ready) -> Ok(Nil)
            Ok(_) -> Error(InvalidMovePoolToMilestone)
            Error(e) -> Error(e)
          }
        None -> Ok(Nil)
      }
    Some(target_id) if target_id <= 0 -> Ok(Nil)
    Some(target_id) ->
      case current_milestone_id {
        Some(current_id) ->
          case
            get_milestone_state(db, current_id, project_id),
            get_milestone_state(db, target_id, project_id)
          {
            Ok(milestone.Ready), Ok(milestone.Ready) -> Ok(Nil)
            Ok(_), Ok(_) -> Error(InvalidMovePoolToMilestone)
            Error(e), _ -> Error(e)
            _, Error(e) -> Error(e)
          }
        None -> Error(InvalidMovePoolToMilestone)
      }
  }
}

fn get_milestone_state(
  db: pog.Connection,
  milestone_id: Int,
  project_id: Int,
) -> Result(milestone.MilestoneState, CardError) {
  case sql.milestones_get(db, milestone_id) {
    Error(e) -> Error(DbError(e))
    Ok(pog.Returned(rows: [], ..)) -> Error(InvalidMilestone)
    Ok(pog.Returned(rows: [row, ..], ..)) ->
      case row.project_id == project_id {
        True -> Ok(milestone.state_from_string(row.state))
        False -> Error(InvalidMilestone)
      }
  }
}
