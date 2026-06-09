//// Pure pool refresh derivations for resources fetched per project.

import gleam/dict.{type Dict}
import gleam/option as opt

import domain/api_error.{type ApiError}
import domain/remote.{type Remote, Failed, Loaded}
import domain/task.{type Task}
import domain/task_type.{type TaskType}
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/helpers/dicts as helpers_dicts

pub type AuthPolicy {
  NoAuthCheck
  CheckAuth(ApiError)
}

pub type Update {
  Update(member_pool.Model, AuthPolicy)
}

pub type ProjectFetched(data) {
  ProjectFetched(
    by_project: Dict(Int, List(data)),
    pending: Int,
    resource: Remote(List(data)),
  )
}

pub fn try_update(
  model: member_pool.Model,
  inner: pool_messages.Msg,
) -> opt.Option(Update) {
  case inner {
    pool_messages.MemberProjectTasksFetched(project_id, Ok(tasks)) ->
      tasks_fetched(model, project_id, tasks)
      |> without_auth_check

    pool_messages.MemberProjectTasksFetched(_project_id, Error(err)) ->
      tasks_failed(model, err)
      |> with_auth_check(err)

    pool_messages.MemberTaskTypesFetched(project_id, Ok(task_types)) ->
      task_types_fetched(model, project_id, task_types)
      |> without_auth_check

    pool_messages.MemberTaskTypesFetched(_project_id, Error(err)) ->
      task_types_failed(model, err)
      |> with_auth_check(err)

    _ -> opt.None
  }
}

fn without_auth_check(model: member_pool.Model) -> opt.Option(Update) {
  opt.Some(Update(model, NoAuthCheck))
}

fn with_auth_check(
  model: member_pool.Model,
  err: ApiError,
) -> opt.Option(Update) {
  opt.Some(Update(model, CheckAuth(err)))
}

pub fn project_fetched(
  by_project: Dict(Int, List(data)),
  pending: Int,
  current: Remote(List(data)),
  project_id: Int,
  items: List(data),
  flatten: fn(Dict(Int, List(data))) -> List(data),
) -> ProjectFetched(data) {
  let next_by_project = dict.insert(by_project, project_id, items)
  let next_pending = decrement_pending(pending)
  let next_resource = case next_pending <= 0 {
    True -> Loaded(flatten(next_by_project))
    False -> current
  }

  ProjectFetched(
    by_project: next_by_project,
    pending: next_pending,
    resource: next_resource,
  )
}

pub fn project_failed(err: ApiError) -> #(Remote(List(data)), Int) {
  #(Failed(err), 0)
}

pub fn tasks_fetched(
  model: member_pool.Model,
  project_id: Int,
  tasks: List(Task),
) -> member_pool.Model {
  let ProjectFetched(
    by_project: tasks_by_project,
    pending: pending,
    resource: next_tasks,
  ) =
    project_fetched(
      model.member_tasks_by_project,
      model.member_tasks_pending,
      model.member_tasks,
      project_id,
      tasks,
      helpers_dicts.flatten_tasks,
    )

  member_pool.Model(
    ..model,
    member_tasks_by_project: tasks_by_project,
    member_tasks_pending: pending,
    member_tasks: next_tasks,
  )
}

pub fn tasks_failed(
  model: member_pool.Model,
  err: ApiError,
) -> member_pool.Model {
  let #(next_tasks, pending) = project_failed(err)

  member_pool.Model(
    ..model,
    member_tasks: next_tasks,
    member_tasks_pending: pending,
  )
}

pub fn task_types_fetched(
  model: member_pool.Model,
  project_id: Int,
  task_types: List(TaskType),
) -> member_pool.Model {
  let ProjectFetched(
    by_project: task_types_by_project,
    pending: pending,
    resource: next_task_types,
  ) =
    project_fetched(
      model.member_task_types_by_project,
      model.member_task_types_pending,
      model.member_task_types,
      project_id,
      task_types,
      helpers_dicts.flatten_task_types,
    )

  member_pool.Model(
    ..model,
    member_task_types_by_project: task_types_by_project,
    member_task_types_pending: pending,
    member_task_types: next_task_types,
  )
}

pub fn task_types_failed(
  model: member_pool.Model,
  err: ApiError,
) -> member_pool.Model {
  let #(next_task_types, pending) = project_failed(err)

  member_pool.Model(
    ..model,
    member_task_types: next_task_types,
    member_task_types_pending: pending,
  )
}

fn decrement_pending(pending: Int) -> Int {
  case pending <= 0 {
    True -> 0
    False -> pending - 1
  }
}
