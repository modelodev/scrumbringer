//// Reconcile task state from the current user's active work sessions.

import gleam/list
import gleam/option as opt

import domain/remote.{type Remote, Loaded}
import domain/task as domain_task
import domain/task/state as task_state
import scrumbringer_client/features/tasks/task_list

pub fn apply_active_sessions(
  tasks: Remote(List(domain_task.Task)),
  current_user_id: opt.Option(Int),
  sessions: List(domain_task.WorkSession),
) -> Remote(List(domain_task.Task)) {
  case current_user_id {
    opt.Some(user_id) ->
      case tasks {
        Loaded(items) ->
          Loaded(
            list.map(items, fn(task) { reconcile_task(task, user_id, sessions) }),
          )
        _ -> tasks
      }
    opt.None -> tasks
  }
}

pub fn mark_task_ongoing(
  tasks: Remote(List(domain_task.Task)),
  task_id: Int,
  current_user_id: opt.Option(Int),
) -> Remote(List(domain_task.Task)) {
  case current_user_id {
    opt.Some(user_id) ->
      task_list.update(tasks, task_id, fn(task) {
        case task.state {
          task_state.Claimed(claimed_by: claimed_by, claimed_at: claimed_at, ..)
            if claimed_by == user_id
          ->
            domain_task.with_state(
              domain_task.with_ongoing_by(
                task,
                opt.Some(domain_task.OngoingBy(user_id)),
              ),
              task_state.Claimed(
                claimed_by: claimed_by,
                claimed_at: claimed_at,
                mode: task_state.Ongoing,
              ),
            )
          _ -> task
        }
      })
    opt.None -> tasks
  }
}

pub fn mark_task_taken(
  tasks: Remote(List(domain_task.Task)),
  task_id: Int,
  current_user_id: opt.Option(Int),
) -> Remote(List(domain_task.Task)) {
  case current_user_id {
    opt.Some(user_id) ->
      task_list.update(tasks, task_id, fn(task) {
        case task.state {
          task_state.Claimed(
            claimed_by: claimed_by,
            claimed_at: claimed_at,
            mode: task_state.Ongoing,
          )
            if claimed_by == user_id
          ->
            domain_task.with_state(
              domain_task.with_ongoing_by(task, opt.None),
              task_state.Claimed(
                claimed_by: claimed_by,
                claimed_at: claimed_at,
                mode: task_state.Taken,
              ),
            )
          _ -> task
        }
      })
    opt.None -> tasks
  }
}

fn reconcile_task(
  task: domain_task.Task,
  current_user_id: Int,
  sessions: List(domain_task.WorkSession),
) -> domain_task.Task {
  case task.state {
    task_state.Claimed(
      claimed_by: claimed_by,
      claimed_at: claimed_at,
      mode: mode,
    )
      if claimed_by == current_user_id
    -> {
      let is_active = has_session(sessions, task.id)
      case is_active, mode {
        True, task_state.Ongoing ->
          domain_task.with_ongoing_by(
            task,
            opt.Some(domain_task.OngoingBy(current_user_id)),
          )
        True, task_state.Taken ->
          domain_task.with_state(
            domain_task.with_ongoing_by(
              task,
              opt.Some(domain_task.OngoingBy(current_user_id)),
            ),
            task_state.Claimed(
              claimed_by: claimed_by,
              claimed_at: claimed_at,
              mode: task_state.Ongoing,
            ),
          )
        False, task_state.Ongoing ->
          domain_task.with_state(
            domain_task.with_ongoing_by(task, opt.None),
            task_state.Claimed(
              claimed_by: claimed_by,
              claimed_at: claimed_at,
              mode: task_state.Taken,
            ),
          )
        False, task_state.Taken -> task
      }
    }
    _ -> task
  }
}

fn has_session(sessions: List(domain_task.WorkSession), task_id: Int) -> Bool {
  list.any(sessions, fn(session) {
    let domain_task.WorkSession(task_id: session_task_id, ..) = session
    session_task_id == task_id
  })
}
