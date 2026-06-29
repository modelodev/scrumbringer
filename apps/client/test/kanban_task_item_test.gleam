import domain/capability.{Capability}
import domain/card.{Active, Card, Closed}
import domain/org.{OrgUser}
import domain/org_role.{Admin}
import domain/task.{type Task, Task}
import domain/task/state as task_state
import domain/task_type.{TaskType}
import gleam/list
import gleam/option.{None, Some}
import support/domain_fixtures
import support/render_assertions

import scrumbringer_client/capability_scope
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/hierarchy/scope_view
import scrumbringer_client/features/views/kanban_board
import scrumbringer_client/i18n/locale as i18n_locale
import scrumbringer_client/theme

fn base_config(tasks: List(Task)) -> kanban_board.KanbanConfig(Int) {
  let card =
    Card(
      ..domain_fixtures.card(1, 1, "Sprint"),
      color: Some(card.Blue),
      state: Active,
      task_count: list.length(tasks),
    )

  kanban_board.KanbanConfig(
    locale: i18n_locale.En,
    theme: theme.Default,
    surface_title: "Kanban",
    surface_purpose: "Card flow by state",
    purpose: kanban_board.ExecutionKanban,
    cards: [card],
    tasks: tasks,
    task_types: [
      TaskType(
        id: 1,
        name: "Bug",
        icon: "bug-ant",
        capability_id: Some(2),
        tasks_count: list.length(tasks),
      ),
    ],
    capabilities: [Capability(id: 2, name: "Backend")],
    type_filter: None,
    capability_filter: None,
    search_query: "",
    capability_scope: capability_scope.AllCapabilities,
    my_capability_ids: [],
    org_users: [
      OrgUser(
        id: 1,
        email: "admin@example.com",
        org_role: Admin,
        created_at: "2026-01-01T00:00:00Z",
      ),
    ],
    is_pm_or_admin: False,
    on_card_click: fn(id) { id },
    on_card_edit: fn(id) { id },
    on_card_delete: fn(id) { id },
    on_task_click: fn(id) { id },
    on_task_claim: fn(a, b) { a + b },
    on_create_task_in_card: fn(id) { id },
    depth_names: [scope_view.DepthName(1, "Epic", "Epics")],
    scope_kind: member_pool.PlanScopeLevel,
    selected_depth: None,
    selected_card_id: None,
    card_query: "",
    show_closed: None,
    plan_mode: member_pool.PlanKanban,
    on_plan_mode_change: fn(_value) { 0 },
    on_scope_kind_change: fn(_value) { 0 },
    on_scope_depth_change: fn(_value) { 0 },
    on_scope_card_change: fn(_value) { 0 },
    on_scope_card_search_change: fn(_value) { 0 },
    on_closed_toggled: fn(_value) { 0 },
    on_capability_scope_change: fn(_value) { 0 },
    on_type_filter_change: fn(_value) { 0 },
    on_capability_filter_change: fn(_value) { 0 },
    on_search_change: fn(_value) { 0 },
  )
}

fn claimed_task() -> Task {
  let state =
    task_state.Claimed(
      claimed_by: 1,
      claimed_at: "2026-01-01T00:00:00Z",
      mode: task_state.Ongoing,
    )

  Task(
    ..domain_fixtures.task(1, "Fix login", 1),
    state: state,
    card_id: Some(1),
    card_title: Some("Sprint"),
    card_color: Some(card.Blue),
  )
}

fn available_task() -> Task {
  Task(
    ..domain_fixtures.task(2, "Review copy", 1),
    priority: 2,
    card_id: Some(1),
    card_title: Some("Sprint"),
    card_color: Some(card.Blue),
  )
}

fn claimed_taken_task() -> Task {
  let state =
    task_state.Claimed(
      claimed_by: 1,
      claimed_at: "2026-01-02T00:00:00Z",
      mode: task_state.Taken,
    )

  Task(
    ..available_task(),
    id: 3,
    title: "Prepare rollout",
    state: state,
    priority: 4,
  )
}

fn blocked_task() -> Task {
  Task(
    ..available_task(),
    id: 4,
    title: "Blocked dependency",
    blocked_count: 1,
    priority: 5,
  )
}

fn closed_done_task() -> Task {
  let state =
    task_state.Closed(task_state.ClosedByClaimant, "2026-01-03T00:00:00Z", 7)

  Task(..available_task(), id: 5, title: "Closed task", state: state)
}

pub fn kanban_task_item_renders_claimed_by_and_icon_test() {
  let html =
    base_config([claimed_task()])
    |> kanban_board.view
    |> render_assertions.html

  render_assertions.contains(html, "kanban-task-item")
  render_assertions.contains(html, "task-claimed-by")
  render_assertions.contains(html, "task-type-icon")
  render_assertions.contains(html, "admin")
}

pub fn kanban_task_item_renders_claim_button_for_available_test() {
  let html =
    base_config([available_task()])
    |> kanban_board.view
    |> render_assertions.html

  render_assertions.contains(html, "btn-claim-mini")
}

pub fn kanban_card_shows_notes_indicator_test() {
  let config = base_config([available_task()])
  let card = case config.cards {
    [first, ..] -> card.Card(..first, has_new_notes: True)
    [] -> panic
  }

  let html =
    kanban_board.KanbanConfig(..config, cards: [card])
    |> kanban_board.view
    |> render_assertions.html

  render_assertions.contains(html, "card-notes-indicator")
}

