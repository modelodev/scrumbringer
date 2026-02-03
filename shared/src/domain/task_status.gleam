//// Task status domain types for ScrumBringer.
////
//// Provides type-safe task status representation using ADTs instead of strings.
//// Ensures compile-time verification of status transitions and eliminates
//// string comparison bugs.
////
//// ## Usage
////
//// ```gleam
//// import shared/domain/task_status.{
////   type TaskStatus, Available, Claimed, Completed, Ongoing, Taken,
//// }
////
//// case status {
////   Available -> "Task is available"
////   Claimed(Taken) -> "Task is claimed but not being worked on"
////   Claimed(Ongoing) -> "Task is actively being worked on"
////   Completed -> "Task is done"
//// }
//// ```

// =============================================================================
// Types
// =============================================================================

/// Task status ADT representing all possible task states.
///
/// - `Available`: Task is open and can be claimed
/// - `Claimed(ClaimedState)`: Task is assigned to someone
/// - `Completed`: Task is finished
///
/// ## Example
///
/// ```gleam
/// case task.status {
///   Available -> allow_claim(task)
///   Claimed(Ongoing) -> show_timer(task)
///   Claimed(Taken) -> show_claimed_badge(task)
///   Completed -> show_completed_badge(task)
/// }
/// ```
pub type TaskStatus {
  Available
  Claimed(ClaimedState)
  Completed
}

/// Sub-state for claimed tasks.
///
/// - `Taken`: Task is claimed but user is not actively working on it
/// - `Ongoing`: Task is claimed and user is actively working on it (timer running)
///
/// ## Example
///
/// ```gleam
/// case status {
///   Claimed(Ongoing) -> "Working on it now"
///   Claimed(Taken) -> "Will work on it later"
///   _ -> "Not claimed"
/// }
/// ```
pub type ClaimedState {
  Taken
  Ongoing
}

/// Work state for UI display (flattened status representation).
///
/// ## Example
///
/// ```gleam
/// case work_state {
///   WorkAvailable -> show_claim_button()
///   WorkClaimed -> show_release_button()
///   WorkOngoing -> show_timer()
///   WorkCompleted -> show_done_badge()
/// }
/// ```
pub type WorkState {
  WorkAvailable
  WorkClaimed
  WorkOngoing
  WorkCompleted
}

/// User currently working on a task.
///
/// ## Example
///
/// ```gleam
/// case task.ongoing_by {
///   Some(OngoingBy(user_id)) -> show_user_avatar(user_id)
///   None -> Nil
/// }
/// ```
pub type OngoingBy {
  OngoingBy(user_id: Int)
}

// =============================================================================
// Status Parsing
// =============================================================================

/// Parse a task status string into TaskStatus.
///
/// ## Example
///
/// ```gleam
/// parse_task_status("available")  // -> Ok(Available)
/// parse_task_status("claimed")    // -> Ok(Claimed(Taken))
/// parse_task_status("ongoing")    // -> Ok(Claimed(Ongoing))
/// parse_task_status("completed")  // -> Ok(Completed)
/// parse_task_status("invalid")    // -> Error("Unknown task status: invalid")
/// ```
pub fn parse_task_status(value: String) -> Result(TaskStatus, String) {
  case value {
    "available" -> Ok(Available)
    "claimed" -> Ok(Claimed(Taken))
    "ongoing" -> Ok(Claimed(Ongoing))
    "completed" -> Ok(Completed)
    _ -> Error("Unknown task status: " <> value)
  }
}

/// Convert TaskStatus to string for API.
///
/// ## Example
///
/// ```gleam
/// task_status_to_string(Available)        // -> "available"
/// task_status_to_string(Claimed(Taken))   // -> "claimed"
/// task_status_to_string(Claimed(Ongoing)) // -> "ongoing"
/// task_status_to_string(Completed)        // -> "completed"
/// ```
pub fn task_status_to_string(status: TaskStatus) -> String {
  case status {
    Available -> "available"
    Claimed(Taken) -> "claimed"
    Claimed(Ongoing) -> "ongoing"
    Completed -> "completed"
  }
}

/// Parse work state string into WorkState.
///
/// ## Example
///
/// ```gleam
/// parse_work_state("available")  // -> WorkAvailable
/// parse_work_state("claimed")    // -> WorkClaimed
/// parse_work_state("ongoing")    // -> WorkOngoing
/// parse_work_state("completed")  // -> WorkCompleted
/// ```
pub fn parse_work_state(value: String) -> WorkState {
  case value {
    "available" -> WorkAvailable
    "claimed" -> WorkClaimed
    "ongoing" -> WorkOngoing
    "completed" -> WorkCompleted
    _ -> WorkClaimed
  }
}

