import domain/card.{Active, Card, Closed, Draft}
import domain/org.{OrgUser}
import domain/org_role.{Admin}
import domain/task.{type Task, Task}
import domain/task_type.{TaskType}
import gleam/option.{None, Some}
import support/domain_fixtures

import scrumbringer_client/capability_scope
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/hierarchy/scope_view
import scrumbringer_client/features/plan/kanban_view
import scrumbringer_client/features/views/kanban_board
import scrumbringer_client/i18n/locale as i18n_locale
import scrumbringer_client/theme
import support/render_assertions

pub fn plan_kanban_has_kanban_title_and_hides_claimable_task_ui_test() {
  let html =
    config([available_task()])
    |> kanban_view.view
    |> render_assertions.html

  render_assertions.contains(html, "work-surface-title\">Kanban")
  render_assertions.not_contains(html, "work-surface-title\">Plan")
  render_assertions.not_contains(html, "data-testid=\"plan-mode-kanban\"")
  render_assertions.not_contains(html, "data-testid=\"plan-mode-structure\"")
  render_assertions.not_contains(html, "kanban-task-item")
  render_assertions.not_contains(html, "btn-claim-mini")
  render_assertions.not_contains(html, "draggable=\"true\"")
  render_assertions.contains(
    html,
    "data-testid=\"work-filter-capability-scope\"",
  )
}

pub fn plan_kanban_card_scope_without_selection_shows_card_target_options_test() {
  let html =
    kanban_board.KanbanConfig(
      ..config([]),
      scope_kind: member_pool.PlanScopeCard,
      selected_card_id: None,
    )
    |> kanban_view.view
    |> render_assertions.html

  render_assertions.contains(html, "data-testid=\"kanban-empty-card-scope\"")
  render_assertions.contains(html, "Select an active card")
  render_assertions.contains(html, "data-testid=\"plan-scope-card-option\"")
  render_assertions.contains(html, "Release 1.5")
  render_assertions.not_contains(html, "Draft prep")
  render_assertions.not_contains(html, "Closed outcome")
}

pub fn plan_kanban_hides_management_actions_even_for_managers_test() {
  let html =
    kanban_board.KanbanConfig(..config([]), is_pm_or_admin: True)
    |> kanban_view.view
    |> render_assertions.html

  render_assertions.not_contains(html, "kanban-card-edit-action")
  render_assertions.not_contains(html, "kanban-card-delete-action")
}

pub fn plan_kanban_uses_active_universe_and_closed_toggle_test() {
  let default_html =
    config([])
    |> kanban_view.view
    |> render_assertions.html

  render_assertions.contains(default_html, "Release 1.5")
  render_assertions.not_contains(default_html, "Draft prep")
  render_assertions.not_contains(default_html, "Closed outcome")

  let closed_html =
    kanban_board.KanbanConfig(..config([]), show_closed: Some(True))
    |> kanban_view.view
    |> render_assertions.html

  render_assertions.contains(closed_html, "Release 1.5")
  render_assertions.not_contains(closed_html, "Draft prep")
  render_assertions.contains(closed_html, "Closed outcome")
}

fn config(tasks: List(Task)) -> kanban_board.KanbanConfig(Int) {
  kanban_board.KanbanConfig(
    locale: i18n_locale.En,
    theme: theme.Default,
    surface_title: "Kanban",
    surface_purpose: "Card flow by state",
    purpose: kanban_board.ExecutionKanban,
    cards: [
      Card(
        ..domain_fixtures.card(1, 1, "Release 1.5"),
        color: Some(card.Blue),
        state: Active,
        task_count: 1,
      ),
      Card(
        ..domain_fixtures.card(2, 1, "Draft prep"),
        color: Some(card.Blue),
        state: Draft,
      ),
      Card(
        ..domain_fixtures.card(3, 1, "Closed outcome"),
        color: Some(card.Blue),
        state: Closed,
      ),
    ],
    tasks: tasks,
    task_types: [
      TaskType(
        id: 1,
        name: "Bug",
        icon: "bug-ant",
        capability_id: None,
        tasks_count: 1,
      ),
    ],
    capabilities: [],
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
    on_task_claim: fn(task_id, version) { task_id + version },
    on_create_task_in_card: fn(id) { id },
    depth_names: [scope_view.DepthName(1, "Epic", "Epics")],
    scope_kind: member_pool.PlanScopeProject,
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

fn available_task() -> Task {
  Task(
    ..domain_fixtures.task(2, "Review copy", 1),
    description: None,
    priority: 2,
    version: 2,
    card_id: Some(1),
    card_title: Some("Release 1.5"),
    card_color: Some(card.Blue),
  )
}
