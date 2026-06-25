//// Member pool state.

import gleam/dict.{type Dict}
import gleam/option.{type Option}

import domain/card.{type Card}
import domain/people_workload.{type PersonWorkload}
import domain/remote.{type Remote, NotAsked}
import domain/task.{type Task}
import domain/task_type.{type TaskType}
import domain/view_mode
import scrumbringer_client/capability_scope
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/features/cards/move_target.{type MoveTarget}
import scrumbringer_client/features/pool/visibility.{type PoolVisibility}
import scrumbringer_client/pool_prefs
import scrumbringer_client/state/normalized_store

import scrumbringer_client/features/people/state as people_state

/// Highlight state for dependency visualization in pool cards.
pub type HighlightState {
  NoHighlight
  CreatedHighlight(task_id: Int)
  BlockingHighlight(
    source_task_id: Int,
    blocker_ids: List(Int),
    hidden_count: Int,
  )
}

/// State during drag-and-drop of a task card.
pub type DragState {
  DragIdle
  DragPending(task_id: Int)
  DragActive(task_id: Int, offset_x: Int, offset_y: Int)
}

/// Drag-to-claim state for pool interactions.
pub type PoolDragState {
  PoolDragIdle
  PoolDragPendingRect
  PoolDragDragging(over_my_tasks: Bool, rect: Rect)
}

/// Scope selector kind for Plan surfaces.
pub type PlanScopeKind {
  PlanScopeProject
  PlanScopeLevel
  PlanScopeCard
}

/// Display mode for the Plan surface.
pub type PlanMode {
  PlanStructure
  PlanKanban
}

/// Inline card movement state for Plan / Structure.
pub type PlanMoveMode {
  PlanNotMoving
  PlanMovingCard(card_id: Int, destination_query: String)
}

/// Native drag state while the inline Plan movement mode is active.
pub type PlanMoveDragState {
  PlanMoveNotDragging
  PlanMoveDraggingCard(card_id: Int, over_destination: Option(MoveTarget))
}

/// Display mode for the Capabilities surface.
pub type PlanCapabilityMode {
  PlanCapabilityList
  PlanCapabilityMatrix
}

/// Card state filter for the Plan structure surface.
pub type PlanStatusFilter {
  PlanStatusAll
  PlanStatusDraft
  PlanStatusActive
  PlanStatusClosed
}

/// Sort order for the Plan structure surface.
pub type PlanSort {
  PlanSortPath
  PlanSortState
  PlanSortDueDate
  PlanSortPoolImpact
}

/// Rectangle geometry for hit testing.
pub type Rect {
  Rect(left: Int, top: Int, width: Int, height: Int)
}

/// Tests if a point (x, y) is inside the rectangle (inclusive bounds).
pub fn rect_contains_point(rect: Rect, x: Int, y: Int) -> Bool {
  let Rect(left: left, top: top, width: width, height: height) = rect
  x >= left && x <= left + width && y >= top && y <= top + height
}

