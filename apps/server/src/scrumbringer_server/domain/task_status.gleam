//// Task status domain types for Scrumbringer server.
////
//// ## Mission
////
//// Provides type-safe task status representation using ADTs instead of strings.
//// Ensures compile-time verification of status transitions and eliminates
//// string comparison bugs.
////
//// ## Usage
////
//// ```gleam
//// import scrumbringer_server/domain/task_status.{
////   type TaskStatus, Available, Claimed, Completed, Ongoing, Taken,
//// }
////
//// // Parse from database
//// let status = task_status.from_db("claimed", True)
//// // => Claimed(Ongoing)
////
//// // Pattern match for business logic
//// case status {
////   Available -> "Task is available"
////   Claimed(Taken) -> "Task is claimed but not being worked on"
////   Claimed(Ongoing) -> "Task is actively being worked on"
////   Completed -> "Task is done"
//// }
////
//// // Convert back for database storage
//// let db_status = task_status.to_db_status(status)  // "claimed"
//// let db_ongoing = task_status.to_db_ongoing(status)  // True
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

// =============================================================================
// Database Conversion
// =============================================================================

/// Parse task status from database columns.
///
/// Maps the database representation (status string + is_ongoing bool) to
/// the type-safe ADT.
///
/// ## Example
///
/// ```gleam
/// from_db("available", False)  // => Available
/// from_db("claimed", False)    // => Claimed(Taken)
/// from_db("claimed", True)     // => Claimed(Ongoing)
/// from_db("completed", False)  // => Completed
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
/// to_db_status(Available)       // => "available"
/// to_db_status(Claimed(Taken))  // => "claimed"
/// to_db_status(Claimed(Ongoing)) // => "claimed"
/// to_db_status(Completed)       // => "completed"
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
/// to_db_ongoing(Claimed(Ongoing)) // => True
/// to_db_ongoing(Claimed(Taken))   // => False
/// to_db_ongoing(Available)        // => False
/// to_db_ongoing(Completed)        // => False
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
/// is_claimed(Claimed(Taken))   // => True
/// is_claimed(Claimed(Ongoing)) // => True
/// is_claimed(Available)        // => False
/// is_claimed(Completed)        // => False
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
/// is_ongoing(Claimed(Ongoing)) // => True
/// is_ongoing(Claimed(Taken))   // => False
/// is_ongoing(Available)        // => False
/// ```
pub fn is_ongoing(status: TaskStatus) -> Bool {
  case status {
    Claimed(Ongoing) -> True
    _ -> False
  }
}

// =============================================================================
// Filter Parsing
// =============================================================================

/// Parse status filter from query parameter string.
///
/// Returns None for empty string (no filter), Some for valid values,
/// Error for invalid values.
///
/// Note: Filter uses "available", "claimed", "completed" without Ongoing distinction
/// since filters query database status column directly.
///
/// ## Example
///
/// ```gleam
/// parse_filter("")           // => Ok(None)
/// parse_filter("available")  // => Ok(Some(Available))
/// parse_filter("claimed")    // => Ok(Some(Claimed(Taken)))
/// parse_filter("completed")  // => Ok(Some(Completed))
/// parse_filter("invalid")    // => Error(Nil)
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
/// to_filter_string(Available)       // => "available"
/// to_filter_string(Claimed(Taken))  // => "claimed"
/// to_filter_string(Claimed(Ongoing)) // => "claimed"
/// to_filter_string(Completed)       // => "completed"
/// ```
pub fn to_filter_string(status: TaskStatus) -> String {
  to_db_status(status)
}