pub fn kanban_in_progress_card_with_tasks_disables_delete_test() {
  let config = base_config([available_task()])
  let card = case config.cards {
    [first, ..] -> card.Card(..first, state: Active)
    [] -> panic
  }

  let html =
    kanban_board.KanbanConfig(..config, cards: [card], is_pm_or_admin: True)
    |> kanban_board.view
    |> render_assertions.html

  render_assertions.contains(html, "data-testid=\"kanban-card-delete-action\"")
  render_assertions.contains(html, "btn-delete-blocked")
  render_assertions.contains(html, "title=\"Cannot delete: has tasks\"")
  render_assertions.contains(html, "data-tooltip=\"Cannot delete: has tasks\"")
  render_assertions.contains(html, "aria-disabled=\"true\"")
}

pub fn kanban_scope_mine_filters_out_tasks_outside_my_capabilities_test() {
  let html =
    kanban_board.KanbanConfig(
      ..base_config([available_task()]),
      capability_scope: capability_scope.MyCapabilities,
      my_capability_ids: [1],
    )
    |> kanban_board.view
    |> render_assertions.html

  render_assertions.not_contains(html, "Review copy")
  render_assertions.contains(
    html,
    "data-testid=\"work-filter-capability-scope\"",
  )
  render_assertions.contains(
    html,
    "data-testid=\"work-filter-capability-scope-mine\"",
  )
  render_assertions.contains(html, "aria-pressed=\"true\"")
}

pub fn kanban_surface_header_summarizes_operational_health_test() {
  let html =
    base_config([
      available_task(),
      claimed_taken_task(),
      claimed_task(),
      blocked_task(),
    ])
    |> kanban_board.view
    |> render_assertions.html

  render_assertions.contains(html, "kanban-surface-header")
  render_assertions.contains(html, "Card flow by state")
  render_assertions.contains(html, "data-testid=\"plan-scope-bar\"")
  render_assertions.contains(html, "data-testid=\"plan-scope-kind\"")
  render_assertions.contains(html, "data-testid=\"plan-scope-depth\"")
  render_assertions.contains(html, "data-testid=\"plan-closed-toggle\"")
  render_assertions.contains(
    html,
    "data-testid=\"work-filter-capability-scope\"",
  )
  render_assertions.not_contains(html, ">Lens<")
  render_assertions.contains(html, "work-surface-chip")
  render_assertions.contains(html, "Cards")
  render_assertions.contains(html, "Available")
  render_assertions.contains(html, "Claimed")
  render_assertions.contains(html, "Ongoing")
  render_assertions.contains(html, "Blocked")
}

pub fn kanban_columns_are_inferred_from_descendant_task_state_test() {
  let child_card =
    Card(
      ..domain_fixtures.card(2, 1, "Child"),
      parent_card_id: Some(1),
      color: Some(card.Green),
      state: Active,
      task_count: 1,
    )
  let child_task = Task(..claimed_task(), id: 7, card_id: Some(2))

  let html =
    kanban_board.KanbanConfig(..base_config([child_task]), cards: [
      child_card,
      ..base_config([]).cards
    ])
    |> kanban_board.view
    |> render_assertions.html

  render_assertions.contains(html, "en-curso")
  render_assertions.contains(html, "Sprint")
  render_assertions.contains(html, "Child")
}

pub fn kanban_level_scope_shows_closed_cards_by_default_test() {
  let closed_card = case base_config([]).cards {
    [first, ..] -> Card(..first, id: 9, title: "Closed card", state: Closed)
    [] -> panic
  }

  let html =
    kanban_board.KanbanConfig(..base_config([]), cards: [closed_card])
    |> kanban_board.view
    |> render_assertions.html

  render_assertions.contains(html, "Closed card")
  render_assertions.contains(html, "cerrada")
  render_assertions.contains(html, "checked")
}

pub fn kanban_card_scope_with_direct_tasks_shows_closed_by_default_test() {
  let closed_card = case base_config([available_task()]).cards {
    [first, ..] -> Card(..first, state: Closed)
    [] -> panic
  }

  let html =
    kanban_board.KanbanConfig(
      ..base_config([available_task()]),
      cards: [closed_card],
      scope_kind: member_pool.PlanScopeCard,
      selected_card_id: Some(closed_card.id),
    )
    |> kanban_board.view
    |> render_assertions.html

  render_assertions.contains(html, "Closed")
  render_assertions.contains(html, "Sprint")
  render_assertions.contains(html, "data-testid=\"plan-scope-card-search\"")
  render_assertions.not_contains(html, "data-testid=\"plan-scope-card\"")
}

pub fn kanban_card_health_and_preview_prioritize_active_work_test() {
  let html =
    base_config([
      available_task(),
      claimed_taken_task(),
      claimed_task(),
      blocked_task(),
      closed_done_task(),
    ])
    |> kanban_board.view
    |> render_assertions.html

  render_assertions.contains(html, "kanban-card-task-metric-chip")
  render_assertions.contains(html, "title=\"Available: 2\"")
  render_assertions.contains(html, "title=\"Claimed: 1\"")
  render_assertions.contains(html, "title=\"Ongoing: 1\"")
  render_assertions.contains(html, "title=\"Blocked: 1\"")
  render_assertions.contains(html, "Blocked dependency")
  render_assertions.not_contains(html, "Closed task")
}

pub fn kanban_closed_only_card_still_shows_task_context_test() {
  let html =
    base_config([closed_done_task()])
    |> kanban_board.view
    |> render_assertions.html

  render_assertions.contains(html, "Closed task")
  render_assertions.not_contains(html, "No tasks yet")
}

pub fn kanban_shows_empty_draft_cards_for_decomposition_test() {
  let html =
    base_config([])
    |> kanban_board.view
    |> render_assertions.html

  render_assertions.contains(html, "Sprint")
  render_assertions.contains(html, "No tasks yet")
}
