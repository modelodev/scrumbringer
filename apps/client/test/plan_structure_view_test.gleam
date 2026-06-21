import domain/card.{type Card, type CardPhase, Active, Card, Closed, Draft}
import domain/task.{type Task, Task}
import domain/task_state
import domain/task_status.{type TaskPhase, Available, Claimed, Done, Taken}
import domain/task_type.{TaskTypeInline}
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/element

import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/hierarchy/scope_view
import scrumbringer_client/features/plan/structure_view
import scrumbringer_client/i18n/locale

fn assert_contains(text: String, fragment: String) {
  let assert True = string.contains(text, fragment)
}

fn assert_not_contains(text: String, fragment: String) {
  let assert False = string.contains(text, fragment)
}

fn render(config: structure_view.Config(Int)) -> String {
  structure_view.view(config) |> element.to_document_string
}

pub fn project_scope_shows_tree_and_mode_without_lens_test() {
  let html = render(base_config())

  assert_contains(html, "data-testid=\"plan-structure-view\"")
  assert_contains(html, "data-testid=\"plan-filter-status\"")
  assert_contains(html, "data-testid=\"plan-filter-sort\"")
  assert_contains(html, "Root Initiative")
  assert_contains(html, "Portal Feature")
  assert_contains(html, "API Story")
  assert_contains(html, "data-testid=\"plan-tree-table\"")
  assert_contains(html, "data-testid=\"plan-tree-mobile-list\"")
  assert_contains(html, "data-testid=\"plan-tree-mobile-row\"")
  assert_contains(html, "data-card-id=\"1\"")
  assert_contains(html, "plan-mode-structure")
  assert_contains(html, "plan-mode-kanban")
  assert_not_contains(html, "Lens")
  assert_not_contains(html, "Lente")
}

pub fn collapsed_card_hides_descendant_rows_and_marks_toggle_test() {
  let html =
    render(structure_view.Config(..base_config(), collapsed_card_ids: [1]))

  assert_contains(html, "aria-expanded=\"false\"")
  assert_contains(html, "Root Initiative")
  assert_not_contains(html, "Portal Feature")
  assert_not_contains(html, "API Story")
  assert_not_contains(html, "Draft Behind Closed")
}

pub fn status_filter_limits_visible_rows_test() {
  let html =
    render(
      structure_view.Config(
        ..base_config(),
        status_filter: member_pool.PlanStatusDraft,
      ),
    )

  assert_contains(html, "Draft Checkout")
  assert_not_contains(html, "plan-tree-title\">Root Initiative")
  assert_not_contains(html, "plan-tree-title\">Portal Feature")
}

pub fn level_scope_uses_visible_level_name_and_parent_path_test() {
  let html =
    render(
      structure_view.Config(
        ..base_config(),
        scope_kind: member_pool.PlanScopeLevel,
        selected_depth: Some(3),
      ),
    )

  assert_contains(html, "Story")
  assert_contains(html, "Root Initiative / Portal Feature")
  assert_contains(html, "API Story")
}

pub fn card_scope_with_subcards_prioritizes_subcards_detail_test() {
  let html =
    render(
      structure_view.Config(
        ..base_config(),
        scope_kind: member_pool.PlanScopeCard,
        selected_card_id: Some(1),
      ),
    )

  assert_contains(html, "data-testid=\"plan-structure-detail\"")
  assert_contains(html, "Contenido: subcards")
  assert_contains(html, "Portal Feature")
  assert_not_contains(html, "Contenido: tasks")
}

pub fn card_scope_without_selection_shows_empty_state_not_full_tree_test() {
  let html =
    render(
      structure_view.Config(
        ..base_config(),
        scope_kind: member_pool.PlanScopeCard,
        selected_card_id: None,
      ),
    )

  assert_contains(html, "data-testid=\"plan-structure-empty\"")
  assert_contains(html, "Selecciona una card activa")
  assert_contains(html, "data-testid=\"plan-scope-card-search\"")
  assert_not_contains(html, "plan-tree-title\">Root Initiative")
  assert_not_contains(html, "plan-tree-title\">Portal Feature")
  assert_not_contains(html, "plan-tree-title\">API Story")
}

pub fn card_scope_with_tasks_prioritizes_tasks_detail_test() {
  let html =
    render(
      structure_view.Config(
        ..base_config(),
        scope_kind: member_pool.PlanScopeCard,
        selected_card_id: Some(3),
      ),
    )

  assert_contains(html, "Contenido: tasks")
  assert_contains(html, "Implement API")
  assert_not_contains(html, "Contenido: subcards")
}

pub fn card_scope_selection_shows_only_selected_subtree_test() {
  let html =
    render(
      structure_view.Config(
        ..base_config(),
        scope_kind: member_pool.PlanScopeCard,
        selected_card_id: Some(2),
      ),
    )

  assert_not_contains(html, "plan-tree-title\">Root Initiative")
  assert_contains(html, "plan-tree-title\">Portal Feature")
  assert_contains(html, "plan-tree-title\">API Story")
  assert_contains(html, "plan-tree-title\">Draft Checkout")
}

