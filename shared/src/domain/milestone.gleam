//// Milestone domain types for ScrumBringer.

import gleam/option.{type Option}

pub type MilestoneState {
  Ready
  Active
  Completed
}

pub type Milestone {
  Milestone(
    id: Int,
    project_id: Int,
    name: String,
    description: Option(String),
    state: MilestoneState,
    position: Int,
    created_by: Int,
    created_at: String,
    activated_at: Option(String),
    completed_at: Option(String),
  )
}

pub type MilestoneProgress {
  MilestoneProgress(
    milestone: Milestone,
    cards_total: Int,
    cards_completed: Int,
    tasks_total: Int,
    tasks_completed: Int,
  )
}

pub fn progress_is_completed(progress: MilestoneProgress) -> Bool {
  let has_work = progress.cards_total > 0 || progress.tasks_total > 0
  let cards_done = progress.cards_total == progress.cards_completed
  let tasks_done = progress.tasks_total == progress.tasks_completed

  has_work && cards_done && tasks_done
}

pub fn state_to_string(state: MilestoneState) -> String {
  case state {
    Ready -> "ready"
    Active -> "active"
    Completed -> "completed"
  }
}

pub fn state_from_string(state: String) -> MilestoneState {
  case state {
    "active" -> Active
    "completed" -> Completed
    _ -> Ready
  }
}
