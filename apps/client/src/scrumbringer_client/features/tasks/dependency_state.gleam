//// Pure task dependency state transitions.

import gleam/option as opt

import domain/api_error.{type ApiError}
import domain/remote.{Failed, Loaded, Loading, NotAsked}
import domain/task.{type Task, type TaskDependency}
import scrumbringer_client/api/tasks/operations as task_operations
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/client_state/member/dependencies as member_dependencies
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/tasks/dependency_list
import scrumbringer_client/features/tasks/task_list

pub fn candidate_filters() -> task_operations.TaskFilters {
  task_operations.TaskFilters(
    status: opt.None,
    type_id: opt.None,
    capability_id: opt.None,
    q: opt.None,
    blocked: opt.None,
    card_id: opt.None,
  )
}

pub fn loaded(
  dependencies: member_dependencies.Model,
  deps: List(TaskDependency),
) -> member_dependencies.Model {
  member_dependencies.Model(..dependencies, member_dependencies: Loaded(deps))
}

pub fn failed(
  dependencies: member_dependencies.Model,
  err: ApiError,
) -> member_dependencies.Model {
  member_dependencies.Model(..dependencies, member_dependencies: Failed(err))
}

pub fn open_dialog(
  dependencies: member_dependencies.Model,
) -> member_dependencies.Model {
  member_dependencies.Model(
    ..dependencies,
    member_dependency_dialog_mode: dialog_mode.DialogCreate,
    member_dependency_search_query: "",
    member_dependency_candidates: Loading,
    member_dependency_selected_task_id: opt.None,
    member_dependency_add_error: opt.None,
  )
}

pub fn close_dialog(
  dependencies: member_dependencies.Model,
) -> member_dependencies.Model {
  member_dependencies.Model(
    ..dependencies,
    member_dependency_dialog_mode: dialog_mode.DialogClosed,
    member_dependency_search_query: "",
    member_dependency_candidates: NotAsked,
    member_dependency_selected_task_id: opt.None,
    member_dependency_add_error: opt.None,
  )
}

pub fn search_changed(
  dependencies: member_dependencies.Model,
  value: String,
) -> member_dependencies.Model {
  member_dependencies.Model(
    ..dependencies,
    member_dependency_search_query: value,
  )
}

pub fn candidates_loaded(
  dependencies: member_dependencies.Model,
  tasks: List(Task),
) -> member_dependencies.Model {
  member_dependencies.Model(
    ..dependencies,
    member_dependency_candidates: Loaded(tasks),
  )
}

pub fn candidates_failed(
  dependencies: member_dependencies.Model,
  err: ApiError,
) -> member_dependencies.Model {
  member_dependencies.Model(
    ..dependencies,
    member_dependency_candidates: Failed(err),
  )
}

pub fn selected(
  dependencies: member_dependencies.Model,
  task_id: Int,
) -> member_dependencies.Model {
  member_dependencies.Model(
    ..dependencies,
    member_dependency_selected_task_id: opt.Some(task_id),
  )
}

pub fn start_add(
  dependencies: member_dependencies.Model,
) -> member_dependencies.Model {
  member_dependencies.Model(
    ..dependencies,
    member_dependency_add_in_flight: True,
    member_dependency_add_error: opt.None,
  )
}

pub fn add_failed(
  dependencies: member_dependencies.Model,
  message: String,
) -> member_dependencies.Model {
  member_dependencies.Model(
    ..dependencies,
    member_dependency_add_in_flight: False,
    member_dependency_add_error: opt.Some(message),
  )
}

pub fn added(
  pool: member_pool.Model,
  dependencies: member_dependencies.Model,
  selected_task_id: opt.Option(Int),
  dep: TaskDependency,
) -> #(member_pool.Model, member_dependencies.Model) {
  let #(pool, dependencies) =
    add_dependency(pool, dependencies, selected_task_id, dep)
  #(
    pool,
    member_dependencies.Model(
      ..dependencies,
      member_dependency_add_in_flight: False,
      member_dependency_dialog_mode: dialog_mode.DialogClosed,
      member_dependency_search_query: "",
      member_dependency_selected_task_id: opt.None,
      member_dependency_add_error: opt.None,
    ),
  )
}

pub fn start_remove(
  dependencies: member_dependencies.Model,
  depends_on_task_id: Int,
) -> member_dependencies.Model {
  member_dependencies.Model(
    ..dependencies,
    member_dependency_remove_in_flight: opt.Some(depends_on_task_id),
  )
}

pub fn removed(
  pool: member_pool.Model,
  dependencies: member_dependencies.Model,
  selected_task_id: opt.Option(Int),
  depends_on_task_id: Int,
) -> #(member_pool.Model, member_dependencies.Model) {
  let #(pool, dependencies) =
    remove_dependency(pool, dependencies, selected_task_id, depends_on_task_id)
  #(
    pool,
    member_dependencies.Model(
      ..dependencies,
      member_dependency_remove_in_flight: opt.None,
    ),
  )
}

pub fn remove_failed(
  dependencies: member_dependencies.Model,
) -> member_dependencies.Model {
  member_dependencies.Model(
    ..dependencies,
    member_dependency_remove_in_flight: opt.None,
  )
}

fn add_dependency(
  pool: member_pool.Model,
  dependencies: member_dependencies.Model,
  selected_task_id: opt.Option(Int),
  dep: TaskDependency,
) -> #(member_pool.Model, member_dependencies.Model) {
  case selected_task_id {
    opt.None -> #(pool, dependencies)
    opt.Some(task_id) -> {
      let updated_deps =
        dependency_list.add_to_remote(dependencies.member_dependencies, dep)
      let updated_tasks =
        task_list.update(pool.member_tasks, task_id, fn(task) {
          dependency_list.add_to_task(task, dep)
        })
      #(
        member_pool.Model(..pool, member_tasks: updated_tasks),
        member_dependencies.Model(
          ..dependencies,
          member_dependencies: updated_deps,
        ),
      )
    }
  }
}

fn remove_dependency(
  pool: member_pool.Model,
  dependencies: member_dependencies.Model,
  selected_task_id: opt.Option(Int),
  depends_on_task_id: Int,
) -> #(member_pool.Model, member_dependencies.Model) {
  case selected_task_id {
    opt.None -> #(pool, dependencies)
    opt.Some(task_id) -> {
      let #(updated_deps, blocked_delta) =
        dependency_list.remove_from_remote(
          dependencies.member_dependencies,
          depends_on_task_id,
        )
      let updated_tasks =
        task_list.update(pool.member_tasks, task_id, fn(task) {
          dependency_list.remove_from_task(
            task,
            depends_on_task_id,
            blocked_delta,
          )
        })
      #(
        member_pool.Model(..pool, member_tasks: updated_tasks),
        member_dependencies.Model(
          ..dependencies,
          member_dependencies: updated_deps,
        ),
      )
    }
  }
}
