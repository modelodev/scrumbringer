//// Now working (active task) actor for business logic orchestration.
////
//// ## Mission
////
//// Centralizes "now working" feature business logic including active task
//// tracking, timer management, and heartbeat operations. Separates business
//// concerns from HTTP handling and pure CRUD.
////
//// ## Responsibilities
////
//// - Active task state management
//// - Task claim validation for start
//// - Response payload construction
//// - Domain error mapping
////
//// ## Non-responsibilities
////
//// - HTTP request parsing (see `http/me_active_task.gleam`)
//// - JSON serialization (handled by HTTP layer)
//// - Pure SQL queries (see `services/now_working_db.gleam`)

import gleam/option.{type Option}
import gleam/result
import pog
import scrumbringer_server/services/now_working_db

// =============================================================================
// Message Types
// =============================================================================

/// Now working messages for business logic operations.
pub type Message {
  /// Get the current active task for a user.
  GetActiveTask(user_id: Int)

  /// Start working on a task (must be claimed by user).
  StartActiveTask(user_id: Int, task_id: Int)

  /// Pause the current active task.
  PauseActiveTask(user_id: Int)

  /// Send a heartbeat to update the timer.
  Heartbeat(user_id: Int)
}

// =============================================================================
// Response Types
// =============================================================================

/// Active task state response.
pub type ActiveTaskState {
  ActiveTaskState(active_task: Option(now_working_db.ActiveTask), as_of: String)
}

// =============================================================================
// Error Types
// =============================================================================

/// Domain errors for now working operations.
pub type Error {
  /// Task is not claimed by this user.
  TaskNotClaimed

  /// Database error.
  DbError(pog.QueryError)
}

// =============================================================================
// Handler
// =============================================================================

/// Handle a now working message and return a domain result.
pub fn handle(
  db: pog.Connection,
  message: Message,
) -> Result(ActiveTaskState, Error) {
  case message {
    GetActiveTask(user_id) -> handle_get_active_task(db, user_id)
    StartActiveTask(user_id, task_id) ->
      handle_start_active_task(db, user_id, task_id)
    PauseActiveTask(user_id) -> handle_pause_active_task(db, user_id)
    Heartbeat(user_id) -> handle_heartbeat(db, user_id)
  }
}

// =============================================================================
// Message Handlers
// =============================================================================

fn handle_get_active_task(
  db: pog.Connection,
  user_id: Int,
) -> Result(ActiveTaskState, Error) {
  build_state(db, user_id)
}

fn handle_start_active_task(
  db: pog.Connection,
  user_id: Int,
  task_id: Int,
) -> Result(ActiveTaskState, Error) {
  case now_working_db.start(db, user_id, task_id) {
    Ok(_) -> build_state(db, user_id)
    Error(now_working_db.NotClaimed) -> Error(TaskNotClaimed)
    Error(now_working_db.DbError(e)) -> Error(DbError(e))
  }
}

fn handle_pause_active_task(
  db: pog.Connection,
  user_id: Int,
) -> Result(ActiveTaskState, Error) {
  case now_working_db.pause(db, user_id) {
    Ok(_) -> build_state(db, user_id)
    Error(e) -> Error(DbError(e))
  }
}

fn handle_heartbeat(
  db: pog.Connection,
  user_id: Int,
) -> Result(ActiveTaskState, Error) {
  case now_working_db.heartbeat(db, user_id) {
    Ok(_) -> build_state(db, user_id)
    Error(e) -> Error(DbError(e))
  }
}

// =============================================================================
// Helpers
// =============================================================================

fn build_state(
  db: pog.Connection,
  user_id: Int,
) -> Result(ActiveTaskState, Error) {
  use active_task <- result.try(
    now_working_db.get_active_task(db, user_id)
    |> result.map_error(DbError),
  )

  use as_of <- result.try(
    now_working_db.as_of(db)
    |> result.map_error(DbError),
  )

  Ok(ActiveTaskState(active_task: active_task, as_of: as_of))
}
