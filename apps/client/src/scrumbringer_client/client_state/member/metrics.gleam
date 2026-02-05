//// Member metrics state.

import domain/metrics.{type MyMetrics}
import domain/remote.{type Remote, NotAsked}
import domain/task.{type WorkSessionsPayload}

/// Represents member metrics state.
pub type Model {
  Model(
    member_work_sessions: Remote(WorkSessionsPayload),
    member_metrics: Remote(MyMetrics),
  )
}

/// Provides default member metrics state.
pub fn default_model() -> Model {
  Model(
    member_work_sessions: NotAsked,
    member_metrics: NotAsked,
  )
}
