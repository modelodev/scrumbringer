//// Task leaf entity for card hierarchy execution rules.

import domain/project/id as project_id
import domain/task/id as task_id
import domain/task/placement.{type TaskPlacement}
import domain/task/state.{type TaskExecutionState}

pub type Task {
  Task(
    id: task_id.TaskId,
    project_id: project_id.ProjectId,
    placement: TaskPlacement,
    execution_state: TaskExecutionState,
    blocked: Bool,
    capability_allowed: Bool,
  )
}
