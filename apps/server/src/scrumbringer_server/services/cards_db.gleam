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
  type Card, type CardColor, type CardState, Card, Pendiente, UnknownCardColor,
  derive_state as shared_derive_state,
  optional_color_to_string as shared_optional_color_to_string,
  parse_optional_color as shared_parse_optional_color,
}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import helpers/option as option_helpers
import pog
import scrumbringer_server/services/persisted_field
import scrumbringer_server/sql

// =============================================================================
// Types
// =============================================================================

const no_parent_create_value = 0

const no_parent_update_value = -1

/// Errors for card operations.
pub type CardError {
  CardNotFound
  CardHasTasks(task_count: Int)
  InvalidMilestone
  InvalidMilestoneState(String)
  InvalidColor(String)
  InvalidMovePoolToMilestone
  CardHasClaimedDescendant(Int)
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
) -> Result(List(Card), CardError) {
  use returned <- result.try(
    sql.cards_list(db, project_id, user_id)
    |> result.map_error(DbError),
  )

  list.try_map(returned.rows, fn(row) {
    card_from_counts(
      row.id,
      row.project_id,
      row.parent_card_id,
      row.title,
      row.description,
      row.color,
      row.created_by,
      row.created_at,
      row.due_date,
      row.task_count,
      row.completed_count,
      row.available_count,
      row.has_new_notes,
    )
  })
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
      card_from_counts(
        row.id,
        row.project_id,
        row.parent_card_id,
        row.title,
        row.description,
        row.color,
        row.created_by,
        row.created_at,
        row.due_date,
        row.task_count,
        row.completed_count,
        row.available_count,
        row.has_new_notes,
      )
  }
}

fn card_from_counts(
  id: Int,
  project_id: Int,
  parent_card_id: Int,
  title: String,
  description: String,
  color: String,
  created_by: Int,
  created_at: String,
  due_date: String,
  task_count: Int,
  completed_count: Int,
  available_count: Int,
  has_new_notes: Bool,
) -> Result(Card, CardError) {
  let state = shared_derive_state(task_count, completed_count, available_count)
  card_from_fields(
    id,
    project_id,
    parent_card_id,
    title,
    description,
    color,
    state,
    task_count,
    completed_count,
    created_by,
    created_at,
    due_date,
    has_new_notes,
  )
}

fn card_from_fields(
  id: Int,
  project_id: Int,
  parent_card_id: Int,
  title: String,
  description: String,
  color: String,
  state: CardState,
  task_count: Int,
  completed_count: Int,
  created_by: Int,
  created_at: String,
  due_date: String,
  has_new_notes: Bool,
) -> Result(Card, CardError) {
  use parsed_color <- result.try(parse_optional_color(color))
  Ok(Card(
    id: id,
    project_id: project_id,
    milestone_id: option_helpers.int_to_option(parent_card_id),
    title: title,
    description: description,
    color: parsed_color,
    state: state,
    task_count: task_count,
    completed_count: completed_count,
    created_by: created_by,
    created_at: created_at,
    due_date: option_helpers.string_to_option(due_date),
    has_new_notes: has_new_notes,
  ))
}