/// Represents member pool state.
pub type Model {
  Model(
    view_mode: view_mode.ViewMode,
    member_plan_scope_kind: PlanScopeKind,
    member_plan_mode: PlanMode,
    member_plan_move_mode: PlanMoveMode,
    member_plan_move_drag: PlanMoveDragState,
    member_plan_move_in_flight: Bool,
    member_plan_move_error: Option(String),
    member_plan_capability_mode: PlanCapabilityMode,
    member_plan_scope_card_id: Option(Int),
    member_plan_scope_card_query: String,
    member_plan_show_closed: Option(Bool),
    member_plan_status_filter: PlanStatusFilter,
    member_plan_sort: PlanSort,
    member_plan_collapsed_cards: Dict(Int, Bool),
    member_card_depth_filter: Option(Int),
    member_tasks: Remote(List(Task)),
    member_tasks_pending: Int,
    member_tasks_by_project: Dict(Int, List(Task)),
    member_task_types: Remote(List(TaskType)),
    member_task_types_pending: Int,
    member_task_types_by_project: Dict(Int, List(TaskType)),
    member_cards_store: normalized_store.NormalizedStore(Int, Card),
    member_cards: Remote(List(Card)),
    member_task_mutation_in_flight: Bool,
    member_task_mutation_task_id: Option(Int),
    member_tasks_snapshot: Option(List(Task)),
    member_pool_visibility: PoolVisibility,
    member_filters_type_id: Option(Int),
    member_filters_capability_id: Option(Int),
    member_filters_q: String,
    member_capability_scope: capability_scope.CapabilityScope,
    member_pool_view_mode: pool_prefs.ViewMode,
    member_list_hide_closed: Bool,
    member_list_expanded_cards: Dict(Int, Bool),
    member_panel_expanded: Bool,
    member_create_dialog_mode: dialog_mode.DialogMode,
    member_create_title: String,
    member_create_description: String,
    member_create_priority: String,
    member_create_type_id: String,
    member_create_card_id: Option(Int),
    member_create_in_flight: Bool,
    member_create_error: Option(String),
    member_drag: DragState,
    member_pool_drag: PoolDragState,
    member_pool_touch_task_id: Option(Int),
    member_pool_touch_longpress: Option(Int),
    member_pool_touch_client_x: Int,
    member_pool_touch_client_y: Int,
    member_pool_preview_task_id: Option(Int),
    member_highlight_state: HighlightState,
    people_workload: Remote(List(PersonWorkload)),
    people_expansions: Dict(Int, people_state.RowExpansion),
    member_people_search_query: String,
    member_people_filter: people_state.PeopleVisibilityFilter,
    member_people_sort: people_state.PeopleSort,
  )
}

/// Provides default member pool state.
pub fn default_model() -> Model {
  Model(
    view_mode: view_mode.Pool,
    member_plan_scope_kind: PlanScopeProject,
    member_plan_mode: PlanStructure,
    member_plan_move_mode: PlanNotMoving,
    member_plan_move_drag: PlanMoveNotDragging,
    member_plan_move_in_flight: False,
    member_plan_move_error: option.None,
    member_plan_capability_mode: PlanCapabilityList,
    member_plan_scope_card_id: option.None,
    member_plan_scope_card_query: "",
    member_plan_show_closed: option.None,
    member_plan_status_filter: PlanStatusAll,
    member_plan_sort: PlanSortPath,
    member_plan_collapsed_cards: dict.new(),
    member_card_depth_filter: option.None,
    member_tasks: NotAsked,
    member_tasks_pending: 0,
    member_tasks_by_project: dict.new(),
    member_task_types: NotAsked,
    member_task_types_pending: 0,
    member_task_types_by_project: dict.new(),
    member_cards_store: normalized_store.new(),
    member_cards: NotAsked,
    member_task_mutation_in_flight: False,
    member_task_mutation_task_id: option.None,
    member_tasks_snapshot: option.None,
    member_pool_visibility: visibility.default(),
    member_filters_type_id: option.None,
    member_filters_capability_id: option.None,
    member_filters_q: "",
    member_capability_scope: capability_scope.default(),
    member_pool_view_mode: pool_prefs.Canvas,
    member_list_hide_closed: True,
    member_list_expanded_cards: dict.new(),
    member_panel_expanded: False,
    member_create_dialog_mode: dialog_mode.DialogClosed,
    member_create_title: "",
    member_create_description: "",
    member_create_priority: "3",
    member_create_type_id: "",
    member_create_card_id: option.None,
    member_create_in_flight: False,
    member_create_error: option.None,
    member_drag: DragIdle,
    member_pool_drag: PoolDragIdle,
    member_pool_touch_task_id: option.None,
    member_pool_touch_longpress: option.None,
    member_pool_touch_client_x: 0,
    member_pool_touch_client_y: 0,
    member_pool_preview_task_id: option.None,
    member_highlight_state: NoHighlight,
    people_workload: NotAsked,
    people_expansions: dict.new(),
    member_people_search_query: "",
    member_people_filter: people_state.ShowEveryone,
    member_people_sort: people_state.SortByAttention,
  )
}
