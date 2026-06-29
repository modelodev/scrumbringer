//// Typed task action references for versioned mutations.

/// The task mutation the user requested.
pub type TaskAction {
  Claim
  Release
  Close
}

/// A task action target may already include the optimistic-lock version, or it
/// may need to be resolved from the current task source before submission.
pub type TaskActionRef {
  Resolved(task_id: Int, version: Int)
  NeedsResolution(task_id: Int)
}
