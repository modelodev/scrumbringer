import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{None, Some}
import support/domain_fixtures

import domain/api_error.{ApiError}
import domain/remote.{Failed, Loaded, Loading}
import domain/task.{type Task, Task}
import domain/task_type.{type TaskType, TaskType}
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/pool/project_refresh

pub fn project_fetched_waits_until_all_projects_complete_test() {
  let project_refresh.ProjectFetched(
    by_project: by_project,
    pending: pending,
    resource: resource,
  ) =
    project_refresh.project_fetched(
      dict.new(),
      2,
      Loading,
      10,
      [1, 2],
      flatten_ints,
    )

  let assert 1 = pending
  let assert Loading = resource
  let assert Ok([1, 2]) = dict.get(by_project, 10)
}

pub fn project_fetched_publishes_loaded_when_last_project_completes_test() {
  let initial =
    dict.new()
    |> dict.insert(10, [1, 2])

  let project_refresh.ProjectFetched(pending: pending, resource: resource, ..) =
    project_refresh.project_fetched(initial, 1, Loading, 20, [3], flatten_ints)

  let assert 0 = pending
  let assert Loaded([_, _, _]) = resource
}

pub fn project_failed_fails_resource_and_clears_pending_test() {
  let #(resource, pending) = project_refresh.project_failed(api_error())

  let assert 0 = pending
  let assert Failed(ApiError(status: 500, code: "ERR", message: "boom")) =
    resource
}

pub fn tasks_fetched_updates_pool_task_resource_fields_test() {
  let pool =
    member_pool.Model(..member_pool.default_model(), member_tasks_pending: 1)

  let next = project_refresh.tasks_fetched(pool, 10, [task(1)])

  let assert 0 = next.member_tasks_pending
  let assert Loaded([Task(id: 1, ..)]) = next.member_tasks
  let assert Ok([Task(id: 1, ..)]) = dict.get(next.member_tasks_by_project, 10)
}

pub fn tasks_failed_fails_pool_task_resource_and_clears_pending_test() {
  let pool =
    member_pool.Model(..member_pool.default_model(), member_tasks_pending: 2)

  let next = project_refresh.tasks_failed(pool, api_error())

  let assert 0 = next.member_tasks_pending
  let assert Failed(ApiError(status: 500, code: "ERR", message: "boom")) =
    next.member_tasks
}

pub fn task_types_fetched_updates_pool_task_type_resource_fields_test() {
  let pool =
    member_pool.Model(
      ..member_pool.default_model(),
      member_task_types_pending: 1,
    )

  let next = project_refresh.task_types_fetched(pool, 10, [task_type(1)])

  let assert 0 = next.member_task_types_pending
  let assert Loaded([TaskType(id: 1, ..)]) = next.member_task_types
  let assert Ok([TaskType(id: 1, ..)]) =
    dict.get(next.member_task_types_by_project, 10)
}

pub fn task_types_failed_fails_pool_task_type_resource_and_clears_pending_test() {
  let pool =
    member_pool.Model(
      ..member_pool.default_model(),
      member_task_types_pending: 2,
    )

  let next = project_refresh.task_types_failed(pool, api_error())

  let assert 0 = next.member_task_types_pending
  let assert Failed(ApiError(status: 500, code: "ERR", message: "boom")) =
    next.member_task_types
}

pub fn try_update_tasks_fetched_returns_local_update_test() {
  let pool =
    member_pool.Model(..member_pool.default_model(), member_tasks_pending: 1)

  let assert Some(project_refresh.Update(next, policy)) =
    project_refresh.try_update(
      pool,
      pool_messages.MemberProjectTasksFetched(10, Ok([task(1)])),
    )

  let assert project_refresh.NoAuthCheck = policy
  let assert 0 = next.member_tasks_pending
  let assert Loaded([Task(id: 1, ..)]) = next.member_tasks
}

pub fn try_update_task_types_error_requests_auth_check_test() {
  let err = api_error()
  let pool =
    member_pool.Model(
      ..member_pool.default_model(),
      member_task_types_pending: 2,
    )

  let assert Some(project_refresh.Update(next, policy)) =
    project_refresh.try_update(
      pool,
      pool_messages.MemberTaskTypesFetched(10, Error(err)),
    )
  let assert project_refresh.CheckAuth(auth_err) = policy

  let assert True = auth_err == err
  let assert 0 = next.member_task_types_pending
  let assert Failed(ApiError(status: 500, code: "ERR", message: "boom")) =
    next.member_task_types
}

pub fn try_update_ignores_non_project_refresh_messages_test() {
  let assert None =
    project_refresh.try_update(
      member_pool.default_model(),
      pool_messages.MemberPoolVisibilityChanged("all-open"),
    )
}

fn flatten_ints(values_by_project: Dict(Int, List(Int))) -> List(Int) {
  values_by_project
  |> dict.to_list
  |> list.fold([], fn(acc, pair) {
    let #(_project_id, values) = pair
    list.append(acc, values)
  })
}

fn api_error() {
  ApiError(status: 500, code: "ERR", message: "boom")
}

fn task(id: Int) -> Task {
  Task(..domain_fixtures.task(id, "Task", 1), description: None)
}

fn task_type(id: Int) -> TaskType {
  TaskType(
    id: id,
    name: "Type",
    icon: "box",
    capability_id: None,
    tasks_count: 0,
  )
}
