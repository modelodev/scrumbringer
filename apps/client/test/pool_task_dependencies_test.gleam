import gleam/int
import gleam/option.{None, Some}
import gleam/string
import lustre/element

import domain/remote
import domain/task.{type Task, Task, TaskDependency}
import domain/task/state as task_state
import domain/task_status.{
  type TaskPhase, Available, Claimed, Done, Ongoing, Taken,
}
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/features/pool/task_dependencies
import scrumbringer_client/i18n/locale

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

pub fn task_dependencies_renders_loaded_dependencies_test() {
  let html =
    task_dependencies.view(config(
      dependencies: remote.Loaded([
        TaskDependency(
          depends_on_task_id: 11,
          title: "Configure API",
          status: Claimed(Taken),
          claimed_by: Some("ana@example.com"),
        ),
        TaskDependency(
          depends_on_task_id: 12,
          title: "Write docs",
          status: Done,
          claimed_by: None,
        ),
      ]),
      dialog_mode: dialog_mode.DialogClosed,
      search_query: "",
      candidates: remote.NotAsked,
      selected_task_id: None,
    ))
    |> element.to_document_string

  assert_contains(html, "Dependencies (1)")
  assert_contains(html, "Configure API")
  assert_contains(html, "Claimed by ana@example.com")
  assert_contains(html, "Write docs")
  assert_contains(html, "Done")
}

pub fn task_dependencies_renders_empty_state_test() {
  let html =
    task_dependencies.view(config(
      dependencies: remote.Loaded([]),
      dialog_mode: dialog_mode.DialogClosed,
      search_query: "",
      candidates: remote.NotAsked,
      selected_task_id: None,
    ))
    |> element.to_document_string

  assert_contains(html, "Dependencies")
  assert_contains(html, "No dependencies")
  assert_contains(html, "Add dependency")
}

pub fn task_dependencies_dialog_filters_candidates_test() {
  let html =
    task_dependencies.view(config(
      dependencies: remote.Loaded([]),
      dialog_mode: dialog_mode.DialogCreate,
      search_query: "api",
      candidates: remote.Loaded([
        sample_task(10, "Current task", Available),
        sample_task(11, "Finished API", Done),
        sample_task(12, "API client", Available),
        sample_task(13, "Other task", Available),
      ]),
      selected_task_id: Some(12),
    ))
    |> element.to_document_string

  assert_contains(html, "This task depends on")
  assert_contains(html, "API client")
  assert_contains(html, "dependency-candidate selected")
  assert_contains(html, "type=\"submit\"")
  assert_contains(html, "form=\"task-dependency-form\"")
  assert_not_contains(html, "Current task")
  assert_not_contains(html, "Finished API")
  assert_not_contains(html, "Other task")
}

pub fn task_dependencies_dialog_renders_loading_submit_state_test() {
  let html =
    task_dependencies.view(
      task_dependencies.Config(
        ..config(
          dependencies: remote.Loaded([]),
          dialog_mode: dialog_mode.DialogCreate,
          search_query: "api",
          candidates: remote.Loaded([sample_task(12, "API client", Available)]),
          selected_task_id: Some(12),
        ),
        add_in_flight: True,
      ),
    )
    |> element.to_document_string

  assert_contains(html, "btn-loading")
  assert_contains(html, "Adding")
  assert_contains(html, "disabled")
}

fn config(
  dependencies dependencies,
  dialog_mode dialog_mode,
  search_query search_query,
  candidates candidates,
  selected_task_id selected_task_id,
) -> task_dependencies.Config(String) {
  task_dependencies.Config(
    locale: locale.En,
    task_id: 10,
    task: Some(sample_task(10, "Current task", Available)),
    dependencies: dependencies,
    dialog_mode: dialog_mode,
    search_query: search_query,
    candidates: candidates,
    selected_task_id: selected_task_id,
    add_in_flight: False,
    add_error: None,
    remove_in_flight: None,
    on_dialog_opened: "open",
    on_dialog_closed: "close",
    on_add_submitted: "submit",
    on_search_changed: fn(value) { "search-" <> value },
    on_selected: fn(id) { "select-" <> int.to_string(id) },
    on_remove: fn(id) { "remove-" <> int.to_string(id) },
  )
}

fn sample_task(id: Int, title: String, status: TaskPhase) -> Task {
  let state = case status {
    Available -> task_state.Available
    Claimed(mode) ->
      task_state.Claimed(
        claimed_by: 1,
        claimed_at: "2026-06-08T00:00:00Z",
        mode: claim_mode(mode),
      )
    Done -> task_state.Closed(task_state.Done, "2026-06-08T00:00:00Z", 7)
  }
  Task(
    id: id,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Task", icon: "check"),
    ongoing_by: None,
    title: title,
    description: None,
    priority: 1,
    state: state,
    created_by: 1,
    created_at: "2026-06-08T00:00:00Z",
    due_date: None,
    version: 1,
    parent_card_id: None,
    card_id: None,
    card_title: None,
    card_color: None,
    has_new_notes: False,
    blocked_count: 0,
    dependencies: [],
    automation_origin: None,
  )
}

fn claim_mode(mode: task_status.ClaimedState) -> task_state.TaskClaimMode {
  case mode {
    Taken -> task_state.Taken
    Ongoing -> task_state.Ongoing
  }
}
