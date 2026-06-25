import domain/card.{type Card, type CardPhase, Active, Card, Closed, Draft}
import domain/task.{type Task, Task}
import domain/task/state as task_state
import domain/task_status.{
  type TaskPhase, Available, Claimed, Done, Ongoing, Taken,
}
import domain/task_type.{TaskTypeInline}
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/element

import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/cards/move_target
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

pub fn project_scope_shows_tree_without_internal_mode_selector_test() {
  let html = render(base_config())

  assert_contains(html, "data-testid=\"plan-structure-view\"")
  assert_contains(html, "data-testid=\"plan-filter-status\"")
  assert_contains(html, "data-testid=\"plan-filter-sort\"")
  assert_contains(html, "Al activar")
  assert_not_contains(html, "Pool impact")
  assert_contains(html, "Root Initiative")
  assert_contains(html, "Portal Feature")
  assert_contains(html, "API Story")
  assert_contains(html, "data-testid=\"plan-tree-table\"")
  assert_contains(html, "data-testid=\"plan-tree-mobile-list\"")
  assert_contains(html, "data-testid=\"plan-tree-mobile-row\"")
  assert_contains(html, "data-card-id=\"1\"")
  assert_not_contains(html, "plan-mode-structure")
  assert_not_contains(html, "plan-mode-kanban")
  assert_not_contains(html, "data-testid=\"plan-move-drag-handle\"")
  assert_not_contains(html, "Lens")
  assert_not_contains(html, "Lente")
  assert_contains(html, "plan-tree-cell is-nested")
  assert_contains(html, "plan-tree-gutter")
  assert_contains(html, "plan-tree-rail")
  assert_contains(html, "plan-tree-rail is-current")
  assert_contains(html, "class=\"plan-tree-marker\">▾</span>")
  assert_contains(html, "class=\"plan-tree-leaf\"></span>")
  assert_not_contains(html, "plan-tree-path")
}

pub fn tree_gutter_scales_for_deep_card_nesting_test() {
  let html =
    render(
      structure_view.Config(..base_config(), cards: [
        card(9, Some(3), "Deep Delivery Slice", Active),
        ..cards()
      ]),
    )

  assert_contains(html, "Deep Delivery Slice")
  assert_contains(html, "Root Initiative / Portal Feature / API Story")
  assert_contains(html, "plan-tree-gutter")
  assert_contains(html, "plan-tree-rail")
  assert_contains(html, "plan-tree-rail is-current")
  assert_contains(html, "class=\"plan-tree-leaf\"></span>")
}

