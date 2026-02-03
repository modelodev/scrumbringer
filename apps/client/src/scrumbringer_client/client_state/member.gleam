//// Member-specific client state model.

import gleam/dict.{type Dict}
import gleam/option.{type Option}

import domain/capability.{type Capability}
import domain/card.{type Card}
import domain/metrics.{type MyMetrics}
import domain/remote.{type Remote}
import domain/task.{
  type Task, type TaskDependency, type TaskNote, type WorkSessionsPayload,
}
import domain/task_status
import domain/task_type.{type TaskType}
import domain/view_mode

import scrumbringer_client/client_state/types as state_types
import scrumbringer_client/member_section
import scrumbringer_client/pool_prefs
import scrumbringer_client/state/normalized_store
import scrumbringer_client/ui/task_tabs

/// Represents MemberModel.
pub type MemberModel {
  MemberModel(
    member_section: member_section.MemberSection,
    view_mode: view_mode.ViewMode,
    member_work_sessions: Remote(WorkSessionsPayload),
    member_metrics: Remote(MyMetrics),
    member_now_working_in_flight: Bool,
    member_now_working_error: Option(String),
    now_working_tick: Int,
    now_working_tick_running: Bool,
    now_working_server_offset_ms: Int,
    member_tasks: Remote(List(Task)),
    member_tasks_pending: Int,
    member_tasks_by_project: Dict(Int, List(Task)),
    member_task_types: Remote(List(TaskType)),
    member_task_types_pending: Int,
    member_task_types_by_project: Dict(Int, List(TaskType)),
    member_cards_store: normalized_store.NormalizedStore(Int, Card),
    member_cards: Remote(List(Card)),
    member_capabilities: Remote(List(Capability)),
    member_task_mutation_in_flight: Bool,
    member_task_mutation_task_id: Option(Int),
    member_tasks_snapshot: Option(List(Task)),
    member_filters_status: Option(task_status.TaskStatus),
    member_filters_type_id: Option(Int),
    member_filters_capability_id: Option(Int),
    member_filters_q: String,
    member_quick_my_caps: Bool,
    member_pool_filters_visible: Bool,
    member_pool_view_mode: pool_prefs.ViewMode,
    member_list_hide_completed: Bool,
    member_list_expanded_cards: Dict(Int, Bool),
    member_panel_expanded: Bool,
    member_create_dialog_open: Bool,
    member_create_title: String,
    member_create_description: String,
    member_create_priority: String,
    member_create_type_id: String,
    member_create_card_id: Option(Int),
    member_create_in_flight: Bool,
    member_create_error: Option(String),
    member_my_capability_ids: Remote(List(Int)),
    member_my_capability_ids_edit: Dict(Int, Bool),
    member_my_capabilities_in_flight: Bool,
    member_my_capabilities_error: Option(String),
    member_positions_by_task: Dict(Int, #(Int, Int)),
    member_drag: state_types.DragState,
    member_canvas_left: Int,
    member_canvas_top: Int,
    member_pool_drag: state_types.PoolDragState,
    member_pool_touch_task_id: Option(Int),
    member_pool_touch_longpress: Option(Int),
    member_pool_touch_client_x: Int,
    member_pool_touch_client_y: Int,
    member_pool_preview_task_id: Option(Int),
    member_hover_notes_cache: Dict(Int, List(TaskNote)),
    member_hover_notes_pending: Dict(Int, Bool),
    member_position_edit_task: Option(Int),
    member_position_edit_x: String,
    member_position_edit_y: String,
    member_position_edit_in_flight: Bool,
    member_position_edit_error: Option(String),
    member_notes_task_id: Option(Int),
    member_notes: Remote(List(TaskNote)),
    member_note_content: String,
    member_note_in_flight: Bool,
    member_note_error: Option(String),
    member_note_dialog_open: Bool,
    card_detail_open: Option(Int),
    member_task_detail_tab: task_tabs.Tab,
    member_dependencies: Remote(List(TaskDependency)),
    member_dependency_dialog_open: Bool,
    member_dependency_search_query: String,
    member_dependency_candidates: Remote(List(Task)),
    member_dependency_selected_task_id: Option(Int),
    member_dependency_add_in_flight: Bool,
    member_dependency_add_error: Option(String),
    member_dependency_remove_in_flight: Option(Int),
    member_blocked_claim_task: Option(#(Int, Int)),
  )
}

/// Reset drag-related state on the member model.
pub fn reset_drag_state(member: MemberModel) -> MemberModel {
  MemberModel(
    ..member,
    member_drag: state_types.DragIdle,
    member_pool_drag: state_types.PoolDragIdle,
  )
}
