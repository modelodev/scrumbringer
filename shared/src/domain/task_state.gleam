////
//// Task lifecycle state with claim/completion metadata.
//// Invalid combinations (e.g., completed + claimed_by) are unrepresentable.
////

import domain/task_status as status
import gleam/option.{type Option, None, Some}

pub type TaskState {
  Available
  Claimed(claimed_by: Int, claimed_at: String, mode: status.ClaimedState)
  Done(completed_at: String)
}

pub type TaskStateError {
  ClaimedMissingUser
  ClaimedMissingAt
  DoneMissingAt
  DoneWithClaim
  AvailableWithClaim
  UnknownStatus(String)
}

pub fn to_status(state: TaskState) -> status.TaskPhase {
  case state {
    Available -> status.Available
    Claimed(mode: mode, ..) -> status.Claimed(mode)
    Done(completed_at: _) -> status.Done
  }
}

pub fn to_work_state(state: TaskState) -> status.WorkState {
  case state {
    Available -> status.WorkAvailable
    Claimed(mode: status.Taken, ..) -> status.WorkClaimed
    Claimed(mode: status.Ongoing, ..) -> status.WorkOngoing
    Done(completed_at: _) -> status.WorkDone
  }
}

pub fn claimed_by(state: TaskState) -> Option(Int) {
  case state {
    Claimed(claimed_by: user_id, ..) -> Some(user_id)
    _ -> None
  }
}

pub fn claimed_at(state: TaskState) -> Option(String) {
  case state {
    Claimed(claimed_at: at, ..) -> Some(at)
    _ -> None
  }
}

pub fn completed_at(state: TaskState) -> Option(String) {
  case state {
    Done(completed_at: at) -> Some(at)
    _ -> None
  }
}

pub fn from_db(
  status: String,
  is_ongoing: Bool,
  claimed_by: Option(Int),
  claimed_at: Option(String),
  completed_at: Option(String),
) -> Result(TaskState, TaskStateError) {
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
              True -> status.Ongoing
              False -> status.Taken
            }),
          )
        None, _ -> Error(ClaimedMissingUser)
        _, None -> Error(ClaimedMissingAt)
      }

    "completed" ->
      case claimed_by, completed_at {
        Some(_), _ -> Error(DoneWithClaim)
        None, Some(at) -> Ok(Done(completed_at: at))
        None, None -> Error(DoneMissingAt)
      }

    other -> Error(UnknownStatus(other))
  }
}

pub fn to_db(
  state: TaskState,
) -> #(String, Bool, Option(Int), Option(String), Option(String)) {
  case state {
    Available -> #("available", False, None, None, None)
    Claimed(claimed_by: user_id, claimed_at: at, mode: mode) -> #(
      "claimed",
      mode == status.Ongoing,
      Some(user_id),
      Some(at),
      None,
    )
    Done(completed_at: at) -> #("completed", False, None, None, Some(at))
  }
}