/// Convert TaskStatus into a WorkState for UI display.
///
/// ## Example
///
/// ```gleam
/// to_work_state(Claimed(Ongoing)) // -> WorkOngoing
/// ```
pub fn to_work_state(status: TaskStatus) -> WorkState {
  case status {
    Available -> WorkAvailable
    Claimed(Taken) -> WorkClaimed
    Claimed(Ongoing) -> WorkOngoing
    Completed -> WorkCompleted
  }
}

/// Convert WorkState into a TaskStatus.
///
/// ## Example
///
/// ```gleam
/// from_work_state(WorkClaimed) // -> Claimed(Taken)
/// ```
pub fn from_work_state(state: WorkState) -> TaskStatus {
  case state {
    WorkAvailable -> Available
    WorkClaimed -> Claimed(Taken)
    WorkOngoing -> Claimed(Ongoing)
    WorkCompleted -> Completed
  }
}

// =============================================================================
// Database Conversion (Server-only helpers)
// =============================================================================

/// Parse task status from database columns.
///
/// Maps the database representation (status string + is_ongoing bool) to
/// the type-safe ADT.
///
/// ## Example
///
/// ```gleam
/// from_db("available", False)  // -> Available
/// from_db("claimed", False)    // -> Claimed(Taken)
/// from_db("claimed", True)     // -> Claimed(Ongoing)
/// from_db("completed", False)  // -> Completed
/// ```
pub fn from_db(status: String, is_ongoing: Bool) -> TaskStatus {
  case status, is_ongoing {
    "available", _ -> Available
    "claimed", True -> Claimed(Ongoing)
    "claimed", False -> Claimed(Taken)
    "completed", _ -> Completed
    // Fallback for any unexpected values (defensive)
    _, _ -> Available
  }
}

/// Convert task status to database status string.
///
/// ## Example
///
/// ```gleam
/// to_db_status(Available)        // -> "available"
/// to_db_status(Claimed(Taken))   // -> "claimed"
/// to_db_status(Claimed(Ongoing)) // -> "claimed"
/// to_db_status(Completed)        // -> "completed"
/// ```
pub fn to_db_status(status: TaskStatus) -> String {
  case status {
    Available -> "available"
    Claimed(_) -> "claimed"
    Completed -> "completed"
  }
}

/// Convert task status to database is_ongoing boolean.
///
/// ## Example
///
/// ```gleam
/// to_db_ongoing(Claimed(Ongoing)) // -> True
/// to_db_ongoing(Claimed(Taken))   // -> False
/// to_db_ongoing(Available)        // -> False
/// ```
pub fn to_db_ongoing(status: TaskStatus) -> Bool {
  case status {
    Claimed(Ongoing) -> True
    _ -> False
  }
}

// =============================================================================
// Query Helpers
// =============================================================================

/// Check if status represents a claimed task (either Taken or Ongoing).
///
/// ## Example
///
/// ```gleam
/// is_claimed(Claimed(Taken))   // -> True
/// is_claimed(Claimed(Ongoing)) // -> True
/// is_claimed(Available)        // -> False
/// ```
pub fn is_claimed(status: TaskStatus) -> Bool {
  case status {
    Claimed(_) -> True
    _ -> False
  }
}

/// Check if status represents an actively worked task.
///
/// ## Example
///
/// ```gleam
/// is_ongoing(Claimed(Ongoing)) // -> True
/// is_ongoing(Claimed(Taken))   // -> False
/// ```
pub fn is_ongoing(status: TaskStatus) -> Bool {
  case status {
    Claimed(Ongoing) -> True
    _ -> False
  }
}

/// Parse status filter from query parameter string.
///
/// ## Example
///
/// ```gleam
/// parse_filter("available")  // -> Ok(Available)
/// parse_filter("claimed")    // -> Ok(Claimed(Taken))
/// parse_filter("completed")  // -> Ok(Completed)
/// parse_filter("invalid")    // -> Error(Nil)
/// ```
pub fn parse_filter(value: String) -> Result(TaskStatus, Nil) {
  case value {
    "available" -> Ok(Available)
    "claimed" -> Ok(Claimed(Taken))
    "completed" -> Ok(Completed)
    _ -> Error(Nil)
  }
}

/// Convert status to filter query string for database.
///
/// ## Example
///
/// ```gleam
/// to_filter_string(Available) // -> "available"
/// to_filter_string(Claimed(_)) // -> "claimed"
/// ```
pub fn to_filter_string(status: TaskStatus) -> String {
  to_db_status(status)
}
