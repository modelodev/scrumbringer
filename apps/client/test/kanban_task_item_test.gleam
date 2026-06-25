import domain/card.{Active, Card, Closed}
import domain/org.{OrgUser}
import domain/org_role.{Admin}
import domain/task.{type Task, Task}
import domain/task/state as task_state
import domain/task_type.{TaskType, TaskTypeInline}
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import lustre/element

import scrumbringer_client/capability_scope
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/hierarchy/scope_view
import scrumbringer_client/features/views/kanban_board
import scrumbringer_client/i18n/locale as i18n_locale
import scrumbringer_client/theme

fn assert_contains(text: String, fragment: String) {
  let assert True = string.contains(text, fragment)
}

fn assert_not_contains(text: String, fragment: String) {
  let assert False = string.contains(text, fragment)
}

fn base_config(tasks: List(Task)) -> kanban_board.KanbanConfig(Int) {
  let card =
    Card(
      id: 1,
      project_id: 1,
      parent_card_id: None,
      title: "Sprint",
      description: "",
      color: Some(card.Blue),
      state: Active,
      task_count: list.length(tasks),
      completed_count: 0,
      created_by: 1,
      created_at: "2026-01-01T00:00:00Z",
      due_date: None,
      has_new_notes: False,
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
    id: 1,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Bug", icon: "bug-ant"),
    ongoing_by: None,
    title: "Fix login",
    description: None,
    priority: 3,
    state: state,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    due_date: None,
    version: 1,
    parent_card_id: None,
    card_id: Some(1),
    card_title: Some("Sprint"),
    card_color: Some(card.Blue),
    has_new_notes: False,
    blocked_count: 0,
    dependencies: [],
    automation_origin: None,
  )
}

fn available_task() -> Task {
  let state = task_state.Available

  Task(
    id: 2,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Bug", icon: "bug-ant"),
    ongoing_by: None,
    title: "Review copy",
    description: None,
    priority: 2,
    state: state,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    due_date: None,
    version: 2,
    parent_card_id: None,
    card_id: Some(1),
    card_title: Some("Sprint"),
    card_color: Some(card.Blue),
    has_new_notes: False,
    blocked_count: 0,
    dependencies: [],
    automation_origin: None,
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
  let state = task_state.Closed(task_state.Done, "2026-01-03T00:00:00Z", 7)

  Task(..available_task(), id: 5, title: "Closed task", state: state)
}

pub fn kanban_task_item_renders_claimed_by_and_icon_test() {
  let html =
    base_config([claimed_task()])
    |> kanban_board.view
    |> element.to_document_string

  assert_contains(html, "kanban-task-item")
  assert_contains(html, "task-claimed-by")
  assert_contains(html, "task-type-icon")
  assert_contains(html, "admin")
}

pub fn kanban_task_item_renders_claim_button_for_available_test() {
  let html =
    base_config([available_task()])
    |> kanban_board.view
    |> element.to_document_string

  assert_contains(html, "btn-claim-mini")
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
    |> element.to_document_string

  assert_contains(html, "card-notes-indicator")
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
    |> element.to_document_string

  assert_contains(html, "data-testid=\"kanban-card-delete-action\"")
  assert_contains(html, "btn-delete-blocked")
  assert_contains(html, "title=\"Cannot delete: has tasks\"")
  assert_contains(html, "data-tooltip=\"Cannot delete: has tasks\"")
  assert_contains(html, "aria-disabled=\"true\"")
}

pub fn kanban_scope_mine_filters_out_tasks_outside_my_capabilities_test() {
  let html =
    kanban_board.KanbanConfig(
      ..base_config([available_task()]),
      capability_scope: capability_scope.MyCapabilities,
      my_capability_ids: [1],
    )
    |> kanban_board.view
    |> element.to_document_string

  assert_not_contains(html, "Review copy")
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
    |> element.to_document_string

  assert_contains(html, "kanban-surface-header")
  assert_contains(html, "Card flow by state")
  assert_contains(html, "data-testid=\"plan-scope-bar\"")
  assert_contains(html, "data-testid=\"plan-scope-kind\"")
  assert_contains(html, "data-testid=\"plan-scope-depth\"")
  assert_contains(html, "data-testid=\"plan-closed-toggle\"")
  assert_not_contains(html, ">Lens<")
  assert_contains(html, "work-surface-chip")
  assert_contains(html, "Cards")
  assert_contains(html, "Available")
  assert_contains(html, "Claimed")
  assert_contains(html, "Ongoing")
  assert_contains(html, "Blocked")
}

pub fn kanban_columns_are_inferred_from_descendant_task_state_test() {
  let child_card =
    Card(
      id: 2,
      project_id: 1,
      parent_card_id: Some(1),
      title: "Child",
      description: "",
      color: Some(card.Green),
      state: Active,
      task_count: 1,
      completed_count: 0,
      created_by: 1,
      created_at: "2026-01-01T00:00:00Z",
      due_date: None,
      has_new_notes: False,
    )
  let child_task = Task(..claimed_task(), id: 7, card_id: Some(2))

  let html =
    kanban_board.KanbanConfig(..base_config([child_task]), cards: [
      child_card,
      ..base_config([]).cards
    ])
    |> kanban_board.view
    |> element.to_document_string

  assert_contains(html, "en-curso")
  assert_contains(html, "Sprint")
  assert_contains(html, "Child")
}

pub fn kanban_level_scope_hides_closed_cards_by_default_test() {
  let closed_card = case base_config([]).cards {
    [first, ..] -> Card(..first, id: 9, title: "Closed card", state: Closed)
    [] -> panic
  }

  let html =
    kanban_board.KanbanConfig(..base_config([]), cards: [closed_card])
    |> kanban_board.view
    |> element.to_document_string

  assert_not_contains(html, "Closed card")
  assert_not_contains(html, "cerrada")
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
    |> element.to_document_string

  assert_contains(html, "Closed")
  assert_contains(html, "Sprint")
  assert_contains(html, "data-testid=\"plan-scope-card-search\"")
  assert_not_contains(html, "data-testid=\"plan-scope-card\"")
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
    |> element.to_document_string

  assert_contains(html, "kanban-health-chip")
  assert_contains(html, "title=\"Available: 2\"")
  assert_contains(html, "title=\"Claimed: 1\"")
  assert_contains(html, "title=\"Ongoing: 1\"")
  assert_contains(html, "title=\"Blocked: 1\"")
  assert_contains(html, "Blocked dependency")
  assert_not_contains(html, "Closed task")
}

pub fn kanban_closed_only_card_still_shows_task_context_test() {
  let html =
    base_config([closed_done_task()])
    |> kanban_board.view
    |> element.to_document_string

  assert_contains(html, "Closed task")
  assert_not_contains(html, "No tasks yet")
}

pub fn kanban_shows_empty_draft_cards_for_decomposition_test() {
  let html =
    base_config([])
    |> kanban_board.view
    |> element.to_document_string

  assert_contains(html, "Sprint")
  assert_contains(html, "No tasks yet")
}