pub fn collapsed_card_hides_descendant_rows_and_marks_toggle_test() {
  let html =
    render(structure_view.Config(..base_config(), collapsed_card_ids: [1]))

  assert_contains(html, "aria-expanded=\"false\"")
  assert_contains(html, "class=\"plan-tree-marker\">▸</span>")
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

pub fn level_scope_uses_visible_level_name_and_matching_card_rows_test() {
  let html =
    render(
      structure_view.Config(
        ..base_config(),
        scope_kind: member_pool.PlanScopeLevel,
        selected_depth: Some(3),
      ),
    )

  assert_contains(html, "Story")
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
  assert_contains(html, "Contenido: subtarjetas")
  assert_contains(html, "Portal Feature")
  assert_not_contains(html, "Contenido: tareas")
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
  assert_contains(html, "Select an active card")
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

  assert_contains(html, "Contenido: tareas")
  assert_contains(html, "Implement API")
  assert_not_contains(html, "Contenido: subtarjetas")
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

  assert_contains(html, "plan-card-scope-layout")
  assert_not_contains(html, "plan-structure-split")
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

pub fn closed_status_filter_still_respects_closed_toggle_test() {
  let hidden =
    render(
      structure_view.Config(
        ..base_config(),
        status_filter: member_pool.PlanStatusClosed,
        show_closed: Some(False),
      ),
    )
  let shown =
    render(
      structure_view.Config(
        ..base_config(),
        status_filter: member_pool.PlanStatusClosed,
        show_closed: Some(True),
      ),
    )

  assert_contains(hidden, "data-testid=\"plan-structure-empty\"")
  assert_not_contains(hidden, "Closed Outcome")
  assert_contains(shown, "Closed Outcome")
  assert_not_contains(shown, "plan-tree-title\">Root Initiative")
  assert_not_contains(shown, "plan-tree-title\">Draft Checkout")
}

pub fn status_filter_copy_uses_locale_and_closed_chip_translation_test() {
  let english =
    render(structure_view.Config(..base_config(), show_closed: Some(True)))
  let spanish =
    render(
      structure_view.Config(
        ..base_config(),
        locale: locale.Es,
        show_closed: Some(True),
      ),
    )

  assert_contains(english, ">All</option>")
  assert_contains(english, ">Pending</option>")
  assert_contains(english, ">In Progress</option>")
  assert_contains(english, ">Closed</option>")
  assert_contains(english, "Includes closed")
  assert_not_contains(english, ">Todas</option>")
  assert_not_contains(english, "Incluye closed")
  assert_contains(spanish, ">Todas</option>")
  assert_contains(spanish, ">Finalizada</option>")
  assert_contains(spanish, "Incluye finalizadas")
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
  assert_contains(html, "Esta tarjeta contiene subtarjetas")
  assert_contains(html, "data-testid=\"plan-action-delete-card\"")
  assert_contains(html, "Tiene historial operativo")
}

pub fn row_actions_are_title_contextual_create_and_move_test() {
  let html = render(base_config())

  assert_contains(html, "data-testid=\"card-show-open\"")
  assert_contains(html, "data-testid=\"plan-action-contextual-create\"")
  assert_contains(html, "data-testid=\"plan-action-move-card\"")
  assert_not_contains(html, "data-testid=\"plan-card-show-action\"")
  assert_not_contains(html, "data-testid=\"plan-action-menu\"")
  assert_not_contains(html, "data-testid=\"plan-action-menu-toggle\"")
  assert_not_contains(html, "aria-haspopup=\"menu\"")
  assert_not_contains(html, "role=\"menuitem\"")
}

pub fn detail_actions_keep_close_and_delete_disabled_reasons_test() {
  let html =
    render(
      structure_view.Config(
        ..base_config(),
        scope_kind: member_pool.PlanScopeCard,
        selected_card_id: Some(1),
      ),
    )

  assert_contains(html, "data-testid=\"plan-action-close-card\"")
  assert_contains(html, "Hay tareas reclamadas o en curso debajo")
  assert_contains(html, "data-testid=\"plan-action-delete-card\"")
  assert_contains(html, "Tiene historial operativo")
}

pub fn move_action_enters_inline_mode_without_opening_detail_test() {
  let html = render(base_config())

  assert_contains(html, "data-testid=\"plan-action-move-card\"")
  assert_not_contains(html, "card-move-dialog")
}

pub fn inline_move_mode_marks_source_and_valid_destinations_test() {
  let html =
    render(
      structure_view.Config(
        ..base_config(),
        move_mode: member_pool.PlanMovingCard(3, ""),
      ),
    )

  assert_contains(html, "data-testid=\"plan-move-context\"")
  assert_contains(html, "Moviendo: API Story")
  assert_contains(html, "data-testid=\"plan-move-source\"")
  assert_contains(html, "data-testid=\"plan-move-drag-handle\"")
  assert_contains(html, "draggable=\"true\"")
  assert_contains(html, "data-testid=\"plan-move-here\"")
  assert_contains(html, "Mover dentro")
  assert_contains(html, "data-testid=\"plan-move-root-option\"")
  assert_contains(html, "Mover a raiz")
}

pub fn inline_move_drag_marks_source_as_dragging_test() {
  let html =
    render(
      structure_view.Config(
        ..base_config(),
        move_mode: member_pool.PlanMovingCard(3, ""),
        move_drag_state: member_pool.PlanMoveDraggingCard(3, None),
      ),
    )

  assert_contains(html, "is-dragging-source")
  assert_contains(html, "Arrastrando")
}

pub fn inline_move_drag_over_valid_destination_shows_drop_hint_test() {
  let html =
    render(
      structure_view.Config(
        ..base_config(),
        move_mode: member_pool.PlanMovingCard(3, ""),
        move_drag_state: member_pool.PlanMoveDraggingCard(
          3,
          Some(move_target.InsideCard(8)),
        ),
      ),
    )

  assert_contains(html, "is-drop-active")
  assert_contains(html, "data-testid=\"plan-drop-target-hint\"")
  assert_contains(html, "Soltar dentro de Mobile Feature")
  assert_contains(html, "data-testid=\"plan-move-here\"")
}

pub fn inline_move_mode_shows_invalid_reason_test() {
  let html =
    render(
      structure_view.Config(
        ..base_config(),
        move_mode: member_pool.PlanMovingCard(3, ""),
      ),
    )

  assert_contains(html, "data-testid=\"plan-move-invalid\"")
  assert_contains(html, "Ya está dentro de esta tarjeta.")
}

pub fn inline_move_drag_over_invalid_destination_does_not_show_drop_hint_test() {
  let html =
    render(
      structure_view.Config(
        ..base_config(),
        move_mode: member_pool.PlanMovingCard(3, ""),
        move_drag_state: member_pool.PlanMoveDraggingCard(
          3,
          Some(move_target.InsideCard(2)),
        ),
      ),
    )

  assert_contains(html, "data-testid=\"plan-move-invalid\"")
  assert_contains(html, "Ya está dentro de esta tarjeta.")
  assert_not_contains(html, "Soltar dentro de Portal Feature")
}

pub fn click_to_move_fallback_still_renders_after_drag_support_test() {
  let html =
    render(
      structure_view.Config(
        ..base_config(),
        move_mode: member_pool.PlanMovingCard(3, ""),
      ),
    )

  assert_contains(html, "data-testid=\"plan-move-here\"")
  assert_contains(html, "Mover dentro")
  assert_contains(html, "data-testid=\"plan-move-destination-search\"")
}

pub fn mobile_move_mode_keeps_click_fallback_without_mobile_drag_handle_test() {
  let html =
    render(
      structure_view.Config(
        ..base_config(),
        move_mode: member_pool.PlanMovingCard(3, ""),
      ),
    )

  assert_contains(html, "data-testid=\"plan-tree-mobile-list\"")
  assert_contains(html, "data-testid=\"plan-tree-mobile-row\"")
  assert_contains(html, "data-testid=\"plan-move-here\"")
  assert_contains(html, "Mover dentro")
}

pub fn inline_move_destination_search_filters_by_title_path_and_id_test() {
  let by_title =
    render(
      structure_view.Config(
        ..base_config(),
        move_mode: member_pool.PlanMovingCard(3, "Mobile"),
      ),
    )
  let by_path =
    render(
      structure_view.Config(
        ..base_config(),
        move_mode: member_pool.PlanMovingCard(3, "Root Initiative"),
      ),
    )
  let by_id =
    render(
      structure_view.Config(
        ..base_config(),
        move_mode: member_pool.PlanMovingCard(3, "#8"),
      ),
    )

  assert_contains(by_title, "data-testid=\"plan-move-destination-search\"")
  assert_contains(by_title, "Mobile Feature")
  assert_contains(by_path, "Portal Feature")
  assert_contains(by_id, "Mobile Feature")
}

pub fn root_cards_can_enter_move_mode_when_card_destinations_exist_test() {
  let html =
    render(
      structure_view.Config(
        ..base_config(),
        cards: [card(9, None, "Sibling Initiative", Active), ..cards()],
        move_mode: member_pool.PlanMovingCard(1, ""),
      ),
    )

  assert_not_contains(html, "Las cards raiz no tienen un padre alternativo.")
  assert_not_contains(html, "data-testid=\"plan-move-root-option\"")
  assert_contains(html, "data-testid=\"plan-move-here\"")
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
    card_query: "",
    show_closed: None,
    status_filter: member_pool.PlanStatusAll,
    sort_order: member_pool.PlanSortPath,
    collapsed_card_ids: [],
    search_query: "",
    is_pm_or_admin: True,
    plan_mode: member_pool.PlanStructure,
    move_mode: member_pool.PlanNotMoving,
    move_drag_state: member_pool.PlanMoveNotDragging,
    move_in_flight: False,
    move_error: None,
    on_plan_mode_change: fn(_) { 0 },
    on_scope_kind_change: fn(_) { 0 },
    on_scope_depth_change: fn(_) { 0 },
    on_scope_card_change: fn(_) { 0 },
    on_scope_card_search_change: fn(_) { 0 },
    on_closed_toggled: fn(_) { 0 },
    on_status_filter_change: fn(_) { 0 },
    on_sort_change: fn(_) { 0 },
    on_card_toggle: fn(id) { id },
    on_card_click: fn(id) { id },
    on_card_edit: fn(id) { id },
    on_card_delete: fn(id) { id },
    on_move_requested: fn(id) { id },
    on_move_cancelled: 0,
    on_move_destination_search_change: fn(_) { 0 },
    on_move_destination_selected: fn(_) { 0 },
    on_move_drag_started: fn(id) { id },
    on_move_drag_entered: fn(_) { 0 },
    on_move_dropped: fn(_) { 0 },
    on_move_drag_ended: 0,
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
    card(8, Some(1), "Mobile Feature", Active),
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
    task(3, "Draft activation impact", Some(4), Available),
  ]
}

fn task(id: Int, title: String, card_id: Option(Int), status: TaskPhase) -> Task {
  let state = case status {
    Available -> task_state.Available
    Claimed(mode) ->
      task_state.Claimed(
        claimed_by: 1,
        claimed_at: "2026-01-01T00:00:00Z",
        mode: claim_mode(mode),
      )
    Done -> task_state.Closed(task_state.Done, "2026-01-02T00:00:00Z", 7)
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
    automation_origin: None,
  )
}

fn claim_mode(mode: task_status.ClaimedState) -> task_state.TaskClaimMode {
  case mode {
    Taken -> task_state.Taken
    Ongoing -> task_state.Ongoing
  }
}
