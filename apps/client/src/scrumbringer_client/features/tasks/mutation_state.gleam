//// Pure optimistic task mutation state transitions.

import gleam/option as opt

import domain/remote.{Loaded}
import domain/task.{type Task}
import domain/task/state as task_state
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/tasks/task_list

pub fn start_claim(
  model: member_pool.Model,
  task_id: Int,
  current_user_id: opt.Option(Int),
) -> member_pool.Model {
  let snapshot = task_list.snapshot(model.member_tasks)
  let tasks = case current_user_id {
    opt.Some(user_id) ->
      task_list.set_state(
        model.member_tasks,
        task_id,
        task_state.Claimed(
          claimed_by: user_id,
          claimed_at: "",
          mode: task_state.Taken,
        ),
      )
    opt.None -> model.member_tasks
  }

  member_pool.Model(
    ..model,
    member_tasks: tasks,
    member_task_mutation_in_flight: True,
    member_task_mutation_task_id: opt.Some(task_id),
    member_tasks_snapshot: snapshot,
  )
}

pub fn start_release(
  model: member_pool.Model,
  task_id: Int,
) -> member_pool.Model {
  start_with_state(model, task_id, task_state.Available)
}

pub fn start_complete(
  model: member_pool.Model,
  task_id: Int,
  current_user_id: opt.Option(Int),
) -> member_pool.Model {
  case current_user_id {
    opt.Some(user_id) ->
      start_with_state(
        model,
        task_id,
        task_state.Closed(task_state.Done, "", user_id),
      )
    opt.None ->
      member_pool.Model(
        ..model,
        member_task_mutation_in_flight: True,
        member_task_mutation_task_id: opt.Some(task_id),
        member_tasks_snapshot: task_list.snapshot(model.member_tasks),
      )
  }
}

pub fn start_delete(model: member_pool.Model, task_id: Int) -> member_pool.Model {
  member_pool.Model(
    ..model,
    member_tasks: task_list.remove(model.member_tasks, task_id),
    member_task_mutation_in_flight: True,
    member_task_mutation_task_id: opt.Some(task_id),
    member_tasks_snapshot: task_list.snapshot(model.member_tasks),
    member_task_show_editing: False,
    member_task_show_edit_error: opt.None,
  )
}

pub fn start_dropped_claim(model: member_pool.Model) -> member_pool.Model {
  member_pool.Model(..model, member_task_mutation_in_flight: True)
}

pub fn clear(model: member_pool.Model) -> member_pool.Model {
  member_pool.Model(
    ..model,
    member_task_mutation_in_flight: False,
    member_task_mutation_task_id: opt.None,
    member_tasks_snapshot: opt.None,
  )
}

pub fn confirm_task(model: member_pool.Model, task: Task) -> member_pool.Model {
  member_pool.Model(
    ..clear(model),
    member_tasks: task_list.replace(model.member_tasks, task),
  )
}

pub fn restore_snapshot(model: member_pool.Model) -> member_pool.Model {
  case model.member_tasks_snapshot {
    opt.Some(tasks) -> member_pool.Model(..model, member_tasks: Loaded(tasks))
    opt.None -> model
  }
}

pub fn restore_and_clear(model: member_pool.Model) -> member_pool.Model {
  model
  |> restore_snapshot()
  |> clear()
}

fn start_with_state(
  model: member_pool.Model,
  task_id: Int,
  state: task_state.TaskExecutionState,
) -> member_pool.Model {
  member_pool.Model(
    ..model,
    member_tasks: task_list.set_state(model.member_tasks, task_id, state),
    member_task_mutation_in_flight: True,
    member_task_mutation_task_id: opt.Some(task_id),
    member_tasks_snapshot: task_list.snapshot(model.member_tasks),
  )
}
