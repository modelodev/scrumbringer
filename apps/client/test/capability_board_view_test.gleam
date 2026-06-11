import domain/api_error.{ApiError}
import domain/capability.{Capability}
import domain/card.{Card, EnCurso}
import domain/org.{OrgUser}
import domain/org_role.{Admin}
import domain/remote
import domain/task.{type Task, Task}
import domain/task_state
import domain/task_status
import domain/task_type.{TaskType, TaskTypeInline}
import gleam/option.{None, Some}
import gleam/string
import lustre/element

import scrumbringer_client/capability_scope
import scrumbringer_client/features/capability_board/view as capability_board
import scrumbringer_client/i18n/locale
import scrumbringer_client/theme

fn assert_contains(text: String, fragment: String) {
  let assert True = string.contains(text, fragment)
}

fn assert_not_contains(text: String, fragment: String) {
  let assert False = string.contains(text, fragment)
}

fn assert_true(value: Bool) {
  let assert True = value
}

fn base_config(tasks: remote.Remote(List(Task))) -> capability_board.Config(Int) {
  capability_board.Config(
    locale: locale.En,
    theme: theme.Default,
    tasks: tasks,
    task_types: remote.Loaded([
      TaskType(
        id: 1,
        name: "Bug",
        icon: "bug-ant",
        capability_id: Some(2),
        tasks_count: 1,
      ),
      TaskType(
        id: 2,
        name: "Feature",
        icon: "sparkles",
        capability_id: Some(1),
        tasks_count: 1,
      ),
      TaskType(
        id: 3,
        name: "Docs",
        icon: "document-text",
        capability_id: None,
        tasks_count: 1,
      ),
    ]),
    capabilities: remote.Loaded([
      Capability(id: 1, name: "Backend"),
      Capability(id: 2, name: "Frontend"),
    ]),
    cards: [
      Card(
        id: 1,
        project_id: 1,
        milestone_id: None,
        title: "Sprint",
        description: "",
        color: Some(card.Blue),
        state: EnCurso,
        task_count: 3,
        completed_count: 0,
        created_by: 1,
        created_at: "2026-01-01T00:00:00Z",
        has_new_notes: False,
      ),
    ],
    org_users: [
      OrgUser(
        id: 1,
        email: "admin@example.com",
        org_role: Admin,
        created_at: "2026-01-01T00:00:00Z",
      ),
    ],
    capability_scope: capability_scope.AllCapabilities,
    my_capability_ids: [1],
    type_filter: None,
    search_query: "",
    on_task_click: fn(id) { id },
    on_task_claim: fn(id, version) { id + version },
  )
}

fn task_with(
  id: Int,
  title: String,
  type_id: Int,
  state: task_state.TaskState,
) -> Task {
  let icon = case type_id {
    1 -> "bug-ant"
    2 -> "sparkles"
    _ -> "document-text"
  }

  Task(
    id: id,
    project_id: 1,
    type_id: type_id,
    task_type: TaskTypeInline(id: type_id, name: "Type", icon: icon),
    ongoing_by: None,
    title: title,
    description: Some(title <> " description"),
    priority: 3,
    state: state,
    status: task_state.to_status(state),
    work_state: task_state.to_work_state(state),
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    version: 1,
    milestone_id: None,
    card_id: Some(1),
    card_title: Some("Sprint"),
    card_color: Some(card.Blue),
    has_new_notes: False,
    blocked_count: 0,
    dependencies: [],
  )
}

fn available_task(id: Int, title: String, type_id: Int) -> Task {
  task_with(id, title, type_id, task_state.Available)
}

fn claimed_task(id: Int, title: String, type_id: Int) -> Task {
  let state =
    task_state.Claimed(
      claimed_by: 1,
      claimed_at: "2026-01-01T00:00:00Z",
      mode: task_status.Ongoing,
    )

  task_with(id, title, type_id, state)
}

