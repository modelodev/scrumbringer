//// Database operations for work sessions (time tracking).
////
//// ## Mission
////
//// Manages work sessions for users tracking time on tasks.
//// Supports multiple concurrent sessions per user (multi-ongoing).
////
//// ## Responsibilities
////
//// - Track active work sessions per user
//// - Start, pause, and heartbeat work sessions
//// - Accumulate time spent on tasks
//// - Close stale sessions automatically

import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option, Some}
import gleam/result
import pog

// =============================================================================
// Types
// =============================================================================

/// An active work session.
pub type ActiveSession {
  ActiveSession(
    task_id: Int,
    started_at: String,
    accumulated_s: Int,
  )
}

/// Response containing active sessions and server time.
pub type WorkSessionsState {
  WorkSessionsState(
    active_sessions: List(ActiveSession),
    as_of: String,
  )
}

/// Errors for work session operations.
pub type WorkSessionError {
  /// Task is not claimed by this user.
  NotClaimed
  /// Task is completed (cannot start session).
  TaskCompleted
  /// Session already exists for this task.
  SessionExists
  /// No active session found for heartbeat.
  SessionNotFound
  /// Database error.
  DbError(pog.QueryError)
}

// =============================================================================
// Configuration
// =============================================================================

/// Stale cutoff in seconds (3 minutes).
pub const stale_cutoff_seconds = 180

// =============================================================================
// Public API
// =============================================================================

/// Get all active work sessions for a user.
pub fn get_active_sessions(
  db: pog.Connection,
  user_id: Int,
) -> Result(WorkSessionsState, pog.QueryError) {
  use sessions <- result.try(query_active_sessions(db, user_id))
  use as_of <- result.try(get_server_time(db))
  Ok(WorkSessionsState(active_sessions: sessions, as_of: as_of))
}

/// Start a work session on a task.
/// - Validates task is claimed by user
/// - Validates task is not completed
/// - Creates new session or returns existing (idempotent)
pub fn start_session(
  db: pog.Connection,
  user_id: Int,
  task_id: Int,
) -> Result(WorkSessionsState, WorkSessionError) {
  // First validate the task is claimed by this user and not completed
  use task_status <- result.try(
    validate_task_for_session(db, user_id, task_id)
  )

  case task_status {
    TaskNotClaimed -> Error(NotClaimed)
    TaskIsCompleted -> Error(TaskCompleted)
    TaskValidForSession -> {
      // Try to insert new session, handle conflict (already exists)
      case insert_session(db, user_id, task_id) {
        Ok(_) -> {
          // Session created, return updated state
          get_active_sessions(db, user_id)
          |> result.map_error(DbError)
        }
        Error(SessionAlreadyExists) -> {
          // Idempotent: return current state
          get_active_sessions(db, user_id)
          |> result.map_error(DbError)
        }
        Error(InsertDbError(e)) -> Error(DbError(e))
      }
    }
  }
}

/// Pause (end) a work session on a task.
/// - Closes active session and flushes accumulated time
/// - Idempotent: returns OK even if no session exists
pub fn pause_session(
  db: pog.Connection,
  user_id: Int,
  task_id: Int,
) -> Result(WorkSessionsState, WorkSessionError) {
  use _ <- result.try(
    close_session(db, user_id, task_id, "user_pause")
    |> result.map_error(DbError)
  )

  get_active_sessions(db, user_id)
  |> result.map_error(DbError)
}

/// Send heartbeat for an active session.
/// - Updates last_heartbeat_at
/// - Optionally flushes accumulated time incrementally
pub fn heartbeat_session(
  db: pog.Connection,
  user_id: Int,
  task_id: Int,
) -> Result(WorkSessionsState, WorkSessionError) {
  use updated <- result.try(
    update_heartbeat(db, user_id, task_id)
    |> result.map_error(DbError)
  )

  case updated {
    0 -> Error(SessionNotFound)
    _ -> {
      get_active_sessions(db, user_id)
      |> result.map_error(DbError)
    }
  }
}

/// Close session for a task (called by complete/release).
/// Returns the ended reason.
pub fn close_session_for_task(
  db: pog.Connection,
  user_id: Int,
  task_id: Int,
  reason: String,
) -> Result(Nil, pog.QueryError) {
  close_session(db, user_id, task_id, reason)
}

