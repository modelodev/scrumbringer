//// Member pool state.

import gleam/dict.{type Dict}
import gleam/option.{type Option}

import domain/card.{type Card}
import domain/milestone.{type MilestoneProgress}
import domain/project.{type ProjectMember}
import domain/remote.{type Remote, NotAsked}
import domain/task.{type Task}
import domain/task_status
import domain/task_type.{type TaskType}
import domain/view_mode
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/client_state/member/milestone_details_tab
import scrumbringer_client/client_state/types as state_types
import scrumbringer_client/member_section
import scrumbringer_client/pool_prefs
import scrumbringer_client/state/normalized_store
import scrumbringer_client/ui/task_tabs

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

pub type MilestoneDialog {
  MilestoneDialogClosed
  MilestoneDialogView(id: Int)
  MilestoneDialogActivate(id: Int)
  MilestoneDialogEdit(id: Int, name: String, description: String)
  MilestoneDialogDelete(id: Int, name: String)
}

pub type MilestoneDragItem {
  MilestoneDragCard(card_id: Int, from_milestone_id: Int)
  MilestoneDragTask(task_id: Int, from_milestone_id: Int)
}

/// Represents member pool state.
pub type Model {
  Model(
    member_section: member_section.MemberSection,
    view_mode: view_mode.ViewMode,
    member_tasks: Remote(List(Task)),
    member_tasks_pending: Int,
    member_tasks_by_project: Dict(Int, List(Task)),
    member_task_types: Remote(List(TaskType)),
    member_task_types_pending: Int,
    member_task_types_by_project: Dict(Int, List(TaskType)),
    member_cards_store: normalized_store.NormalizedStore(Int, Card),
    member_cards: Remote(List(Card)),
    member_milestones_store: normalized_store.NormalizedStore(
      Int,
      MilestoneProgress,
    ),
    member_milestones: Remote(List(MilestoneProgress)),
    member_milestones_show_completed: Bool,
    member_milestones_show_empty: Bool,
    member_milestones_expanded: Dict(Int, Bool),
    member_milestone_activate_in_flight_id: Option(Int),
    member_milestone_dialog: MilestoneDialog,
    member_milestone_dialog_in_flight: Bool,
    member_milestone_dialog_error: Option(String),
    member_milestone_details_tab: milestone_details_tab.MilestoneDetailsTab,
    member_milestone_drag_item: Option(MilestoneDragItem),
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
    member_create_dialog_mode: dialog_mode.DialogMode,
    member_create_title: String,
    member_create_description: String,
    member_create_priority: String,
    member_create_type_id: String,
    member_create_card_id: Option(Int),
    member_create_milestone_id: Option(Int),
    member_create_in_flight: Bool,
    member_create_error: Option(String),
    member_drag: state_types.DragState,
    member_pool_drag: state_types.PoolDragState,
    member_pool_touch_task_id: Option(Int),
    member_pool_touch_longpress: Option(Int),
    member_pool_touch_client_x: Int,
    member_pool_touch_client_y: Int,
    member_pool_preview_task_id: Option(Int),
    card_detail_open: Option(Int),
    member_task_detail_tab: task_tabs.Tab,
    member_blocked_claim_task: Option(#(Int, Int)),
    member_highlight_state: HighlightState,
    people_roster: Remote(List(ProjectMember)),
    people_expansions: Dict(Int, people_state.RowExpansion),
  )
}

/// Provides default member pool state.
pub fn default_model() -> Model {
  Model(
    member_section: member_section.Pool,
    view_mode: view_mode.Pool,
    member_tasks: NotAsked,
    member_tasks_pending: 0,
    member_tasks_by_project: dict.new(),
    member_task_types: NotAsked,
    member_task_types_pending: 0,
    member_task_types_by_project: dict.new(),
    member_cards_store: normalized_store.new(),
    member_cards: NotAsked,
    member_milestones_store: normalized_store.new(),
    member_milestones: NotAsked,
    member_milestones_show_completed: False,
    member_milestones_show_empty: False,
    member_milestones_expanded: dict.new(),
    member_milestone_activate_in_flight_id: option.None,
    member_milestone_dialog: MilestoneDialogClosed,
    member_milestone_dialog_in_flight: False,
    member_milestone_dialog_error: option.None,
    member_milestone_details_tab: milestone_details_tab.MilestoneOverviewTab,
    member_milestone_drag_item: option.None,
    member_task_mutation_in_flight: False,
    member_task_mutation_task_id: option.None,
    member_tasks_snapshot: option.None,
    member_filters_status: option.None,
    member_filters_type_id: option.None,
    member_filters_capability_id: option.None,
    member_filters_q: "",
    member_quick_my_caps: True,
    member_pool_filters_visible: False,
    member_pool_view_mode: pool_prefs.Canvas,
    member_list_hide_completed: True,
    member_list_expanded_cards: dict.new(),
    member_panel_expanded: False,
    member_create_dialog_mode: dialog_mode.DialogClosed,
    member_create_title: "",
    member_create_description: "",
    member_create_priority: "3",
    member_create_type_id: "",
    member_create_card_id: option.None,
    member_create_milestone_id: option.None,
    member_create_in_flight: False,
    member_create_error: option.None,
    member_drag: state_types.DragIdle,
    member_pool_drag: state_types.PoolDragIdle,
    member_pool_touch_task_id: option.None,
    member_pool_touch_longpress: option.None,
    member_pool_touch_client_x: 0,
    member_pool_touch_client_y: 0,
    member_pool_preview_task_id: option.None,
    card_detail_open: option.None,
    member_task_detail_tab: task_tabs.DetailsTab,
    member_blocked_claim_task: option.None,
    member_highlight_state: NoHighlight,
    people_roster: NotAsked,
    people_expansions: dict.new(),
  )
}
