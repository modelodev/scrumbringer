//// Canonical task execution state for claimable task leaves.
////
//// This module owns the lifecycle ADT used by shared, server, and client code.
//// `domain/task_status.gleam` is only a presentation/filter projection.

import domain/task_status as status
import gleam/option.{type Option, None, Some}

pub type TaskExecutionState {
  Available
  Claimed(claimed_by: Int, claimed_at: String, mode: TaskClaimMode)
  Closed(reason: TaskClosedReason, closed_at: String, closed_by: Int)
}

pub type TaskClaimMode {
  Taken
  Ongoing
}

pub type TaskClosedReason {
  Done
  ManuallyClosed
  ClosedByAncestor
}

pub type TaskExecutionStateFilter {
  FilterAvailable
  FilterClaimed
  FilterClosed
}

pub type TaskExecutionStateError {
  ClaimedMissingUser
  ClaimedMissingAt
  ClosedMissingAt
  ClosedWithClaim
  AvailableWithClaim
  UnknownStatus(String)
}

pub fn to_status(state: TaskExecutionState) -> status.TaskPhase {
  case state {
    Available -> status.Available
    Claimed(mode: Taken, ..) -> status.Claimed(status.Taken)
    Claimed(mode: Ongoing, ..) -> status.Claimed(status.Ongoing)
    Closed(..) -> status.Done
  }
}

pub fn to_work_state(state: TaskExecutionState) -> status.WorkState {
  case state {
    Available -> status.WorkAvailable
    Claimed(mode: Taken, ..) -> status.WorkClaimed
    Claimed(mode: Ongoing, ..) -> status.WorkOngoing
    Closed(..) -> status.WorkDone
  }
}

pub fn claimed_by(state: TaskExecutionState) -> Option(Int) {
  case state {
    Claimed(claimed_by: user_id, ..) -> Some(user_id)
    _ -> None
  }
}

pub fn claimed_at(state: TaskExecutionState) -> Option(String) {
  case state {
    Claimed(claimed_at: at, ..) -> Some(at)
    _ -> None
  }
}

pub fn closed_at(state: TaskExecutionState) -> Option(String) {
  case state {
    Closed(closed_at: at, ..) -> Some(at)
    _ -> None
  }
}

pub fn from_db(
  status: String,
  is_ongoing: Bool,
  claimed_by: Option(Int),
  claimed_at: Option(String),
  completed_at: Option(String),
) -> Result(TaskExecutionState, TaskExecutionStateError) {
  case status {
    "available" ->
      case claimed_by {
        None -> Ok(Available)
        Some(_) -> Error(AvailableWithClaim)
      }

    "claimed" ->
      case claimed_by, claimed_at {
        Some(user_id), Some(at) ->
          Ok(
            Claimed(claimed_by: user_id, claimed_at: at, mode: case is_ongoing {
              True -> Ongoing
              False -> Taken
            }),
          )
        None, _ -> Error(ClaimedMissingUser)
        _, None -> Error(ClaimedMissingAt)
      }

    "completed" | "closed" ->
      case claimed_by, completed_at {
        Some(_), _ -> Error(ClosedWithClaim)
        // Older task-list payloads do not carry closed_by. Repository code that
        // has closed_by available should construct Closed directly.
        None, Some(at) -> Ok(Closed(reason: Done, closed_at: at, closed_by: 0))
        None, None -> Error(ClosedMissingAt)
      }

    other -> Error(UnknownStatus(other))
  }
}

pub fn to_db(
  state: TaskExecutionState,
) -> #(String, Bool, Option(Int), Option(String), Option(String)) {
  case state {
    Available -> #("available", False, None, None, None)
    Claimed(claimed_by: user_id, claimed_at: at, mode: mode) -> #(
      "claimed",
      mode == Ongoing,
      Some(user_id),
      Some(at),
      None,
    )
    Closed(closed_at: at, ..) -> #("closed", False, None, None, Some(at))
  }
}
