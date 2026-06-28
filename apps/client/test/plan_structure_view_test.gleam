import domain/card.{type Card, type CardPhase, Active, Card, Closed, Draft}
import domain/task.{type Task, Task}
import domain/task/state as task_state
import domain/task_status.{
  type TaskPhase, Available, Claimed, Closed as TaskClosed, Ongoing, Taken,
}
import domain/task_type.{TaskTypeInline}
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/element
import support/domain_fixtures
import support/render_assertions

import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/cards/move_target
import scrumbringer_client/features/hierarchy/scope_view
import scrumbringer_client/features/plan/structure_view
import scrumbringer_client/i18n/locale

fn assert_before(text: String, first: String, second: String) {
  let assert Ok(#(_, after_first)) = string.split_once(text, first)
  let assert Ok(#(_, _)) = string.split_once(after_first, second)
  Nil
}

fn render(config: structure_view.Config(Int)) -> String {
  structure_view.view(config) |> element.to_document_string
}

pub fn project_scope_shows_tree_without_internal_mode_selector_test() {
  let html = render(base_config())

  render_assertions.contains(html, "data-testid=\"plan-structure-view\"")
  render_assertions.contains(html, "data-testid=\"plan-filter-status\"")
  render_assertions.contains(html, "data-testid=\"plan-filter-sort\"")
  render_assertions.not_contains(
    html,
    "data-testid=\"work-filter-capability-scope\"",
  )
  render_assertions.contains(html, "Trabajo")
  render_assertions.not_contains(html, "Al activar")
  render_assertions.not_contains(html, "Vence")
  render_assertions.not_contains(html, "ya activo")
  render_assertions.not_contains(html, "Pool impact")
  render_assertions.contains(html, "Root Initiative")
  render_assertions.contains(html, "Portal Feature")
  render_assertions.contains(html, "API Story")
  render_assertions.contains(html, "data-testid=\"plan-tree-table\"")
  render_assertions.contains(html, "data-testid=\"plan-tree-mobile-list\"")
  render_assertions.contains(html, "data-testid=\"plan-tree-mobile-row\"")
  render_assertions.contains(html, "data-card-id=\"1\"")
  render_assertions.not_contains(html, "plan-mode-structure")
  render_assertions.not_contains(html, "plan-mode-kanban")
  render_assertions.not_contains(html, "data-testid=\"plan-move-drag-handle\"")
  render_assertions.not_contains(html, "Lens")
  render_assertions.not_contains(html, "Lente")
  render_assertions.contains(html, "plan-tree-cell is-nested")
  render_assertions.contains(html, "plan-tree-gutter")
  render_assertions.contains(html, "plan-tree-node")
  render_assertions.contains(html, "plan-tree-node is-open")
  render_assertions.contains(html, "plan-tree-rail is-elbow")
  render_assertions.contains(html, "plan-tree-rail is-end")
  render_assertions.contains(html, ">▾</button>")
  render_assertions.contains(html, "plan-tree-toggle-placeholder")
  render_assertions.contains(html, "plan-tree-terminal-dot")
  render_assertions.not_contains(html, "plan-tree-chevron")
  render_assertions.not_contains(html, "plan-tree-toggle-slot")
  render_assertions.not_contains(html, "plan-tree-marker")
  render_assertions.not_contains(html, "plan-tree-leaf")
  render_assertions.not_contains(html, "plan-tree-path")
  render_assertions.contains(html, "plan-detail-context")
  render_assertions.contains(html, "Tareas descendientes")
}

pub fn tree_gutter_scales_for_deep_card_nesting_test() {
  let html =
    render(
      structure_view.Config(..base_config(), cards: [
        card(10, Some(1), "Zeta Feature", Active),
        card(9, Some(4), "Deep Delivery Slice", Active),
        ..cards()
      ]),
    )

  render_assertions.contains(html, "Deep Delivery Slice")
  render_assertions.contains(
    html,
    "Root Initiative / Portal Feature / Draft Checkout",
  )
  render_assertions.contains(html, "plan-tree-gutter")
  render_assertions.contains(html, "plan-tree-rail is-continue")
  render_assertions.contains(html, "plan-tree-rail is-blank")
  render_assertions.contains(html, "plan-tree-rail is-end")
  render_assertions.contains(html, "plan-tree-toggle-placeholder")
  render_assertions.contains(html, "plan-tree-terminal-dot")
}

pub fn collapsed_card_hides_descendant_rows_and_marks_toggle_test() {
  let html =
    render(structure_view.Config(..base_config(), collapsed_card_ids: [1]))

  render_assertions.contains(html, "aria-expanded=\"false\"")
  render_assertions.contains(html, ">▸</button>")
  render_assertions.not_contains(html, "plan-tree-node is-open")
  render_assertions.contains(html, "Root Initiative")
  render_assertions.not_contains(html, "Portal Feature")
  render_assertions.not_contains(html, "API Story")
  render_assertions.not_contains(html, "Draft Behind Closed")
}

pub fn status_filter_limits_visible_rows_test() {
  let html =
    render(
      structure_view.Config(
        ..base_config(),
        status_filter: member_pool.PlanStatusDraft,
      ),
    )

  render_assertions.contains(html, "Draft Checkout")
  render_assertions.not_contains(html, "plan-tree-title\">Root Initiative")
  render_assertions.not_contains(html, "plan-tree-title\">Portal Feature")
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

  render_assertions.contains(html, "Story")
  render_assertions.contains(html, "API Story")
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

  render_assertions.contains(html, "data-testid=\"plan-structure-detail\"")
  render_assertions.contains(html, "Contenido: subtarjetas")
  render_assertions.contains(html, "Portal Feature")
  render_assertions.not_contains(html, "Contenido: tareas")
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

  render_assertions.contains(html, "data-testid=\"plan-structure-empty\"")
  render_assertions.contains(html, "Select an active card")
  render_assertions.contains(html, "data-testid=\"plan-scope-card-search\"")
  render_assertions.not_contains(html, "plan-tree-title\">Root Initiative")
  render_assertions.not_contains(html, "plan-tree-title\">Portal Feature")
  render_assertions.not_contains(html, "plan-tree-title\">API Story")
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

  render_assertions.contains(html, "Contenido: tareas")
  render_assertions.contains(html, "Implement API")
  render_assertions.not_contains(html, "Contenido: subtarjetas")
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

  render_assertions.contains(html, "plan-card-scope-layout")
  render_assertions.not_contains(html, "plan-structure-split")
  render_assertions.not_contains(html, "plan-tree-title\">Root Initiative")
  render_assertions.contains(html, "plan-tree-title\">Portal Feature")
  render_assertions.contains(html, "plan-tree-title\">API Story")
  render_assertions.contains(html, "plan-tree-title\">Draft Checkout")
}

pub fn closed_cards_are_hidden_until_closed_toggle_applies_test() {
  let hidden = render(base_config())
  let shown =
    render(structure_view.Config(..base_config(), show_closed: Some(True)))

  render_assertions.not_contains(hidden, "Closed Outcome")
  render_assertions.contains(shown, "Closed Outcome")
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

  render_assertions.contains(hidden, "data-testid=\"plan-structure-empty\"")
  render_assertions.not_contains(hidden, "Closed Outcome")
  render_assertions.contains(shown, "Closed Outcome")
  render_assertions.not_contains(shown, "plan-tree-title\">Root Initiative")
  render_assertions.not_contains(shown, "plan-tree-title\">Draft Checkout")
}

pub fn due_date_sort_uses_valid_date_values_before_invalid_or_missing_test() {
  let html =
    render(
      structure_view.Config(
        ..base_config(),
        cards: [
          Card(
            ..card(10, None, "Invalid Date", Active),
            due_date: Some("not-a-date"),
          ),
          Card(..card(11, None, "No Date", Active), due_date: None),
          Card(
            ..card(12, None, "Later Date", Active),
            due_date: Some("2026-07-01"),
          ),
          Card(
            ..card(13, None, "Soon Date", Active),
            due_date: Some("2026-06-19"),
          ),
        ],
        sort_order: member_pool.PlanSortDueDate,
      ),
    )

  assert_before(html, "Soon Date", "Later Date")
  assert_before(html, "Later Date", "Invalid Date")
  assert_before(html, "Later Date", "No Date")
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

  render_assertions.contains(english, ">All</option>")
  render_assertions.contains(english, ">Pending</option>")
  render_assertions.contains(english, ">Active</option>")
  render_assertions.contains(english, ">Closed</option>")
  render_assertions.contains(english, "Includes closed")
  render_assertions.not_contains(english, ">Todas</option>")
  render_assertions.not_contains(english, "Incluye closed")
  render_assertions.contains(spanish, ">Todas</option>")
  render_assertions.contains(spanish, ">cerrada</option>")
  render_assertions.contains(spanish, "Incluye cerradas")
}

pub fn unsupported_detail_actions_are_hidden_test() {
  let html =
    render(
      structure_view.Config(
        ..base_config(),
        scope_kind: member_pool.PlanScopeCard,
        selected_card_id: Some(1),
      ),
    )

  render_assertions.not_contains(
    html,
    "data-testid=\"plan-action-create-task\"",
  )
  render_assertions.not_contains(html, "Esta tarjeta contiene subtarjetas")
  render_assertions.not_contains(
    html,
    "data-testid=\"plan-action-delete-card\"",
  )
  render_assertions.not_contains(html, "Tiene historial operativo")
}

pub fn row_actions_are_title_and_contextual_create_test() {
  let html = render(base_config())

  render_assertions.contains(html, "data-testid=\"card-show-open\"")
  render_assertions.contains(
    html,
    "data-testid=\"plan-action-contextual-create\"",
  )
  render_assertions.contains(html, "Activar subárbol")
  render_assertions.not_contains(html, "data-testid=\"plan-action-move-card\"")
  render_assertions.not_contains(html, "data-testid=\"plan-card-show-action\"")
  render_assertions.not_contains(html, "data-testid=\"plan-action-menu\"")
  render_assertions.not_contains(
    html,
    "data-testid=\"plan-action-menu-toggle\"",
  )
  render_assertions.not_contains(html, "aria-haspopup=\"menu\"")
  render_assertions.not_contains(html, "role=\"menuitem\"")
}

pub fn detail_actions_hide_unavailable_close_and_delete_test() {
  let html =
    render(
      structure_view.Config(
        ..base_config(),
        scope_kind: member_pool.PlanScopeCard,
        selected_card_id: Some(1),
      ),
    )

  render_assertions.not_contains(html, "data-testid=\"plan-action-close-card\"")
  render_assertions.not_contains(
    html,
    "Hay tareas reclamadas o en curso debajo",
  )
  render_assertions.not_contains(
    html,
    "data-testid=\"plan-action-delete-card\"",
  )
  render_assertions.not_contains(html, "Tiene historial operativo")
}

pub fn normal_outline_does_not_repeat_move_action_per_row_test() {
  let html = render(base_config())

  render_assertions.not_contains(html, "data-testid=\"plan-action-move-card\"")
  render_assertions.not_contains(html, "card-move-dialog")
}

pub fn inline_move_mode_marks_source_and_valid_destinations_test() {
  let html =
    render(
      structure_view.Config(
        ..base_config(),
        move_mode: member_pool.PlanMovingCard(3, ""),
      ),
    )

  render_assertions.contains(html, "data-testid=\"plan-move-context\"")
  render_assertions.contains(html, "Moviendo: API Story")
  render_assertions.contains(html, "data-testid=\"plan-move-source\"")
  render_assertions.contains(html, "data-testid=\"plan-move-drag-handle\"")
  render_assertions.contains(html, "draggable=\"true\"")
  render_assertions.contains(html, "data-testid=\"plan-move-here\"")
  render_assertions.contains(html, "Mover dentro")
  render_assertions.contains(html, "data-testid=\"plan-move-root-option\"")
  render_assertions.contains(html, "Mover a raiz")
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

  render_assertions.contains(html, "is-dragging-source")
  render_assertions.contains(html, "Arrastrando")
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

  render_assertions.contains(html, "is-drop-active")
  render_assertions.contains(html, "data-testid=\"plan-drop-target-hint\"")
  render_assertions.contains(html, "Soltar dentro de Mobile Feature")
  render_assertions.contains(html, "data-testid=\"plan-move-here\"")
}

pub fn inline_move_mode_shows_invalid_reason_test() {
  let html =
    render(
      structure_view.Config(
        ..base_config(),
        move_mode: member_pool.PlanMovingCard(3, ""),
      ),
    )

  render_assertions.contains(html, "data-testid=\"plan-move-invalid\"")
  render_assertions.contains(html, "Ya está dentro de esta tarjeta.")
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

  render_assertions.contains(html, "data-testid=\"plan-move-invalid\"")
  render_assertions.contains(html, "Ya está dentro de esta tarjeta.")
  render_assertions.not_contains(html, "Soltar dentro de Portal Feature")
}

pub fn click_to_move_fallback_still_renders_after_drag_support_test() {
  let html =
    render(
      structure_view.Config(
        ..base_config(),
        move_mode: member_pool.PlanMovingCard(3, ""),
      ),
    )

  render_assertions.contains(html, "data-testid=\"plan-move-here\"")
  render_assertions.contains(html, "Mover dentro")
  render_assertions.contains(
    html,
    "data-testid=\"plan-move-destination-search\"",
  )
}

pub fn mobile_move_mode_keeps_click_fallback_without_mobile_drag_handle_test() {
  let html =
    render(
      structure_view.Config(
        ..base_config(),
        move_mode: member_pool.PlanMovingCard(3, ""),
      ),
    )

  render_assertions.contains(html, "data-testid=\"plan-tree-mobile-list\"")
  render_assertions.contains(html, "data-testid=\"plan-tree-mobile-row\"")
  render_assertions.contains(html, "data-testid=\"plan-move-here\"")
  render_assertions.contains(html, "Mover dentro")
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

  render_assertions.contains(
    by_title,
    "data-testid=\"plan-move-destination-search\"",
  )
  render_assertions.contains(by_title, "Mobile Feature")
  render_assertions.contains(by_path, "Portal Feature")
  render_assertions.contains(by_id, "Mobile Feature")
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

  render_assertions.not_contains(
    html,
    "Las cards raiz no tienen un padre alternativo.",
  )
  render_assertions.not_contains(html, "data-testid=\"plan-move-root-option\"")
  render_assertions.contains(html, "data-testid=\"plan-move-here\"")
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
    ..domain_fixtures.card(id, 1, title),
    parent_card_id: parent_card_id,
    state: state,
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
    TaskClosed ->
      task_state.Closed(task_state.ClosedByClaimant, "2026-01-02T00:00:00Z", 7)
  }
  Task(
    ..domain_fixtures.task(id, title, 1),
    task_type: TaskTypeInline(id: 1, name: "Backend", icon: "code-bracket"),
    description: None,
    state: state,
    card_id: card_id,
    blocked_count: case id {
      2 -> 1
      _ -> 0
    },
  )
}

fn claim_mode(mode: task_status.ClaimedState) -> task_state.TaskClaimMode {
  case mode {
    Taken -> task_state.Taken
    Ongoing -> task_state.Ongoing
  }
}
