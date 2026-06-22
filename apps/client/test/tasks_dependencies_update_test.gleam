import gleam/option.{None, Some}
import lustre/effect

import domain/api_error.{type ApiError, ApiError}
import domain/remote
import domain/task.{type Task, type TaskDependency, Task, TaskDependency}
import domain/task_state
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/client_state/member/dependencies as member_dependencies
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/tasks/dependency_update

fn sample_dependency() -> TaskDependency {
  TaskDependency(
    depends_on_task_id: 11,
    title: "Configure OAuth",
    status: task_state.to_status(task_state.Available),
    claimed_by: None,
  )
}

fn sample_task() -> Task {
  let state = task_state.Available
  Task(
    id: 42,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Bug", icon: "bug-ant"),
    ongoing_by: None,
    title: "Prepare release",
    description: Some("Review checklist."),
    priority: 2,
    state: state,
    created_by: 1,
    created_at: "2026-03-20T14:00:00Z",
    due_date: None,
    version: 3,
    parent_card_id: None,
    card_id: None,
    card_title: None,
    card_color: None,
    has_new_notes: False,
    blocked_count: 0,
    dependencies: [],
  )
}

fn sample_error() -> ApiError {
  ApiError(status: 500, code: "ERR", message: "boom")
}

fn local_model() -> dependency_update.DependenciesModel {
  dependency_update.DependenciesModel(
    pool: member_pool.default_model(),
    dependencies: member_dependencies.default_model(),
  )
}

fn local_context(
  selected_task_id,
  selected_task,
) -> dependency_update.DependencyContext(Nil) {
  dependency_update.DependencyContext(
    selected_task_id: selected_task_id,
    selected_task: selected_task,
    on_dependency_candidates_fetched: fn(_result) { Nil },
    on_dependency_added: fn(_result) { Nil },
    on_dependency_removed: fn(_depends_on_task_id, _result) { Nil },
  )
}

fn feedback_context() -> dependency_update.DependencyFeedbackContext(Nil) {
  dependency_update.DependencyFeedbackContext(on_error_toast: fn(_) {
    effect.from(fn(_dispatch) { Nil })
  })
}

fn run(
  model: dependency_update.DependenciesModel,
  inner: pool_messages.Msg,
  context: dependency_update.DependencyContext(Nil),
) -> #(dependency_update.DependenciesModel, effect.Effect(Nil)) {
  let assert Some(dependency_update.Update(next, fx, _policy)) =
    dependency_update.try_update(model, inner, context, feedback_context())
  #(next, fx)
}

pub fn local_dependencies_fetched_ok_sets_loaded_dependencies_test() {
  let dep = sample_dependency()
  let #(next, fx) =
    run(
      local_model(),
      pool_messages.MemberDependenciesFetched(Ok([dep])),
      local_context(Some(42), Some(sample_task())),
    )

  let assert True =
    next.dependencies.member_dependencies == remote.Loaded([dep])
  let assert True = fx == effect.none()
}

pub fn local_dependency_dialog_opened_loads_candidates_for_selected_task_test() {
  let #(next, fx) =
    run(
      local_model(),
      pool_messages.MemberDependencyDialogOpened,
      local_context(Some(42), Some(sample_task())),
    )

  let assert dialog_mode.DialogCreate =
    next.dependencies.member_dependency_dialog_mode
  let assert True =
    next.dependencies.member_dependency_candidates == remote.Loading
  let assert None = next.dependencies.member_dependency_selected_task_id
  let assert True = fx != effect.none()
}

pub fn local_dependency_add_submitted_sets_in_flight_test() {
  let model =
    dependency_update.DependenciesModel(
      ..local_model(),
      dependencies: member_dependencies.Model(
        ..member_dependencies.default_model(),
        member_dependency_selected_task_id: Some(11),
        member_dependency_add_error: Some("old"),
      ),
    )

  let #(next, fx) =
    run(
      model,
      pool_messages.MemberDependencyAddSubmitted,
      local_context(Some(42), Some(sample_task())),
    )

  let assert True = next.dependencies.member_dependency_add_in_flight
  let assert None = next.dependencies.member_dependency_add_error
  let assert True = fx != effect.none()
}