/// Close all stale sessions (background job or lazy cleanup).
pub fn close_stale_sessions(
  db: pog.Connection,
) -> Result(Int, pog.QueryError) {
  let query = "
    WITH closed AS (
      UPDATE user_task_work_session
      SET ended_at = NOW(),
          ended_reason = 'stale_timeout'
      WHERE ended_at IS NULL
        AND last_heartbeat_at < NOW() - INTERVAL '" <> int.to_string(stale_cutoff_seconds) <> " seconds'
      RETURNING user_id, task_id, started_at, last_heartbeat_at
    ),
    flush AS (
      INSERT INTO user_task_work_total (user_id, task_id, accumulated_s, updated_at)
      SELECT user_id, task_id,
             GREATEST(0, FLOOR(EXTRACT(EPOCH FROM (last_heartbeat_at - started_at))))::INT,
             NOW()
      FROM closed
      ON CONFLICT (user_id, task_id) DO UPDATE
      SET accumulated_s = user_task_work_total.accumulated_s + EXCLUDED.accumulated_s,
          updated_at = NOW()
    )
    SELECT COUNT(*)::INT FROM closed
  "

  let decoder = {
    use count <- decode.field(0, decode.int)
    decode.success(count)
  }

  pog.query(query)
  |> pog.returning(decoder)
  |> pog.execute(db)
  |> result.map(fn(returned) {
    case returned.rows {
      [count, ..] -> count
      _ -> 0
    }
  })
}

/// Get time tracking data for a task (total and by user).
pub fn get_task_time_tracking(
  db: pog.Connection,
  task_id: Int,
) -> Result(TaskTimeTracking, pog.QueryError) {
  let query = "
    SELECT
      uwt.user_id,
      u.email,
      uwt.accumulated_s,
      ws.started_at,
      EXTRACT(EPOCH FROM (NOW() - ws.started_at))::INT as session_elapsed
    FROM user_task_work_total uwt
    JOIN users u ON u.id = uwt.user_id
    LEFT JOIN user_task_work_session ws
      ON ws.user_id = uwt.user_id
      AND ws.task_id = uwt.task_id
      AND ws.ended_at IS NULL
    WHERE uwt.task_id = $1
    ORDER BY uwt.accumulated_s DESC
  "

  let decoder = {
    use user_id <- decode.field(0, decode.int)
    use email <- decode.field(1, decode.string)
    use accumulated_s <- decode.field(2, decode.int)
    use started_at <- decode.field(3, decode.optional(decode.string))
    use session_elapsed <- decode.field(4, decode.optional(decode.int))
    decode.success(ContributorTime(
      user_id: user_id,
      email: email,
      accumulated_s: accumulated_s,
      ongoing_started_at: started_at,
      ongoing_elapsed_s: session_elapsed,
    ))
  }

  use returned <- result.try(
    pog.query(query)
    |> pog.parameter(pog.int(task_id))
    |> pog.returning(decoder)
    |> pog.execute(db)
  )

  let contributors = returned.rows

  let total_accumulated = list.fold(contributors, 0, fn(acc, c) {
    acc + c.accumulated_s
  })

  let ongoing_session = list.find(contributors, fn(c) {
    option.is_some(c.ongoing_started_at)
  })
  |> option.from_result

  Ok(TaskTimeTracking(
    total_s: total_accumulated,
    contributors: contributors,
    ongoing_session: ongoing_session,
  ))
}

// =============================================================================
// Supporting Types
// =============================================================================

pub type TaskTimeTracking {
  TaskTimeTracking(
    total_s: Int,
    contributors: List(ContributorTime),
    ongoing_session: Option(ContributorTime),
  )
}

pub type ContributorTime {
  ContributorTime(
    user_id: Int,
    email: String,
    accumulated_s: Int,
    ongoing_started_at: Option(String),
    ongoing_elapsed_s: Option(Int),
  )
}

// =============================================================================
// Internal Helpers
// =============================================================================

type TaskValidation {
  TaskValidForSession
  TaskNotClaimed
  TaskIsCompleted
}

