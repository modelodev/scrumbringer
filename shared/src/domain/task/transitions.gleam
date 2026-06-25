//// Task execution transitions and final-state guards.

import domain/task/entity as task_entity
import domain/task/state
import domain/user/id as user_id

pub type TaskTransitionError {
  TaskAlreadyClosed
  TaskAlreadyClaimed
  TaskNotClaimed
  TaskClaimedByAnotherUser
}

pub fn claim_task(
  task: task_entity.Task,
  actor_id: user_id.UserId,
  now: String,
  mode: state.TaskClaimMode,
) -> Result(task_entity.Task, TaskTransitionError) {
  let actor_id = user_id.to_int(actor_id)

  case task.execution_state {
    state.Available ->
      Ok(
        task_entity.Task(
          ..task,
          execution_state: state.Claimed(actor_id, now, mode),
        ),
      )
    state.Claimed(..) -> Error(TaskAlreadyClaimed)
    state.Closed(..) -> Error(TaskAlreadyClosed)
  }
}

pub fn close_task(
  task: task_entity.Task,
  actor_id: user_id.UserId,
  now: String,
) -> Result(task_entity.Task, TaskTransitionError) {
  let actor_id = user_id.to_int(actor_id)

  case task.execution_state {
    state.Available -> Error(TaskNotClaimed)
    state.Claimed(claimed_by, _, _) if claimed_by == actor_id ->
      Ok(
        task_entity.Task(
          ..task,
          execution_state: state.Closed(state.ClosedByClaimant, now, actor_id),
        ),
      )
    state.Claimed(..) -> Error(TaskClaimedByAnotherUser)
    state.Closed(..) -> Error(TaskAlreadyClosed)
  }
}
