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

import gleam/list
import gleam/option.{type Option}
import gleam/result
import pog
import scrumbringer_server/sql

// =============================================================================
// Types
// =============================================================================

/// Card state derived from tasks.
pub type CardState {
  Pendiente
  EnCurso
  Cerrada
}

/// A card with its derived state.
pub type Card {
  Card(
    id: Int,
    project_id: Int,
    title: String,
    description: String,
    color: String,
    state: CardState,
    task_count: Int,
    completed_count: Int,
    created_by: Int,
    created_at: String,
  )
}

/// Errors for card operations.
pub type CardError {
  CardNotFound
  CardHasTasks(task_count: Int)
  DbError(pog.QueryError)
}

// =============================================================================
// Public API
// =============================================================================

/// List all cards for a project with derived state.
pub fn list_cards(
  db: pog.Connection,
  project_id: Int,
) -> Result(List(Card), pog.QueryError) {
  use returned <- result.try(sql.cards_list(db, project_id))

  let cards =
    returned.rows
    |> list.map(fn(row) {
      card_from_counts(
        row.id,
        row.project_id,
        row.title,
        row.description,
        row.color,
        row.created_by,
        row.created_at,
        row.task_count,
        row.completed_count,
        row.available_count,
      )
    })

  Ok(cards)
}

/// Get a single card by ID with derived state.
pub fn get_card(db: pog.Connection, card_id: Int) -> Result(Card, CardError) {
  case sql.cards_get(db, card_id) {
    Error(e) -> Error(DbError(e))
    Ok(pog.Returned(rows: [], ..)) -> Error(CardNotFound)
    Ok(pog.Returned(rows: [row, ..], ..)) ->
      Ok(card_from_counts(
        row.id,
        row.project_id,
        row.title,
        row.description,
        row.color,
        row.created_by,
        row.created_at,
        row.task_count,
        row.completed_count,
        row.available_count,
      ))
  }
}

fn card_from_counts(
  id: Int,
  project_id: Int,
  title: String,
  description: String,
  color: String,
  created_by: Int,
  created_at: String,
  task_count: Int,
  completed_count: Int,
  available_count: Int,
) -> Card {
  let state = derive_card_state(task_count, completed_count, available_count)

  Card(
    id: id,
    project_id: project_id,
    title: title,
    description: description,
    color: color,
    state: state,
    task_count: task_count,
    completed_count: completed_count,
    created_by: created_by,
    created_at: created_at,
  )
}

/// Create a new card.
pub fn create_card(
  db: pog.Connection,
  project_id: Int,
  title: String,
  description: Option(String),
  color: Option(String),
  created_by: Int,
) -> Result(Card, pog.QueryError) {
  let desc = option.unwrap(description, "")
  let col = option.unwrap(color, "")

  use returned <- result.try(sql.cards_create(
    db,
    project_id,
    title,
    desc,
    col,
    created_by,
  ))

  case returned.rows {
    [row, ..] -> {
      Ok(Card(
        id: row.id,
        project_id: row.project_id,
        title: row.title,
        description: row.description,
        color: row.color,
        state: Pendiente,
        task_count: 0,
        completed_count: 0,
        created_by: row.created_by,
        created_at: row.created_at,
      ))
    }
    _ -> {
      // Should not happen, but handle gracefully
      Error(pog.UnexpectedArgumentCount(5, 0))
    }
  }
}

/// Update a card's title, description, and color.
pub fn update_card(
  db: pog.Connection,
  card_id: Int,
  title: String,
  description: Option(String),
  color: Option(String),
) -> Result(Card, CardError) {
  let desc = option.unwrap(description, "")
  let col = option.unwrap(color, "")

  case sql.cards_update(db, card_id, title, desc, col) {
    Error(e) -> Error(DbError(e))
    Ok(pog.Returned(rows: [], ..)) -> Error(CardNotFound)
    Ok(pog.Returned(rows: [row, ..], ..)) -> {
      // After update, we need to get current task counts
      case sql.cards_get(db, card_id) {
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
            title: row.title,
            description: row.description,
            color: row.color,
            state: state,
            task_count: full_row.task_count,
            completed_count: full_row.completed_count,
            created_by: row.created_by,
            created_at: row.created_at,
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
// State Derivation
// =============================================================================

/// Derive card state from task counts.
///
/// Rules:
/// - If task_count = 0 → Pendiente
/// - If task_count > 0 AND task_count = completed_count → Cerrada
/// - If available_count < task_count (some progress) → EnCurso
/// - Else (all tasks available) → Pendiente
pub fn derive_card_state(
  task_count: Int,
  completed_count: Int,
  available_count: Int,
) -> CardState {
  case task_count {
    0 -> Pendiente
    _ -> {
      case task_count == completed_count {
        True -> Cerrada
        False -> {
          // If any task is NOT available (claimed or completed), there's progress
          case available_count < task_count {
            True -> EnCurso
            False -> Pendiente
          }
        }
      }
    }
  }
}

/// Convert CardState to string for API responses.
pub fn state_to_string(state: CardState) -> String {
  case state {
    Pendiente -> "pendiente"
    EnCurso -> "en_curso"
    Cerrada -> "cerrada"
  }
}