pub fn local_dependency_added_ok_updates_dependencies_and_blocked_count_test() {
  let task = sample_task()
  let dep = sample_dependency()
  let model =
    dependency_update.DependenciesModel(
      pool: member_pool.Model(
        ..member_pool.default_model(),
        member_tasks: remote.Loaded([task]),
      ),
      dependencies: member_dependencies.Model(
        ..member_dependencies.default_model(),
        member_dependency_add_in_flight: True,
        member_dependency_dialog_mode: dialog_mode.DialogCreate,
      ),
    )

  let #(next, fx) =
    run(
      model,
      pool_messages.MemberDependencyAdded(Ok(dep)),
      local_context(Some(42), Some(task)),
    )

  let expected_task = Task(..task, dependencies: [dep], blocked_count: 1)
  let assert True =
    next.dependencies.member_dependencies == remote.Loaded([dep])
  let assert True = next.pool.member_tasks == remote.Loaded([expected_task])
  let assert False = next.dependencies.member_dependency_add_in_flight
  let assert dialog_mode.DialogClosed =
    next.dependencies.member_dependency_dialog_mode
  let assert True = fx == effect.none()
}

pub fn local_dependency_removed_ok_removes_dependency_and_decrements_count_test() {
  let dep = sample_dependency()
  let task = Task(..sample_task(), blocked_count: 1, dependencies: [dep])
  let model =
    dependency_update.DependenciesModel(
      pool: member_pool.Model(
        ..member_pool.default_model(),
        member_tasks: remote.Loaded([task]),
      ),
      dependencies: member_dependencies.Model(
        ..member_dependencies.default_model(),
        member_dependencies: remote.Loaded([dep]),
        member_dependency_remove_in_flight: Some(11),
      ),
    )

  let #(next, fx) =
    run(
      model,
      pool_messages.MemberDependencyRemoved(11, Ok(Nil)),
      local_context(Some(42), Some(task)),
    )

  let expected_task = Task(..task, blocked_count: 0, dependencies: [])
  let assert True = next.dependencies.member_dependencies == remote.Loaded([])
  let assert True = next.pool.member_tasks == remote.Loaded([expected_task])
  let assert None = next.dependencies.member_dependency_remove_in_flight
  let assert True = fx == effect.none()
}

pub fn local_dependency_removed_error_clears_in_flight_test() {
  let model =
    dependency_update.DependenciesModel(
      ..local_model(),
      dependencies: member_dependencies.Model(
        ..member_dependencies.default_model(),
        member_dependency_remove_in_flight: Some(11),
      ),
    )

  let #(next, fx) =
    run(
      model,
      pool_messages.MemberDependencyRemoved(11, Error(sample_error())),
      local_context(Some(42), Some(sample_task())),
    )

  let assert None = next.dependencies.member_dependency_remove_in_flight
  let assert True = fx != effect.none()
}

pub fn dependency_update_try_update_selected_without_auth_test() {
  let assert Some(dependency_update.Update(
    next,
    fx,
    dependency_update.NoAuthCheck,
  )) =
    dependency_update.try_update(
      local_model(),
      pool_messages.MemberDependencySelected(11),
      local_context(Some(42), Some(sample_task())),
      feedback_context(),
    )

  let assert Some(11) = next.dependencies.member_dependency_selected_task_id
  let assert True = fx == effect.none()
}

pub fn dependency_update_try_update_candidates_error_checks_auth_test() {
  let err = sample_error()

  let assert Some(dependency_update.Update(
    next,
    fx,
    dependency_update.CheckAuth(policy_err),
  )) =
    dependency_update.try_update(
      local_model(),
      pool_messages.MemberDependencyCandidatesFetched(Error(err)),
      local_context(Some(42), Some(sample_task())),
      feedback_context(),
    )

  let assert True = policy_err == err
  let assert True =
    next.dependencies.member_dependency_candidates == remote.Failed(err)
  let assert True = fx == effect.none()
}

pub fn dependency_update_try_update_ignores_non_dependency_messages_test() {
  let assert None =
    dependency_update.try_update(
      local_model(),
      pool_messages.MemberPoolFiltersToggled,
      local_context(Some(42), Some(sample_task())),
      feedback_context(),
    )
}
