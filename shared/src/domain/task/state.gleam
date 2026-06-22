//// Task execution state for claimable task leaves.

import domain/user/id.{type UserId}

pub type TaskExecutionState {
  Available
  Claimed(claimed_by: UserId, claimed_at: String, mode: TaskClaimMode)
  Closed(reason: TaskClosedReason, closed_at: String, closed_by: UserId)
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
