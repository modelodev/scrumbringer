import domain/api_error.{ApiError}
import domain/capability.{Capability}
import domain/card.{type Card, Active, Card}
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
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/capability_board/view as capability_board
import scrumbringer_client/features/hierarchy/scope_view
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
    cards: base_cards(),
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
    capability_filter: None,
    search_query: "",
    on_capability_scope_change: fn(_) { 0 },
    on_type_filter_change: fn(_) { 0 },
    on_capability_filter_change: fn(_) { 0 },
    on_search_change: fn(_) { 0 },
    on_task_click: fn(id) { id },
    on_task_claim: fn(id, version) { id + version },
    depth_names: [
      scope_view.DepthName(1, "Initiative", "Initiatives"),
      scope_view.DepthName(2, "Feature", "Features"),
    ],
    scope_kind: member_pool.PlanScopeLevel,
    capability_mode: member_pool.PlanCapabilityList,
    selected_depth: Some(1),
    selected_card_id: None,
    card_query: "",
    show_closed: None,
    on_scope_kind_change: fn(_) { 0 },
    on_scope_depth_change: fn(_) { 0 },
    on_scope_card_change: fn(_) { 0 },
    on_scope_card_search_change: fn(_) { 0 },
    on_closed_toggled: fn(_) { 0 },
    on_capability_mode_change: fn(_) { 0 },
  )
}

fn base_cards() -> List(Card) {
  [
    card_with(1, "Sprint", None),
    card_with(2, "Checkout", Some(1)),
    card_with(3, "Empty feature", Some(1)),
  ]
}

fn card_with(id: Int, title: String, parent_card_id) -> Card {
  Card(
    id: id,
    project_id: 1,
    parent_card_id: parent_card_id,
    title: title,
    description: "",
    color: Some(card.Blue),
    state: Active,
    task_count: 3,
    completed_count: 0,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    due_date: None,
    has_new_notes: False,
  )
}

fn task_with(
  id: Int,
  title: String,
  type_id: Int,
  state: task_state.TaskState,
  card_id: Int,
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
    due_date: None,
    version: 1,
    parent_card_id: None,
    card_id: Some(card_id),
    card_title: Some("Sprint"),
    card_color: Some(card.Blue),
    has_new_notes: False,
    blocked_count: 0,
    dependencies: [],
  )
}

fn available_task(id: Int, title: String, type_id: Int, card_id: Int) -> Task {
  task_with(id, title, type_id, task_state.Available, card_id)
}

fn claimed_task(id: Int, title: String, type_id: Int, card_id: Int) -> Task {
  let state =
    task_state.Claimed(
      claimed_by: 1,
      claimed_at: "2026-01-01T00:00:00Z",
      mode: task_status.Ongoing,
    )

  task_with(id, title, type_id, state, card_id)
}

fn completed_task(id: Int, title: String, type_id: Int, card_id: Int) -> Task {
  let state = task_state.Done(completed_at: "2026-01-01T00:00:00Z")
  task_with(id, title, type_id, state, card_id)
}

pub fn capability_board_list_groups_tasks_by_capability_and_card_test() {
  let html =
    base_config(
      remote.Loaded([
        available_task(1, "Frontend polish", 1, 1),
        claimed_task(2, "Backend API", 2, 2),
        available_task(3, "Docs refresh", 3, 2),
        completed_task(4, "Done task", 1, 1),
      ]),
    )
    |> capability_board.view
    |> element.to_document_string

  assert_contains(html, "data-testid=\"plan-scope-bar\"")
  assert_contains(html, "data-testid=\"capability-mode-list\"")
  assert_contains(html, "data-testid=\"capability-mode-matrix\"")
  assert_contains(html, "data-testid=\"capability-my-capabilities-action\"")
  assert_contains(html, "data-testid=\"capability-filter-type\"")
  assert_contains(html, "data-testid=\"capability-filter-capability\"")
  assert_contains(html, "data-testid=\"capability-filter-search\"")
  assert_not_contains(html, "data-testid=\"capabilities-toolbar\"")
  assert_not_contains(html, "data-testid=\"filter-type\"")
  assert_not_contains(html, "data-testid=\"filter-capability\"")
  assert_not_contains(html, ">Lens<")
  assert_contains(html, "data-testid=\"capability-list\"")
  assert_contains(html, "Backend")
  assert_contains(html, "Frontend")
  assert_contains(html, "No capability")
  assert_contains(html, "Sprint")
  assert_contains(html, "Frontend polish")
  assert_contains(html, "Backend API")
  assert_contains(html, "Docs refresh")
  assert_not_contains(html, "Done task")
  assert_contains(html, "task-claim-btn")
  assert_contains(html, "Claimed by admin@example.com")
}

pub fn capability_board_matrix_is_read_only_and_hides_empty_affordances_test() {
  let html =
    capability_board.Config(
      ..base_config(
        remote.Loaded([
          claimed_task(2, "Backend API", 2, 2),
          available_task(3, "Frontend polish", 1, 3),
        ]),
      ),
      capability_mode: member_pool.PlanCapabilityMatrix,
      selected_depth: Some(2),
    )
    |> capability_board.view
    |> element.to_document_string

  assert_contains(html, "data-testid=\"capability-matrix\"")
  assert_contains(html, "data-testid=\"capability-matrix-empty-cell\"")
  assert_contains(html, ">Level<")
  assert_contains(html, ">Total<")
  assert_not_contains(html, "chevron")
  assert_not_contains(html, "expand-icon")
}

pub fn capability_board_card_scope_rows_direct_children_test() {
  let html =
    capability_board.Config(
      ..base_config(
        remote.Loaded([
          available_task(1, "Frontend polish", 1, 1),
          claimed_task(2, "Backend API", 2, 2),
        ]),
      ),
      scope_kind: member_pool.PlanScopeCard,
      selected_card_id: Some(1),
      selected_depth: None,
      capability_mode: member_pool.PlanCapabilityMatrix,
    )
    |> capability_board.view
    |> element.to_document_string

  assert_contains(html, "data-testid=\"plan-scope-card-search\"")
  assert_not_contains(html, "data-testid=\"plan-scope-card\"")
  assert_contains(html, ">Card<")
  assert_contains(html, "Checkout")
}

pub fn capability_board_show_closed_includes_completed_tasks_test() {
  let html =
    capability_board.Config(
      ..base_config(
        remote.Loaded([
          available_task(1, "Frontend polish", 1, 1),
          completed_task(2, "Done task", 1, 1),
        ]),
      ),
      show_closed: Some(True),
    )
    |> capability_board.view
    |> element.to_document_string

  assert_contains(html, "Done task")
  assert_contains(html, "complete")
}

pub fn capability_board_scope_mine_filters_to_my_capabilities_test() {
  let html =
    capability_board.Config(
      ..base_config(
        remote.Loaded([
          available_task(1, "Frontend polish", 1, 1),
          claimed_task(2, "Backend API", 2, 1),
          available_task(3, "Docs refresh", 3, 1),
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
      ..base_config(remote.Loaded([available_task(1, "Frontend polish", 1, 1)])),
      search_query: "missing",
    )
    |> capability_board.view
    |> element.to_document_string

  assert_contains(
    html,
    "No active tasks grouped by capability match the current filters",
  )
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

  assert_true(string.contains(
    html,
    "Could not load the capability board: server exploded",
  ))
}