pub fn closed_cards_are_hidden_until_closed_toggle_applies_test() {
  let hidden = render(base_config())
  let shown =
    render(structure_view.Config(..base_config(), show_closed: Some(True)))

  assert_not_contains(hidden, "Closed Outcome")
  assert_contains(shown, "Closed Outcome")
}

pub fn incompatible_actions_are_disabled_with_reason_test() {
  let html =
    render(
      structure_view.Config(
        ..base_config(),
        scope_kind: member_pool.PlanScopeCard,
        selected_card_id: Some(1),
      ),
    )

  assert_contains(html, "data-testid=\"plan-action-create-task\"")
  assert_contains(html, "Esta card contiene subcards")
  assert_contains(html, "data-testid=\"plan-action-delete-card\"")
  assert_contains(html, "Tiene historial operativo")
}

pub fn row_actions_are_detail_contextual_create_and_secondary_menu_test() {
  let html = render(base_config())

  assert_contains(html, "data-testid=\"plan-card-detail-action\"")
  assert_contains(html, "data-testid=\"plan-action-contextual-create\"")
  assert_contains(html, "data-testid=\"plan-action-menu\"")
  assert_contains(html, "data-testid=\"plan-action-menu-toggle\"")
}

pub fn secondary_action_menu_keeps_close_and_delete_disabled_reasons_test() {
  let html =
    render(
      structure_view.Config(
        ..base_config(),
        scope_kind: member_pool.PlanScopeCard,
        selected_card_id: Some(1),
      ),
    )

  assert_contains(html, "data-testid=\"plan-action-menu\"")
  assert_contains(html, "data-testid=\"plan-action-close-card\"")
  assert_contains(html, "Hay tasks reclamadas o en curso debajo")
  assert_contains(html, "data-testid=\"plan-action-delete-card\"")
  assert_contains(html, "Tiene historial operativo")
}

fn base_config() -> structure_view.Config(Int) {
  structure_view.Config(
    locale: locale.En,
    cards: cards(),
    tasks: tasks(),
    depth_names: [
      scope_view.DepthName(1, "Initiative", "Initiatives"),
      scope_view.DepthName(2, "Feature", "Features"),
      scope_view.DepthName(3, "Story", "Stories"),
    ],
    scope_kind: member_pool.PlanScopeProject,
    selected_depth: None,
    selected_card_id: None,
    show_closed: None,
    status_filter: member_pool.PlanStatusAll,
    sort_order: member_pool.PlanSortPath,
    collapsed_card_ids: [],
    search_query: "",
    is_pm_or_admin: True,
    plan_mode: member_pool.PlanStructure,
    on_plan_mode_change: fn(_) { 0 },
    on_scope_kind_change: fn(_) { 0 },
    on_scope_depth_change: fn(_) { 0 },
    on_scope_card_change: fn(_) { 0 },
    on_closed_toggled: fn(_) { 0 },
    on_status_filter_change: fn(_) { 0 },
    on_sort_change: fn(_) { 0 },
    on_card_toggle: fn(id) { id },
    on_card_click: fn(id) { id },
    on_card_edit: fn(id) { id },
    on_card_delete: fn(id) { id },
    on_create_task_in_card: fn(id) { id },
    on_create_subcard: fn(id) { id },
  )
}

fn cards() -> List(Card) {
  [
    card(1, None, "Root Initiative", Active),
    card(2, Some(1), "Portal Feature", Active),
    card(3, Some(2), "API Story", Active),
    card(4, Some(2), "Draft Checkout", Draft),
    card(5, None, "Closed Outcome", Closed),
    card(6, Some(1), "Closed Gate", Closed),
    card(7, Some(6), "Draft Behind Closed", Draft),
  ]
}

fn card(
  id: Int,
  parent_card_id: Option(Int),
  title: String,
  state: CardPhase,
) -> Card {
  Card(
    id: id,
    project_id: 1,
    parent_card_id: parent_card_id,
    title: title,
    description: "",
    color: None,
    state: state,
    task_count: 0,
    completed_count: 0,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    due_date: None,
    has_new_notes: False,
  )
}

fn tasks() -> List(Task) {
  [
    task(1, "Implement API", Some(3), Available),
    task(2, "Review API", Some(3), Claimed(Taken)),
    task(3, "Draft pool impact", Some(4), Available),
  ]
}

fn task(id: Int, title: String, card_id: Option(Int), status: TaskPhase) -> Task {
  let state = case status {
    Available -> task_state.Available
    Claimed(mode) ->
      task_state.Claimed(
        claimed_by: 1,
        claimed_at: "2026-01-01T00:00:00Z",
        mode: mode,
      )
    Done -> task_state.Done(completed_at: "2026-01-02T00:00:00Z")
  }
  Task(
    id: id,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Backend", icon: "code-bracket"),
    ongoing_by: None,
    title: title,
    description: None,
    priority: 3,
    state: state,
    status: status,
    work_state: task_state.to_work_state(state),
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    due_date: None,
    version: 1,
    parent_card_id: None,
    card_id: card_id,
    card_title: None,
    card_color: None,
    has_new_notes: False,
    blocked_count: case id {
      2 -> 1
      _ -> 0
    },
    dependencies: [],
  )
}
