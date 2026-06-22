import gleam/option.{None, Some}

import domain/api_error.{ApiError}
import domain/remote.{Failed, Loaded, Loading}
import domain/task.{type Task, Task}
import domain/task_state
import domain/task_status
import domain/task_type.{TaskType, TaskTypeInline}
import scrumbringer_client/capability_scope.{AllCapabilities, MyCapabilities}
import scrumbringer_client/features/pool/available_tasks
import scrumbringer_client/features/pool/visibility.{
  AllOpen, Blocked, ReadyToClaim,
}

fn task(id: Int, title: String, type_id: Int, state) -> Task {
  Task(
    id: id,
    project_id: 1,
    type_id: type_id,
    task_type: TaskTypeInline(id: type_id, name: "Bug", icon: "bug-ant"),
    ongoing_by: None,
    title: title,
    description: Some("Task description"),
    priority: 3,
    state: state,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    due_date: None,
    version: 1,
    parent_card_id: None,
    card_id: None,
    card_title: None,
    card_color: None,
    has_new_notes: False,
    blocked_count: 0,
    dependencies: [],
  )
}

fn task_type(id: Int, capability_id) {
  TaskType(
    id: id,
    name: "Type",
    icon: "box",
    capability_id: capability_id,
    tasks_count: 0,
  )
}

fn config(tasks) -> available_tasks.Config {
  available_tasks.Config(
    tasks: tasks,
    task_types: Loaded([]),
    my_capability_ids: Loaded([]),
    type_filter: None,
    capability_filter: None,
    search_query: "",
    capability_scope: AllCapabilities,
    visibility: AllOpen,
  )
}

pub fn pool_available_tasks_reports_loading_without_root_model_test() {
  let assert available_tasks.Loading = available_tasks.state(config(Loading))
}

pub fn pool_available_tasks_reports_error_without_root_model_test() {
  let state =
    available_tasks.state(
      config(Failed(ApiError(status: 500, code: "ERR", message: "boom"))),
    )

  let assert available_tasks.Error("boom") = state
}

pub fn pool_available_tasks_keeps_only_available_tasks_test() {
  let open = task(1, "Open", 1, task_state.Available)
  let claimed =
    task(
      2,
      "Claimed",
      1,
      task_state.Claimed(
        claimed_by: 1,
        claimed_at: "2026-01-01T00:00:00Z",
        mode: task_status.Taken,
      ),
    )

  let assert available_tasks.Ready(tasks) =
    available_tasks.state(config(Loaded([open, claimed])))
  let assert [available] = tasks
  let assert 1 = available.id
}

pub fn available_tasks_all_open_includes_blocked_and_unblocked_test() {
  let ready = task(1, "Ready", 1, task_state.Available)
  let blocked =
    Task(..task(2, "Blocked", 1, task_state.Available), blocked_count: 2)

  let assert available_tasks.Ready(tasks) =
    available_tasks.state(config(Loaded([blocked, ready])))
  let assert [first, second] = tasks
  let assert 1 = first.id
  let assert 2 = second.id
}

pub fn available_tasks_ready_to_claim_excludes_blocked_test() {
  let ready = task(1, "Ready", 1, task_state.Available)
  let blocked =
    Task(..task(2, "Blocked", 1, task_state.Available), blocked_count: 1)

  let state =
    available_tasks.state(
      available_tasks.Config(
        ..config(Loaded([ready, blocked])),
        visibility: ReadyToClaim,
      ),
    )

  let assert available_tasks.Ready(tasks) = state
  let assert [only] = tasks
  let assert 1 = only.id
}

pub fn available_tasks_blocked_only_includes_only_blocked_test() {
  let ready = task(1, "Ready", 1, task_state.Available)
  let blocked =
    Task(..task(2, "Blocked", 1, task_state.Available), blocked_count: 1)

  let state =
    available_tasks.state(
      available_tasks.Config(
        ..config(Loaded([ready, blocked])),
        visibility: Blocked,
      ),
    )

  let assert available_tasks.Ready(tasks) = state
  let assert [only] = tasks
  let assert 2 = only.id
}

pub fn available_tasks_never_includes_claimed_or_closed_test() {
  let claimed =
    task(
      1,
      "Claimed",
      1,
      task_state.Claimed(
        claimed_by: 1,
        claimed_at: "2026-01-01T00:00:00Z",
        mode: task_status.Taken,
      ),
    )
  let done =
    task(2, "Done", 1, task_state.Done(completed_at: "2026-01-02T00:00:00Z"))

  let state =
    available_tasks.state(
      available_tasks.Config(
        ..config(Loaded([claimed, done])),
        visibility: AllOpen,
      ),
    )

  let assert available_tasks.Empty(has_filters: False) = state
}

pub fn pool_available_tasks_marks_empty_with_active_filters_test() {
  let state =
    available_tasks.state(
      available_tasks.Config(
        ..config(Loaded([task(1, "Backend", 1, task_state.Available)])),
        search_query: "frontend",
      ),
    )

  let assert available_tasks.Empty(has_filters: True) = state
}

pub fn pool_available_tasks_filters_by_my_capabilities_test() {
  let matching = task(1, "Mine", 1, task_state.Available)
  let other = task(2, "Other", 2, task_state.Available)

  let state =
    available_tasks.state(
      available_tasks.Config(
        ..config(Loaded([matching, other])),
        task_types: Loaded([
          task_type(1, Some(10)),
          task_type(2, Some(20)),
        ]),
        my_capability_ids: Loaded([10]),
        capability_scope: MyCapabilities,
      ),
    )

  let assert available_tasks.Ready(tasks) = state
  let assert [available] = tasks
  let assert 1 = available.id
}

pub fn available_tasks_filters_type_capability_search_and_my_capabilities_test() {
  let matching = task(1, "Backend parser", 1, task_state.Available)
  let other_type = task(2, "Backend UI", 2, task_state.Available)
  let other_query = task(3, "Frontend parser", 1, task_state.Available)

  let state =
    available_tasks.state(
      available_tasks.Config(
        ..config(Loaded([matching, other_type, other_query])),
        task_types: Loaded([
          task_type(1, Some(10)),
          task_type(2, Some(20)),
        ]),
        my_capability_ids: Loaded([10]),
        type_filter: Some(1),
        capability_filter: Some(10),
        search_query: "backend",
        capability_scope: MyCapabilities,
      ),
    )

  let assert available_tasks.Ready(tasks) = state
  let assert [only] = tasks
  let assert 1 = only.id
}

pub fn pool_available_tasks_matches_work_filters_without_root_model_test() {
  let task = task(1, "Backend work", 1, task_state.Available)

  let matching =
    available_tasks.matches_work_filters(
      available_tasks.Config(..config(Loaded([task])), search_query: "backend"),
      task,
    )
  let non_matching =
    available_tasks.matches_work_filters(
      available_tasks.Config(..config(Loaded([task])), type_filter: Some(99)),
      task,
    )

  let assert True = matching
  let assert False = non_matching
}