/// Create a new card.
pub fn create_card(
  db: pog.Connection,
  project_id: Int,
  parent_card_id: Option(Int),
  title: String,
  description: Option(String),
  color: Option(CardColor),
  created_by: Int,
) -> Result(Card, CardError) {
  case validate_parent_for_create(db, project_id, parent_card_id) {
    Error(e) -> Error(e)
    Ok(Nil) ->
      create_card_row(
        db,
        project_id,
        parent_card_id,
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
  parent_card_id: Option(Int),
  title: String,
  description: Option(String),
  color: Option(CardColor),
  created_by: Int,
) -> Result(Card, CardError) {
  let desc = description_text(description)
  let col = shared_optional_color_to_string(color)

  case
    sql.cards_create(
      db,
      project_id,
      title,
      desc,
      col,
      created_by,
      parent_card_id_create_value(parent_card_id),
    )
  {
    Error(e) -> Error(DbError(e))
    Ok(returned) -> {
      use row <- result.try(
        persisted_field.query_row(returned.rows)
        |> result.map_error(DbError),
      )
      card_from_fields(
        row.id,
        row.project_id,
        row.parent_card_id,
        row.title,
        row.description,
        row.color,
        Pendiente,
        0,
        0,
        row.created_by,
        row.created_at,
        row.due_date,
        False,
      )
    }
  }
}

/// Update a card's title, description, and color.
pub fn update_card(
  db: pog.Connection,
  card_id: Int,
  parent_card_id: Option(Int),
  title: String,
  description: Option(String),
  color: Option(CardColor),
  user_id: Int,
) -> Result(Card, CardError) {
  use current <- result.try(get_card(db, card_id, user_id))
  use _ <- result.try(validate_parent_for_update(
    db,
    current.project_id,
    current.milestone_id,
    parent_card_id,
  ))

  let desc = description_text(description)
  let col = shared_optional_color_to_string(color)

  case
    sql.cards_update(
      db,
      card_id,
      title,
      desc,
      col,
      parent_card_id_update_value(parent_card_id),
    )
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
            shared_derive_state(
              full_row.task_count,
              full_row.completed_count,
              full_row.available_count,
            )
          card_from_fields(
            row.id,
            row.project_id,
            row.parent_card_id,
            row.title,
            row.description,
            row.color,
            state,
            full_row.task_count,
            full_row.completed_count,
            row.created_by,
            row.created_at,
            row.due_date,
            full_row.has_new_notes,
          )
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

pub fn activate_card(
  db: pog.Connection,
  card_id: Int,
  user_id: Int,
) -> Result(Int, CardError) {
  pog.query(
    "UPDATE cards
     SET execution_state = 'active',
         activated_at = NOW(),
         activated_by = $2,
         activation_source = 'direct_activation'
     WHERE id = $1",
  )
  |> pog.parameter(pog.int(card_id))
  |> pog.parameter(pog.int(user_id))
  |> pog.execute(db)
  |> result.map(fn(_) { 0 })
  |> result.map_error(DbError)
}

pub fn close_card(
  db: pog.Connection,
  card_id: Int,
  user_id: Int,
) -> Result(Int, CardError) {
  use claimed_count <- result.try(count_claimed_tasks(db, card_id))
  case claimed_count > 0 {
    True -> Error(CardHasClaimedDescendant(claimed_count))
    False ->
      pog.query(
        "UPDATE cards
         SET execution_state = 'closed',
             closed_at = NOW(),
             closed_by = $2,
             closed_by_kind = 'user',
             closed_reason = 'manually_closed'
         WHERE id = $1",
      )
      |> pog.parameter(pog.int(card_id))
      |> pog.parameter(pog.int(user_id))
      |> pog.execute(db)
      |> result.map(fn(_) { 0 })
      |> result.map_error(DbError)
  }
}

pub fn move_card(
  db: pog.Connection,
  card_id: Int,
  parent_card_id: Option(Int),
) -> Result(Int, CardError) {
  pog.query(
    "UPDATE cards
     SET parent_card_id = $2
     WHERE id = $1",
  )
  |> pog.parameter(pog.int(card_id))
  |> pog.parameter(pog.nullable(pog.int, parent_card_id))
  |> pog.execute(db)
  |> result.map(fn(_) { 0 })
  |> result.map_error(DbError)
}

fn count_claimed_tasks(
  db: pog.Connection,
  card_id: Int,
) -> Result(Int, CardError) {
  pog.query(
    "SELECT COUNT(*)::int
     FROM tasks
     WHERE card_id = $1
       AND execution_state = 'claimed'",
  )
  |> pog.parameter(pog.int(card_id))
  |> pog.returning(int_decoder())
  |> pog.execute(db)
  |> result.map_error(DbError)
  |> result.try(fn(returned) {
    case returned.rows {
      [count] -> Ok(count)
      _ -> Ok(0)
    }
  })
}

fn int_decoder() {
  use value <- decode.field(0, decode.int)
  decode.success(value)
}

// =============================================================================
// State Derivation (delegated to shared module)
// =============================================================================

fn parse_optional_color(color: String) -> Result(Option(CardColor), CardError) {
  case shared_parse_optional_color(color) {
    Ok(parsed) -> Ok(parsed)
    Error(UnknownCardColor(value)) -> Error(InvalidColor(value))
  }
}

fn description_text(description: Option(String)) -> String {
  option_helpers.option_to_value(description, "")
}

fn parent_card_id_create_value(parent_card_id: Option(Int)) -> Int {
  option_helpers.option_to_value(parent_card_id, no_parent_create_value)
}

fn parent_card_id_update_value(parent_card_id: Option(Int)) -> Int {
  option_helpers.option_to_value(parent_card_id, no_parent_update_value)
}

fn validate_parent_for_create(
  db: pog.Connection,
  project_id: Int,
  parent_card_id: Option(Int),
) -> Result(Nil, CardError) {
  let _ = db
  let _ = project_id
  case parent_card_id {
    None -> Ok(Nil)
    Some(id) if id <= 0 -> Ok(Nil)
    Some(_) -> Ok(Nil)
  }
}

fn validate_parent_for_update(
  db: pog.Connection,
  project_id: Int,
  current_parent_card_id: Option(Int),
  target_parent_card_id: Option(Int),
) -> Result(Nil, CardError) {
  let _ = db
  let _ = project_id
  let _ = current_parent_card_id
  let _ = target_parent_card_id
  Ok(Nil)
}