fn taken_task(id: Int, title: String, type_id: Int) -> Task {
  let state =
    task_state.Claimed(
      claimed_by: 1,
      claimed_at: "2026-01-01T00:00:00Z",
      mode: task_status.Taken,
    )

  task_with(id, title, type_id, state)
}

fn completed_task(id: Int, title: String, type_id: Int) -> Task {
  let state = task_state.Completed(completed_at: "2026-01-01T00:00:00Z")
  task_with(id, title, type_id, state)
}

fn appears_before(html: String, first: String, second: String) -> Bool {
  case string.split_once(html, first) {
    Ok(#(_, after_first)) -> string.contains(after_first, second)
    Error(_) -> False
  }
}

pub fn capability_board_groups_active_tasks_into_three_columns_test() {
  let html =
    base_config(
      remote.Loaded([
        available_task(1, "Frontend polish", 1),
        taken_task(2, "Frontend takeover", 1),
        claimed_task(3, "Backend API", 2),
        available_task(4, "Docs refresh", 3),
        completed_task(5, "Completed task", 1),
      ]),
    )
    |> capability_board.view
    |> element.to_document_string

  assert_contains(html, "Backend")
  assert_contains(html, "Frontend")
  assert_contains(html, "No capability")
  assert_true(appears_before(html, ">Backend<", ">Frontend<"))
  assert_true(appears_before(html, ">Frontend<", ">No capability<"))
  assert_contains(html, "data-column-state=\"pending\"")
  assert_contains(html, "data-column-state=\"claimed\"")
  assert_contains(html, "data-column-state=\"ongoing\"")
  assert_contains(html, ">Pending<")
  assert_contains(html, ">Claimed<")
  assert_contains(html, ">Working now<")
  assert_contains(html, "Frontend polish")
  assert_contains(html, "Frontend takeover")
  assert_contains(html, "Backend API")
  assert_contains(html, "Docs refresh")
  assert_not_contains(html, "Completed task")
  assert_contains(html, "task-item card-border-blue")
  assert_contains(html, "task-claim-btn")
  assert_contains(html, "Claimed by admin@example.com")
}

pub fn capability_board_keeps_empty_columns_visible_test() {
  let html =
    base_config(remote.Loaded([available_task(1, "Frontend polish", 1)]))
    |> capability_board.view
    |> element.to_document_string

  assert_contains(html, "No claimed tasks")
  assert_contains(html, "No ongoing tasks")
}

pub fn capability_board_scope_mine_filters_to_my_capabilities_test() {
  let html =
    capability_board.Config(
      ..base_config(
        remote.Loaded([
          available_task(1, "Frontend polish", 1),
          claimed_task(2, "Backend API", 2),
          available_task(3, "Docs refresh", 3),
        ]),
      ),
      capability_scope: capability_scope.MyCapabilities,
    )
    |> capability_board.view
    |> element.to_document_string

  assert_contains(html, "Backend API")
  assert_not_contains(html, "Frontend polish")
  assert_not_contains(html, "Docs refresh")
  assert_not_contains(html, "No capability")
}

pub fn capability_board_shows_no_results_after_filters_test() {
  let html =
    capability_board.Config(
      ..base_config(remote.Loaded([available_task(1, "Frontend polish", 1)])),
      search_query: "missing",
    )
    |> capability_board.view
    |> element.to_document_string

  string.contains(
    html,
    "No active tasks grouped by capability match the current filters",
  )
  |> assert_true
}

pub fn capability_board_shows_loading_state_test() {
  let html =
    base_config(remote.Loading)
    |> capability_board.view
    |> element.to_document_string

  assert_contains(html, "Loading capabilities...")
}

pub fn capability_board_shows_error_state_test() {
  let html =
    base_config(
      remote.Failed(ApiError(
        status: 500,
        code: "boom",
        message: "server exploded",
      )),
    )
    |> capability_board.view
    |> element.to_document_string

  string.contains(html, "Could not load the capability board: server exploded")
  |> assert_true
}