fn validate_task_for_session(
  db: pog.Connection,
  user_id: Int,
  task_id: Int,
) -> Result(TaskValidation, WorkSessionError) {
  let query = "
    SELECT status, claimed_by
    FROM tasks
    WHERE id = $1
  "

  let decoder = {
    use status <- decode.field(0, decode.string)
    use claimed_by <- decode.field(1, decode.optional(decode.int))
    decode.success(#(status, claimed_by))
  }

  case pog.query(query)
    |> pog.parameter(pog.int(task_id))
    |> pog.returning(decoder)
    |> pog.execute(db)
  {
    Error(e) -> Error(DbError(e))
    Ok(pog.Returned(rows: [], ..)) -> Error(NotClaimed)
    Ok(pog.Returned(rows: [#(status, claimed_by), ..], ..)) -> {
      case status {
        "completed" -> Ok(TaskIsCompleted)
        "claimed" -> {
          case claimed_by {
            Some(id) if id == user_id -> Ok(TaskValidForSession)
            _ -> Ok(TaskNotClaimed)
          }
        }
        _ -> Ok(TaskNotClaimed)
      }
    }
  }
}

type InsertError {
  SessionAlreadyExists
  InsertDbError(pog.QueryError)
}

fn insert_session(
  db: pog.Connection,
  user_id: Int,
  task_id: Int,
) -> Result(Nil, InsertError) {
  let query = "
    INSERT INTO user_task_work_session (user_id, task_id)
    VALUES ($1, $2)
    ON CONFLICT DO NOTHING
    RETURNING id
  "

  let decoder = {
    use id <- decode.field(0, decode.int)
    decode.success(id)
  }

  case pog.query(query)
    |> pog.parameter(pog.int(user_id))
    |> pog.parameter(pog.int(task_id))
    |> pog.returning(decoder)
    |> pog.execute(db)
  {
    Error(e) -> Error(InsertDbError(e))
    Ok(pog.Returned(rows: [], ..)) -> Error(SessionAlreadyExists)
    Ok(_) -> Ok(Nil)
  }
}

fn close_session(
  db: pog.Connection,
  user_id: Int,
  task_id: Int,
  reason: String,
) -> Result(Nil, pog.QueryError) {
  // Close session and flush accumulated time in a single transaction
  let query = "
    WITH closed AS (
      UPDATE user_task_work_session
      SET ended_at = NOW(),
          ended_reason = $3
      WHERE user_id = $1
        AND task_id = $2
        AND ended_at IS NULL
      RETURNING started_at
    )
    INSERT INTO user_task_work_total (user_id, task_id, accumulated_s, updated_at)
    SELECT $1, $2,
           GREATEST(0, FLOOR(EXTRACT(EPOCH FROM (NOW() - started_at))))::INT,
           NOW()
    FROM closed
    ON CONFLICT (user_id, task_id) DO UPDATE
    SET accumulated_s = user_task_work_total.accumulated_s + EXCLUDED.accumulated_s,
        updated_at = NOW()
  "

  pog.query(query)
  |> pog.parameter(pog.int(user_id))
  |> pog.parameter(pog.int(task_id))
  |> pog.parameter(pog.text(reason))
  |> pog.execute(db)
  |> result.map(fn(_) { Nil })
}

fn update_heartbeat(
  db: pog.Connection,
  user_id: Int,
  task_id: Int,
) -> Result(Int, pog.QueryError) {
  let query = "
    UPDATE user_task_work_session
    SET last_heartbeat_at = NOW()
    WHERE user_id = $1
      AND task_id = $2
      AND ended_at IS NULL
  "

  pog.query(query)
  |> pog.parameter(pog.int(user_id))
  |> pog.parameter(pog.int(task_id))
  |> pog.execute(db)
  |> result.map(fn(returned) { returned.count })
}

fn query_active_sessions(
  db: pog.Connection,
  user_id: Int,
) -> Result(List(ActiveSession), pog.QueryError) {
  let query = "
    SELECT
      ws.task_id,
      TO_CHAR(ws.started_at AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as started_at,
      COALESCE(uwt.accumulated_s, 0) as accumulated_s
    FROM user_task_work_session ws
    LEFT JOIN user_task_work_total uwt
      ON uwt.user_id = ws.user_id AND uwt.task_id = ws.task_id
    WHERE ws.user_id = $1
      AND ws.ended_at IS NULL
    ORDER BY ws.started_at ASC
  "

  let decoder = {
    use task_id <- decode.field(0, decode.int)
    use started_at <- decode.field(1, decode.string)
    use accumulated_s <- decode.field(2, decode.int)
    decode.success(ActiveSession(
      task_id: task_id,
      started_at: started_at,
      accumulated_s: accumulated_s,
    ))
  }

  pog.query(query)
  |> pog.parameter(pog.int(user_id))
  |> pog.returning(decoder)
  |> pog.execute(db)
  |> result.map(fn(returned) { returned.rows })
}

fn get_server_time(db: pog.Connection) -> Result(String, pog.QueryError) {
  let decoder = {
    use value <- decode.field(0, decode.string)
    decode.success(value)
  }

  pog.query("SELECT TO_CHAR(NOW() AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"')")
  |> pog.returning(decoder)
  |> pog.execute(db)
  |> result.map(fn(returned) {
    case returned.rows {
      [value, ..] -> value
      _ -> ""
    }
  })
}
