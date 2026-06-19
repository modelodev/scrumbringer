import gleam/option.{None, Some}

import domain/api_error.{ApiError}
import domain/remote
import domain/task.{type Task, type TaskDependency, Task, TaskDependency}
import domain/task_state
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/client_state/member/dependencies as member_dependencies
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/tasks/dependency_state

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
    status: task_state.to_status(state),
    work_state: task_state.to_work_state(state),
    created_by: 1,
    created_at: "2026-03-20T14:00:00Z",
    due_date: None,
    version: 3,
    milestone_id: None,
    card_id: None,
    card_title: None,
    card_color: None,
    has_new_notes: False,
    blocked_count: 0,
    dependencies: [],
  )
}

pub fn dependency_state_open_and_close_dialog_test() {
  let opened = dependency_state.open_dialog(member_dependencies.default_model())

  let assert dialog_mode.DialogCreate = opened.member_dependency_dialog_mode
  let assert "" = opened.member_dependency_search_query
  let assert True = opened.member_dependency_candidates == remote.Loading
  let assert None = opened.member_dependency_selected_task_id
  let assert None = opened.member_dependency_add_error

  let closed = dependency_state.close_dialog(opened)

  let assert dialog_mode.DialogClosed = closed.member_dependency_dialog_mode
  let assert True = closed.member_dependency_candidates == remote.NotAsked
  let assert None = closed.member_dependency_selected_task_id
}

pub fn dependency_state_candidate_and_selection_updates_test() {
  let err = ApiError(status: 500, code: "ERR", message: "boom")
  let searched =
    dependency_state.search_changed(
      member_dependencies.default_model(),
      "oauth",
    )
  let loaded = dependency_state.candidates_loaded(searched, [sample_task()])
  let failed = dependency_state.candidates_failed(searched, err)
  let selected = dependency_state.selected(searched, 11)

  let assert "oauth" = searched.member_dependency_search_query
  let assert True =
    loaded.member_dependency_candidates == remote.Loaded([sample_task()])
  let assert True = failed.member_dependency_candidates == remote.Failed(err)
  let assert Some(11) = selected.member_dependency_selected_task_id
}

pub fn dependency_state_added_updates_dependencies_and_task_test() {
  let task = sample_task()
  let dep = sample_dependency()
  let pool =
    member_pool.Model(
      ..member_pool.default_model(),
      member_tasks: remote.Loaded([task]),
    )
  let dependencies =
    member_dependencies.Model(
      ..member_dependencies.default_model(),
      member_dependency_add_in_flight: True,
      member_dependency_dialog_mode: dialog_mode.DialogCreate,
      member_dependency_selected_task_id: Some(11),
      member_dependency_add_error: Some("old"),
    )

  let #(next_pool, next_dependencies) =
    dependency_state.added(pool, dependencies, Some(42), dep)

  let expected_task = Task(..task, dependencies: [dep], blocked_count: 1)
  let assert True = next_pool.member_tasks == remote.Loaded([expected_task])
  let assert True =
    next_dependencies.member_dependencies == remote.Loaded([dep])
  let assert False = next_dependencies.member_dependency_add_in_flight
  let assert dialog_mode.DialogClosed =
    next_dependencies.member_dependency_dialog_mode
  let assert None = next_dependencies.member_dependency_selected_task_id
  let assert None = next_dependencies.member_dependency_add_error
}

pub fn dependency_state_removed_updates_dependencies_and_task_test() {
  let dep = sample_dependency()
  let task = Task(..sample_task(), dependencies: [dep], blocked_count: 1)
  let pool =
    member_pool.Model(
      ..member_pool.default_model(),
      member_tasks: remote.Loaded([task]),
    )
  let dependencies =
    member_dependencies.Model(
      ..member_dependencies.default_model(),
      member_dependencies: remote.Loaded([dep]),
      member_dependency_remove_in_flight: Some(11),
    )

  let #(next_pool, next_dependencies) =
    dependency_state.removed(pool, dependencies, Some(42), 11)

  let expected_task = Task(..task, dependencies: [], blocked_count: 0)
  let assert True = next_pool.member_tasks == remote.Loaded([expected_task])
  let assert True = next_dependencies.member_dependencies == remote.Loaded([])
  let assert None = next_dependencies.member_dependency_remove_in_flight
}

pub fn dependency_state_start_and_fail_transitions_test() {
  let adding =
    dependency_state.start_add(
      member_dependencies.Model(
        ..member_dependencies.default_model(),
        member_dependency_add_error: Some("old"),
      ),
    )
  let add_failed = dependency_state.add_failed(adding, "boom")
  let removing =
    dependency_state.start_remove(member_dependencies.default_model(), 11)
  let remove_failed = dependency_state.remove_failed(removing)

  let assert True = adding.member_dependency_add_in_flight
  let assert None = adding.member_dependency_add_error
  let assert False = add_failed.member_dependency_add_in_flight
  let assert Some("boom") = add_failed.member_dependency_add_error
  let assert Some(11) = removing.member_dependency_remove_in_flight
  let assert None = remove_failed.member_dependency_remove_in_flight
}
