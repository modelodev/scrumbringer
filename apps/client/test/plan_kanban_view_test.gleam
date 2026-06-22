import domain/card.{Active, Card, Closed, Draft}
import domain/org.{OrgUser}
import domain/org_role.{Admin}
import domain/task.{type Task, Task}
import domain/task_state
import domain/task_type.{TaskType, TaskTypeInline}
import gleam/option.{None, Some}
import gleam/string
import lustre/element

import scrumbringer_client/capability_scope
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/hierarchy/scope_view
import scrumbringer_client/features/plan/kanban_view
import scrumbringer_client/features/views/kanban_board
import scrumbringer_client/i18n/locale as i18n_locale
import scrumbringer_client/theme

fn assert_contains(text: String, fragment: String) {
  let assert True = string.contains(text, fragment)
}

fn assert_not_contains(text: String, fragment: String) {
  let assert False = string.contains(text, fragment)
}

pub fn plan_kanban_keeps_plan_title_and_hides_claimable_task_ui_test() {
  let html =
    config([available_task()])
    |> kanban_view.view
    |> element.to_document_string

  assert_contains(html, "work-surface-title\">Plan")
  assert_contains(html, "data-testid=\"plan-mode-kanban\"")
  assert_contains(html, "aria-pressed=\"true\"")
  assert_not_contains(html, "work-surface-title\">Kanban")
  assert_not_contains(html, "kanban-task-item")
  assert_not_contains(html, "btn-claim-mini")
  assert_not_contains(html, "draggable=\"true\"")
}

pub fn plan_kanban_uses_active_universe_and_closed_toggle_test() {
  let default_html =
    config([])
    |> kanban_view.view
    |> element.to_document_string

  assert_contains(default_html, "Release 1.5")
  assert_not_contains(default_html, "Draft prep")
  assert_not_contains(default_html, "Closed outcome")

  let closed_html =
    kanban_board.KanbanConfig(..config([]), show_closed: Some(True))
    |> kanban_view.view
    |> element.to_document_string

  assert_contains(closed_html, "Release 1.5")
  assert_not_contains(closed_html, "Draft prep")
  assert_contains(closed_html, "Closed outcome")
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
        id: 1,
        project_id: 1,
        parent_card_id: None,
        title: "Release 1.5",
        description: "",
        color: Some(card.Blue),
        state: Active,
        task_count: 1,
        completed_count: 0,
        created_by: 1,
        created_at: "2026-01-01T00:00:00Z",
        due_date: None,
        has_new_notes: False,
      ),
      Card(
        id: 2,
        project_id: 1,
        parent_card_id: None,
        title: "Draft prep",
        description: "",
        color: Some(card.Blue),
        state: Draft,
        task_count: 0,
        completed_count: 0,
        created_by: 1,
        created_at: "2026-01-01T00:00:00Z",
        due_date: None,
        has_new_notes: False,
      ),
      Card(
        id: 3,
        project_id: 1,
        parent_card_id: None,
        title: "Closed outcome",
        description: "",
        color: Some(card.Blue),
        state: Closed,
        task_count: 0,
        completed_count: 0,
        created_by: 1,
        created_at: "2026-01-01T00:00:00Z",
        due_date: None,
        has_new_notes: False,
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
    card_title: Some("Release 1.5"),
    card_color: Some(card.Blue),
    has_new_notes: False,
    blocked_count: 0,
    dependencies: [],
  )
}
