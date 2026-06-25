//// Task status presentation/filter projections for ScrumBringer.
////
//// `domain/task/state.gleam` owns the canonical task execution lifecycle.
//// This module provides flattened status and work-state ADTs for UI labels,
//// filters, and external presentation strings.
////
//// ## Usage
////
//// ```gleam
//// import shared/domain/task_status.{
////   type TaskPhase, Available, Claimed, Done, Ongoing, Taken,
//// }
////
//// case status {
////   Available -> "Task is available"
////   Claimed(Taken) -> "Task is claimed but not being worked on"
////   Claimed(Ongoing) -> "Task is actively being worked on"
////   Done -> "Task is closed"
//// }
//// ```

// =============================================================================
// Types
// =============================================================================

/// Presentation/filter projection of task execution state.
///
/// This is not the canonical task execution lifecycle. Use
/// `domain/task/state.gleam` for lifecycle decisions.
///
/// - `Available`: Task is open and can be claimed
/// - `Claimed(ClaimedState)`: Task is assigned to someone
/// - `Done`: Task is closed, exposed as the historical `completed` filter value
///
/// ## Example
///
/// ```gleam
/// case task.status {
///   Available -> allow_claim(task)
///   Claimed(Ongoing) -> show_timer(task)
///   Claimed(Taken) -> show_claimed_badge(task)
///   Done -> show_closed_badge(task)
/// }
/// ```
pub type TaskPhase {
  Available
  Claimed(ClaimedState)
  Done
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
///   WorkDone -> show_closed_badge()
/// }
/// ```
pub type WorkState {
  WorkAvailable
  WorkClaimed
  WorkOngoing
  WorkDone
}

/// Error returned when an external task status/work state cannot be parsed.
pub type TaskPhaseParseError {
  UnknownTaskPhase(String)
  UnknownWorkState(String)
}

// =============================================================================
// Status Parsing
// =============================================================================

/// Parse an external task status/filter string into TaskPhase.
///
/// The `"completed"` value is retained for API/filter compatibility and maps
/// to the closed presentation phase.
///
/// ## Example
///
/// ```gleam
/// parse_task_status("available")  // -> Ok(Available)
/// parse_task_status("claimed")    // -> Ok(Claimed(Taken))
/// parse_task_status("ongoing")    // -> Ok(Claimed(Ongoing))
/// parse_task_status("completed")  // -> Ok(Done)
/// parse_task_status("invalid")    // -> Error(UnknownTaskPhase("invalid"))
/// ```
pub fn parse_task_status(
  value: String,
) -> Result(TaskPhase, TaskPhaseParseError) {
  case value {
    "available" -> Ok(Available)
    "claimed" -> Ok(Claimed(Taken))
    "ongoing" -> Ok(Claimed(Ongoing))
    "completed" -> Ok(Done)
    other -> Error(UnknownTaskPhase(other))
  }
}

/// Convert TaskPhase to the external API/filter string.
///
/// ## Example
///
/// ```gleam
/// task_status_to_string(Available)        // -> "available"
/// task_status_to_string(Claimed(Taken))   // -> "claimed"
/// task_status_to_string(Claimed(Ongoing)) // -> "ongoing"
/// task_status_to_string(Done)             // -> "completed"
/// ```
pub fn task_status_to_string(status: TaskPhase) -> String {
  case status {
    Available -> "available"
    Claimed(Taken) -> "claimed"
    Claimed(Ongoing) -> "ongoing"
    Done -> "completed"
  }
}

/// Parse an external work-state string into WorkState.
///
/// The `"completed"` value is retained for API/filter compatibility and maps
/// to the closed presentation work state.
///
/// ## Example
///
/// ```gleam
/// parse_work_state("available")  // -> Ok(WorkAvailable)
/// parse_work_state("claimed")    // -> Ok(WorkClaimed)
/// parse_work_state("ongoing")    // -> Ok(WorkOngoing)
/// parse_work_state("completed")  // -> Ok(WorkDone)
/// parse_work_state("invalid")    // -> Error(UnknownWorkState("invalid"))
/// ```
pub fn parse_work_state(value: String) -> Result(WorkState, TaskPhaseParseError) {
  case value {
    "available" -> Ok(WorkAvailable)
    "claimed" -> Ok(WorkClaimed)
    "ongoing" -> Ok(WorkOngoing)
    "completed" -> Ok(WorkDone)
    other -> Error(UnknownWorkState(other))
  }
}

/// Convert parse errors into stable labels for diagnostics.
pub fn parse_error_to_string(error: TaskPhaseParseError) -> String {
  case error {
    UnknownTaskPhase(value) -> "Unknown task status: " <> value
    UnknownWorkState(value) -> "Unknown work state: " <> value
  }
}

/// Convert WorkState to the external API/UI serialization string.
///
/// ## Example
///
/// ```gleam
/// work_state_to_string(WorkAvailable) // -> "available"
/// ```
pub fn work_state_to_string(state: WorkState) -> String {
  case state {
    WorkAvailable -> "available"
    WorkClaimed -> "claimed"
    WorkOngoing -> "ongoing"
    WorkDone -> "completed"
  }
}

/// Convert TaskPhase into a WorkState for UI display.
///
/// ## Example
///
/// ```gleam
/// to_work_state(Claimed(Ongoing)) // -> WorkOngoing
/// ```
pub fn to_work_state(status: TaskPhase) -> WorkState {
  case status {
    Available -> WorkAvailable
    Claimed(Taken) -> WorkClaimed
    Claimed(Ongoing) -> WorkOngoing
    Done -> WorkDone
  }
}

/// Convert WorkState into a TaskPhase.
///
/// ## Example
///
/// ```gleam
/// from_work_state(WorkClaimed) // -> Claimed(Taken)
/// ```
pub fn from_work_state(state: WorkState) -> TaskPhase {
  case state {
    WorkAvailable -> Available
    WorkClaimed -> Claimed(Taken)
    WorkOngoing -> Claimed(Ongoing)
    WorkDone -> Done
  }
}
