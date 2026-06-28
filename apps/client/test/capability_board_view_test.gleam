import domain/api_error.{ApiError}
import domain/card.{type Card, Active, Card}
import domain/org.{OrgUser}
import domain/org_role.{Admin}
import domain/remote
import domain/task.{type Task, Task}
import domain/task/state as task_state
import domain/task_type.{type TaskType, TaskType, TaskTypeInline}
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/element
import support/assertions.{assert_true}
import support/domain_fixtures
import support/render_assertions

import scrumbringer_client/capability_scope
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/capability_board/task_preview_state
import scrumbringer_client/features/capability_board/view as capability_board
import scrumbringer_client/features/hierarchy/scope_view
import scrumbringer_client/i18n/locale
import scrumbringer_client/theme

fn base_config(tasks: remote.Remote(List(Task))) -> capability_board.Config(Int) {
  capability_board.Config(
    locale: locale.En,
    theme: theme.Default,
    tasks: tasks,
    task_types: remote.Loaded([
      board_task_type(1, "Bug", "bug-ant", Some(2)),
      board_task_type(2, "Feature", "sparkles", Some(1)),
      board_task_type(3, "Docs", "document-text", None),
    ]),
    capabilities: remote.Loaded([
      domain_fixtures.capability(1, "Backend"),
      domain_fixtures.capability(2, "Frontend"),
    ]),
    cards: base_cards(),
    org_users: [
      OrgUser(
        ..domain_fixtures.org_user(1, "admin@example.com"),
        org_role: Admin,
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
    expanded_task_previews: task_preview_state.new(),
    on_scope_kind_change: fn(_) { 0 },
    on_scope_depth_change: fn(_) { 0 },
    on_scope_card_change: fn(_) { 0 },
    on_scope_card_search_change: fn(_) { 0 },
    on_closed_toggled: fn(_) { 0 },
    on_capability_mode_change: fn(_) { 0 },
    on_task_preview_toggle: fn(_) { 0 },
  )
}

fn board_task_type(
  id: Int,
  name: String,
  icon: String,
  capability_id: Option(Int),
) -> TaskType {
  TaskType(
    ..domain_fixtures.task_type(id, name),
    icon: icon,
    capability_id: capability_id,
    tasks_count: 1,
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
    ..domain_fixtures.card(id, 1, title),
    parent_card_id: parent_card_id,
    color: Some(card.Blue),
    state: Active,
    task_count: 3,
  )
}

fn task_with(
  id: Int,
  title: String,
  type_id: Int,
  state: task_state.TaskExecutionState,
  card_id: Int,
) -> Task {
  let icon = case type_id {
    1 -> "bug-ant"
    2 -> "sparkles"
    _ -> "document-text"
  }

  Task(
    ..domain_fixtures.task(id, title, type_id),
    task_type: TaskTypeInline(id: type_id, name: "Type", icon: icon),
    description: Some(title <> " description"),
    state: state,
    card_id: Some(card_id),
    card_title: Some("Sprint"),
    card_color: Some(card.Blue),
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
      mode: task_state.Ongoing,
    )

  task_with(id, title, type_id, state, card_id)
}

fn closed_done_task(id: Int, title: String, type_id: Int, card_id: Int) -> Task {
  let state =
    task_state.Closed(task_state.ClosedByClaimant, "2026-01-01T00:00:00Z", 7)
  task_with(id, title, type_id, state, card_id)
}

pub fn capability_board_list_groups_tasks_by_capability_and_card_test() {
  let html =
    base_config(
      remote.Loaded([
        available_task(1, "Frontend polish", 1, 1),
        claimed_task(2, "Backend API", 2, 2),
        available_task(3, "Docs refresh", 3, 2),
        closed_done_task(4, "Closed task", 1, 1),
      ]),
    )
    |> capability_board.view
    |> element.to_document_string

  render_assertions.contains(html, "data-testid=\"plan-scope-bar\"")
  render_assertions.contains(html, "data-testid=\"capability-mode-list\"")
  render_assertions.contains(html, "data-testid=\"capability-mode-matrix\"")
  render_assertions.contains(html, "data-testid=\"work-filter-type\"")
  render_assertions.contains(html, "data-testid=\"work-filter-capability\"")
  render_assertions.contains(html, "data-testid=\"work-filter-search\"")
  render_assertions.contains(
    html,
    "data-testid=\"work-filter-capability-scope\"",
  )
  render_assertions.not_contains(html, "data-testid=\"capabilities-toolbar\"")
  render_assertions.not_contains(html, "data-testid=\"filter-type\"")
  render_assertions.not_contains(html, "data-testid=\"filter-capability\"")
  render_assertions.not_contains(html, ">Lens<")
  render_assertions.contains(html, "data-testid=\"capability-list\"")
  render_assertions.contains(html, "Backend")
  render_assertions.contains(html, "Frontend")
  render_assertions.contains(html, "No capability")
  render_assertions.contains(html, "Sprint")
  render_assertions.contains(html, "Frontend polish")
  render_assertions.contains(html, "Backend API")
  render_assertions.contains(html, "Docs refresh")
  render_assertions.not_contains(html, "Closed task")
  render_assertions.contains(html, "task-claim-btn")
  render_assertions.contains(html, "Claimed by admin@example.com")
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

  render_assertions.contains(html, "data-testid=\"capability-matrix\"")
  render_assertions.contains(
    html,
    "data-testid=\"capability-matrix-empty-cell\"",
  )
  render_assertions.contains(html, "grid-template-columns")
  render_assertions.contains(html, "repeat(2, minmax(112px, 1fr))")
  render_assertions.contains(html, "data-testid=\"task-metric-breakdown\"")
  render_assertions.contains(html, "data-testid=\"task-metric-available\"")
  render_assertions.contains(html, "data-testid=\"task-metric-ongoing\"")
  render_assertions.not_contains(html, ">claim<")
  render_assertions.not_contains(html, "auto-fit")
  render_assertions.contains(html, ">Level<")
  render_assertions.contains(html, ">Total<")
  render_assertions.not_contains(html, "chevron")
  render_assertions.not_contains(html, "expand-icon")
}

pub fn capability_board_list_marks_hidden_preview_tasks_test() {
  let html =
    base_config(
      remote.Loaded([
        available_task(1, "Task one", 1, 1),
        available_task(2, "Task two", 1, 1),
        available_task(3, "Task three", 1, 1),
        available_task(4, "Task four", 1, 1),
      ]),
    )
    |> capability_board.view
    |> element.to_document_string

  render_assertions.contains(html, "Task one")
  render_assertions.contains(html, "Task two")
  render_assertions.contains(html, "Task three")
  render_assertions.not_contains(html, "Task four")
  render_assertions.not_contains(html, "<details")
  render_assertions.not_contains(html, "<summary")
  render_assertions.contains(html, "data-testid=\"capability-list-more\"")
  render_assertions.contains(html, "data-testid=\"capability-list-more-link\"")
  render_assertions.contains(html, "aria-expanded=\"false\"")
  render_assertions.contains(html, "+1 more task")
}

pub fn capability_board_list_expands_hidden_preview_tasks_below_link_test() {
  let html =
    capability_board.Config(
      ..base_config(
        remote.Loaded([
          available_task(1, "Task one", 1, 1),
          available_task(2, "Task two", 1, 1),
          available_task(3, "Task three", 1, 1),
          available_task(4, "Task four", 1, 1),
        ]),
      ),
      expanded_task_previews: task_preview_state.from_list([
        #("1-capability-2", True),
      ]),
    )
    |> capability_board.view
    |> element.to_document_string

  render_assertions.contains(html, "Task four")
  render_assertions.contains(html, "aria-expanded=\"true\"")
  render_assertions.contains(html, "Show fewer")
  assert_true(string.contains(html, "Task four</span>"))
  let assert Ok(before_toggle) = string.split_once(html, "Task four")
  let assert True = string.contains(before_toggle.1, "Show fewer")
}

pub fn capability_board_more_tasks_link_counts_multiple_hidden_tasks_test() {
  let html =
    base_config(
      remote.Loaded([
        available_task(1, "Task one", 1, 1),
        available_task(2, "Task two", 1, 1),
        available_task(3, "Task three", 1, 1),
        available_task(4, "Task four", 1, 1),
        available_task(5, "Task five", 1, 1),
      ]),
    )
    |> capability_board.view
    |> element.to_document_string

  render_assertions.contains(html, "+2 more tasks")
  render_assertions.not_contains(html, "Task four")
  render_assertions.not_contains(html, "Task five")
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

  render_assertions.contains(html, "data-testid=\"plan-scope-card-search\"")
  render_assertions.not_contains(html, "data-testid=\"plan-scope-card\"")
  render_assertions.contains(html, ">Card<")
  render_assertions.contains(html, "Checkout")
}

pub fn capability_board_show_closed_includes_closed_tasks_test() {
  let html =
    capability_board.Config(
      ..base_config(
        remote.Loaded([
          available_task(1, "Frontend polish", 1, 1),
          closed_done_task(2, "Closed task", 1, 1),
        ]),
      ),
      show_closed: Some(True),
    )
    |> capability_board.view
    |> element.to_document_string

  render_assertions.contains(html, "Closed task")
  render_assertions.contains(html, "closed")
  render_assertions.not_contains(html, "complete")
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

  render_assertions.contains(html, "Backend API")
  render_assertions.not_contains(html, "Frontend polish")
  render_assertions.not_contains(html, "Docs refresh")
  render_assertions.not_contains(html, "No capability")
}

pub fn capability_board_shows_no_results_after_filters_test() {
  let html =
    capability_board.Config(
      ..base_config(remote.Loaded([available_task(1, "Frontend polish", 1, 1)])),
      search_query: "missing",
    )
    |> capability_board.view
    |> element.to_document_string

  render_assertions.contains(
    html,
    "No active tasks grouped by capability match the current filters",
  )
}

pub fn capability_board_shows_loading_state_test() {
  let html =
    base_config(remote.Loading)
    |> capability_board.view
    |> element.to_document_string

  render_assertions.contains(html, "Loading capabilities...")
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
