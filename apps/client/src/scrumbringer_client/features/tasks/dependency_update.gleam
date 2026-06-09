//// Effectful task dependency workflow.

import gleam/option as opt

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError, type ApiResult}
import domain/task.{type Task, type TaskDependency}
import scrumbringer_client/api/tasks/dependencies as task_dependencies_api
import scrumbringer_client/api/tasks/operations as task_operations_api
import scrumbringer_client/client_state/member/dependencies as member_dependencies
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/tasks/dependency_state

pub type DependenciesModel {
  DependenciesModel(
    pool: member_pool.Model,
    dependencies: member_dependencies.Model,
  )
}

pub type AuthPolicy {
  NoAuthCheck
  CheckAuth(ApiError)
}

pub type Update(parent_msg) {
  Update(DependenciesModel, Effect(parent_msg), AuthPolicy)
}

pub type DependencyContext(parent_msg) {
  DependencyContext(
    selected_task_id: opt.Option(Int),
    selected_task: opt.Option(Task),
    on_dependency_candidates_fetched: fn(ApiResult(List(Task))) -> parent_msg,
    on_dependency_added: fn(ApiResult(TaskDependency)) -> parent_msg,
    on_dependency_removed: fn(Int, ApiResult(Nil)) -> parent_msg,
  )
}

pub type DependencyFeedbackContext(parent_msg) {
  DependencyFeedbackContext(on_error_toast: fn(String) -> Effect(parent_msg))
}

pub fn try_update(
  model: DependenciesModel,
  inner: pool_messages.Msg,
  context: DependencyContext(parent_msg),
  feedback_context: DependencyFeedbackContext(parent_msg),
) -> opt.Option(Update(parent_msg)) {
  case inner {
    pool_messages.MemberDependenciesFetched(Ok(deps)) ->
      handle_dependencies_fetched_ok(model, deps)
      |> without_auth_check

    pool_messages.MemberDependenciesFetched(Error(err)) ->
      handle_dependencies_fetched_error(model, err)
      |> with_auth_check(err)

    pool_messages.MemberDependencyDialogOpened ->
      handle_dependency_dialog_opened(model, context)
      |> without_auth_check

    pool_messages.MemberDependencyDialogClosed ->
      handle_dependency_dialog_closed(model)
      |> without_auth_check

    pool_messages.MemberDependencySearchChanged(value) ->
      handle_dependency_search_changed(model, value)
      |> without_auth_check

    pool_messages.MemberDependencyCandidatesFetched(Ok(tasks)) ->
      handle_dependency_candidates_fetched_ok(model, tasks)
      |> without_auth_check

    pool_messages.MemberDependencyCandidatesFetched(Error(err)) ->
      handle_dependency_candidates_fetched_error(model, err)
      |> with_auth_check(err)

    pool_messages.MemberDependencySelected(task_id) ->
      handle_dependency_selected(model, task_id)
      |> without_auth_check

    pool_messages.MemberDependencyAddSubmitted ->
      handle_dependency_add_submitted(model, context)
      |> without_auth_check

    pool_messages.MemberDependencyAdded(Ok(dep)) ->
      handle_dependency_added_ok(model, dep, context)
      |> without_auth_check

    pool_messages.MemberDependencyAdded(Error(err)) ->
      handle_dependency_added_error(model, err)
      |> with_auth_check(err)

    pool_messages.MemberDependencyRemoveClicked(depends_on_task_id) ->
      handle_dependency_remove_clicked(model, depends_on_task_id, context)
      |> without_auth_check

    pool_messages.MemberDependencyRemoved(depends_on_task_id, Ok(_)) ->
      handle_dependency_removed_ok(model, depends_on_task_id, context)
      |> without_auth_check

    pool_messages.MemberDependencyRemoved(_depends_on_task_id, Error(err)) ->
      handle_dependency_removed_error(model, err, feedback_context)
      |> with_auth_check(err)

    _ -> opt.None
  }
}

fn without_auth_check(
  result: #(DependenciesModel, Effect(parent_msg)),
) -> opt.Option(Update(parent_msg)) {
  let #(model, fx) = result
  opt.Some(Update(model, fx, NoAuthCheck))
}

fn with_auth_check(
  result: #(DependenciesModel, Effect(parent_msg)),
  err: ApiError,
) -> opt.Option(Update(parent_msg)) {
  let #(model, fx) = result
  opt.Some(Update(model, fx, CheckAuth(err)))
}

pub fn handle_dependencies_fetched_ok(
  model: DependenciesModel,
  deps: List(TaskDependency),
) -> #(DependenciesModel, Effect(parent_msg)) {
  #(
    DependenciesModel(
      ..model,
      dependencies: dependency_state.loaded(model.dependencies, deps),
    ),
    effect.none(),
  )
}

pub fn handle_dependencies_fetched_error(
  model: DependenciesModel,
  err: ApiError,
) -> #(DependenciesModel, Effect(parent_msg)) {
  #(
    DependenciesModel(
      ..model,
      dependencies: dependency_state.failed(model.dependencies, err),
    ),
    effect.none(),
  )
}

pub fn handle_dependency_dialog_opened(
  model: DependenciesModel,
  context: DependencyContext(parent_msg),
) -> #(DependenciesModel, Effect(parent_msg)) {
  case context.selected_task {
    opt.None -> #(model, effect.none())
    opt.Some(task) -> {
      let next =
        DependenciesModel(
          ..model,
          dependencies: dependency_state.open_dialog(model.dependencies),
        )
      #(
        next,
        task_operations_api.list_project_tasks(
          task.project_id,
          dependency_state.candidate_filters(),
          context.on_dependency_candidates_fetched,
        ),
      )
    }
  }
}

pub fn handle_dependency_dialog_closed(
  model: DependenciesModel,
) -> #(DependenciesModel, Effect(parent_msg)) {
  #(
    DependenciesModel(
      ..model,
      dependencies: dependency_state.close_dialog(model.dependencies),
    ),
    effect.none(),
  )
}

pub fn handle_dependency_search_changed(
  model: DependenciesModel,
  value: String,
) -> #(DependenciesModel, Effect(parent_msg)) {
  #(
    DependenciesModel(
      ..model,
      dependencies: dependency_state.search_changed(model.dependencies, value),
    ),
    effect.none(),
  )
}

pub fn handle_dependency_candidates_fetched_ok(
  model: DependenciesModel,
  tasks: List(Task),
) -> #(DependenciesModel, Effect(parent_msg)) {
  #(
    DependenciesModel(
      ..model,
      dependencies: dependency_state.candidates_loaded(
        model.dependencies,
        tasks,
      ),
    ),
    effect.none(),
  )
}

pub fn handle_dependency_candidates_fetched_error(
  model: DependenciesModel,
  err: ApiError,
) -> #(DependenciesModel, Effect(parent_msg)) {
  #(
    DependenciesModel(
      ..model,
      dependencies: dependency_state.candidates_failed(model.dependencies, err),
    ),
    effect.none(),
  )
}

pub fn handle_dependency_selected(
  model: DependenciesModel,
  task_id: Int,
) -> #(DependenciesModel, Effect(parent_msg)) {
  #(
    DependenciesModel(
      ..model,
      dependencies: dependency_state.selected(model.dependencies, task_id),
    ),
    effect.none(),
  )
}

pub fn handle_dependency_add_submitted(
  model: DependenciesModel,
  context: DependencyContext(parent_msg),
) -> #(DependenciesModel, Effect(parent_msg)) {
  case model.dependencies.member_dependency_add_in_flight {
    True -> #(model, effect.none())
    False -> submit_dependency_add(model, context)
  }
}

fn submit_dependency_add(
  model: DependenciesModel,
  context: DependencyContext(parent_msg),
) -> #(DependenciesModel, Effect(parent_msg)) {
  case
    context.selected_task_id,
    model.dependencies.member_dependency_selected_task_id
  {
    opt.Some(task_id), opt.Some(depends_on_task_id) ->
      submit_dependency_add_for_task(
        model,
        task_id,
        depends_on_task_id,
        context,
      )
    _, _ -> #(model, effect.none())
  }
}

fn submit_dependency_add_for_task(
  model: DependenciesModel,
  task_id: Int,
  depends_on_task_id: Int,
  context: DependencyContext(parent_msg),
) -> #(DependenciesModel, Effect(parent_msg)) {
  let model =
    DependenciesModel(
      ..model,
      dependencies: dependency_state.start_add(model.dependencies),
    )
  #(
    model,
    task_dependencies_api.add_task_dependency(
      task_id,
      depends_on_task_id,
      context.on_dependency_added,
    ),
  )
}

pub fn handle_dependency_added_ok(
  model: DependenciesModel,
  dep: TaskDependency,
  context: DependencyContext(parent_msg),
) -> #(DependenciesModel, Effect(parent_msg)) {
  let #(pool, dependencies) =
    dependency_state.added(
      model.pool,
      model.dependencies,
      context.selected_task_id,
      dep,
    )
  #(DependenciesModel(pool: pool, dependencies: dependencies), effect.none())
}

pub fn handle_dependency_added_error(
  model: DependenciesModel,
  err: ApiError,
) -> #(DependenciesModel, Effect(parent_msg)) {
  #(
    DependenciesModel(
      ..model,
      dependencies: dependency_state.add_failed(model.dependencies, err.message),
    ),
    effect.none(),
  )
}

pub fn handle_dependency_remove_clicked(
  model: DependenciesModel,
  depends_on_task_id: Int,
  context: DependencyContext(parent_msg),
) -> #(DependenciesModel, Effect(parent_msg)) {
  case model.dependencies.member_dependency_remove_in_flight {
    opt.Some(_) -> #(model, effect.none())
    opt.None ->
      case context.selected_task_id {
        opt.None -> #(model, effect.none())
        opt.Some(task_id) -> {
          let next =
            DependenciesModel(
              ..model,
              dependencies: dependency_state.start_remove(
                model.dependencies,
                depends_on_task_id,
              ),
            )
          #(
            next,
            task_dependencies_api.delete_task_dependency(
              task_id,
              depends_on_task_id,
              fn(result) {
                context.on_dependency_removed(depends_on_task_id, result)
              },
            ),
          )
        }
      }
  }
}

pub fn handle_dependency_removed_ok(
  model: DependenciesModel,
  depends_on_task_id: Int,
  context: DependencyContext(parent_msg),
) -> #(DependenciesModel, Effect(parent_msg)) {
  let #(pool, dependencies) =
    dependency_state.removed(
      model.pool,
      model.dependencies,
      context.selected_task_id,
      depends_on_task_id,
    )
  #(DependenciesModel(pool: pool, dependencies: dependencies), effect.none())
}

pub fn handle_dependency_removed_error(
  model: DependenciesModel,
  err: ApiError,
  context: DependencyFeedbackContext(parent_msg),
) -> #(DependenciesModel, Effect(parent_msg)) {
  #(
    DependenciesModel(
      ..model,
      dependencies: dependency_state.remove_failed(model.dependencies),
    ),
    context.on_error_toast(err.message),
  )
}
