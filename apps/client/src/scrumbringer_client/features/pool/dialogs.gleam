//// Pool Dialog Components for Scrumbringer client.
////
//// ## Mission
////
//// Render modal dialogs for the pool view: task details.
////
//// ## Responsibilities
////
//// - Task details modal with notes list
////
//// ## Non-responsibilities
////
//// - Task creation dialog wiring (see features/pool/create_dialog_config.gleam)
//// - Position edit dialog wiring (see features/pool/position_edit_dialog_config.gleam)
//// - Dialog state management (see features/pool/update.gleam, features/tasks/update.gleam)
//// - Form validation (handled by update handlers)
////
//// ## Relations
////
//// - **features/pool/view.gleam**: Imports and renders these dialogs

import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div}
import lustre/event

import domain/card.{type Card}
import domain/metrics.{type TaskModalMetrics}
import domain/milestone.{type MilestoneProgress}
import domain/remote.{type Remote}
import domain/task.{type Task, type TaskDependency, type TaskNote}
import domain/task_type.{type TaskType}

import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/features/pool/task_dependencies
import scrumbringer_client/features/pool/task_detail_details
import scrumbringer_client/features/pool/task_detail_footer
import scrumbringer_client/features/pool/task_detail_header
import scrumbringer_client/features/pool/task_detail_tabs
import scrumbringer_client/features/pool/task_metrics
import scrumbringer_client/features/pool/task_notes
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/ui/task_tabs

// =============================================================================
// Task Details Dialog (Story 5.4.1: Unified modal with tabs)
// =============================================================================

pub type TaskDetailsConfig(msg) {
  TaskDetailsConfig(
    locale: Locale,
    task_id: Int,
    task: opt.Option(Task),
    current_user_id: opt.Option(Int),
    can_manage_notes: Bool,
    active_tab: task_tabs.Tab,
    notes: Remote(List(TaskNote)),
    metrics: Remote(TaskModalMetrics),
    dependencies: Remote(List(TaskDependency)),
    dependency_dialog_mode: dialog_mode.DialogMode,
    dependency_search_query: String,
    dependency_candidates: Remote(List(Task)),
    dependency_selected_task_id: opt.Option(Int),
    dependency_add_in_flight: Bool,
    dependency_add_error: opt.Option(String),
    dependency_remove_in_flight: opt.Option(Int),
    editing: Bool,
    edit_title: String,
    edit_description: String,
    edit_priority: String,
    edit_type_id: String,
    edit_card_id: String,
    edit_milestone_id: String,
    edit_error: opt.Option(String),
    edit_in_flight: Bool,
    task_types: Remote(List(TaskType)),
    cards: List(Card),
    milestones: Remote(List(MilestoneProgress)),
    parent_card_title: opt.Option(String),
    note_dialog_mode: dialog_mode.DialogMode,
    note_content: String,
    note_error: opt.Option(String),
    note_in_flight: Bool,
    note_delete_in_flight: opt.Option(Int),
    disable_actions: Bool,
    on_close: msg,
    on_tab_clicked: fn(task_tabs.Tab) -> msg,
    on_dependency_dialog_opened: msg,
    on_dependency_dialog_closed: msg,
    on_dependency_add_submitted: msg,
    on_dependency_search_changed: fn(String) -> msg,
    on_dependency_selected: fn(Int) -> msg,
    on_dependency_remove: fn(Int) -> msg,
    on_edit_started: msg,
    on_edit_cancelled: msg,
    on_edit_title_changed: fn(String) -> msg,
    on_edit_description_changed: fn(String) -> msg,
    on_edit_priority_changed: fn(String) -> msg,
    on_edit_type_id_changed: fn(String) -> msg,
    on_edit_card_id_changed: fn(String) -> msg,
    on_edit_milestone_id_changed: fn(String) -> msg,
    on_edit_submitted: msg,
    on_note_dialog_opened: msg,
    on_note_dialog_closed: msg,
    on_note_content_changed: fn(String) -> msg,
    on_note_submitted: msg,
    on_note_delete: fn(Int) -> msg,
    on_claim: fn(Int, Int) -> msg,
    on_release: fn(Int, Int) -> msg,
    on_complete: fn(Int, Int) -> msg,
  )
}

/// Renders the task details modal with header, tabs, and content.
/// AC1: Shows task title, type, priority, status
/// AC2: Tab system (DETALLES | NOTAS)
/// AC7: Backdrop click-to-close
/// AC8: Close button [×]
pub fn view_task_details(config: TaskDetailsConfig(msg)) -> Element(msg) {
  div([attribute.class("task-detail-modal")], [
    // AC7: Backdrop that closes on click
    div(
      [
        attribute.class("modal-backdrop"),
        event.on_click(config.on_close),
      ],
      [],
    ),
    div(
      [
        attribute.class("modal-content task-detail-content"),
        attribute.attribute("role", "dialog"),
        attribute.attribute("aria-modal", "true"),
        attribute.attribute("aria-labelledby", "task-detail-title"),
      ],
      [
        div(
          [
            attribute.class("modal-header-block detail-header-block"),
          ],
          [
            // AC1, AC8: Header with task info and close button
            view_task_header(config),
            // AC2: Tab system
            view_task_tabs(config),
          ],
        ),
        div([attribute.class("modal-body task-detail-body")], [
          // Content based on active tab
          view_task_tab_content(config),
        ]),
        // Footer
        view_task_footer(config),
      ],
    ),
  ])
}

/// Task header with title, type, priority, status (AC1)
fn view_task_header(config: TaskDetailsConfig(msg)) -> Element(msg) {
  task_detail_header.view(task_detail_header.Config(
    locale: config.locale,
    task: config.task,
    on_close: config.on_close,
  ))
}

/// Tab system for task detail (AC2)
fn view_task_tabs(config: TaskDetailsConfig(msg)) -> Element(msg) {
  task_detail_tabs.view(task_detail_tabs.Config(
    locale: config.locale,
    active_tab: config.active_tab,
    notes: config.notes,
    on_tab_clicked: config.on_tab_clicked,
  ))
}

/// Tab content based on active tab (AC3, AC4)
fn view_task_tab_content(config: TaskDetailsConfig(msg)) -> Element(msg) {
  let panel = case config.active_tab {
    task_tabs.TasksTab ->
      div([attribute.class("task-detail-grid detail-grid")], [
        view_task_details_tab(config),
        view_dependencies(config),
      ])
    task_tabs.NotesTab -> view_notes(config)
    task_tabs.MetricsTab -> view_task_metrics(config)
  }

  task_detail_tabs.panel(config.active_tab, panel)
}

fn view_task_metrics(config: TaskDetailsConfig(msg)) -> Element(msg) {
  task_metrics.view(task_metrics.Config(
    locale: config.locale,
    metrics: config.metrics,
  ))
}

/// Renders the dependencies section for a task.
fn view_dependencies(config: TaskDetailsConfig(msg)) -> Element(msg) {
  task_dependencies.view(task_dependencies.Config(
    locale: config.locale,
    task_id: config.task_id,
    task: config.task,
    dependencies: config.dependencies,
    dialog_mode: config.dependency_dialog_mode,
    search_query: config.dependency_search_query,
    candidates: config.dependency_candidates,
    selected_task_id: config.dependency_selected_task_id,
    add_in_flight: config.dependency_add_in_flight,
    add_error: config.dependency_add_error,
    remove_in_flight: config.dependency_remove_in_flight,
    on_dialog_opened: config.on_dependency_dialog_opened,
    on_dialog_closed: config.on_dependency_dialog_closed,
    on_add_submitted: config.on_dependency_add_submitted,
    on_search_changed: config.on_dependency_search_changed,
    on_selected: config.on_dependency_selected,
    on_remove: config.on_dependency_remove,
  ))
}

/// Details tab content (AC3)
fn view_task_details_tab(config: TaskDetailsConfig(msg)) -> Element(msg) {
  task_detail_details.view(task_detail_details.Config(
    locale: config.locale,
    current_user_id: config.current_user_id,
    task: config.task,
    editing: config.editing,
    edit_title: config.edit_title,
    edit_description: config.edit_description,
    edit_priority: config.edit_priority,
    edit_type_id: config.edit_type_id,
    edit_card_id: config.edit_card_id,
    edit_milestone_id: config.edit_milestone_id,
    edit_error: config.edit_error,
    edit_in_flight: config.edit_in_flight,
    task_types: config.task_types,
    cards: config.cards,
    milestones: config.milestones,
    parent_card_title: config.parent_card_title,
    on_edit_started: config.on_edit_started,
    on_edit_cancelled: config.on_edit_cancelled,
    on_title_changed: config.on_edit_title_changed,
    on_description_changed: config.on_edit_description_changed,
    on_priority_changed: config.on_edit_priority_changed,
    on_type_id_changed: config.on_edit_type_id_changed,
    on_card_id_changed: config.on_edit_card_id_changed,
    on_milestone_id_changed: config.on_edit_milestone_id_changed,
    on_submitted: config.on_edit_submitted,
  ))
}

/// Renders the notes section for a task.
/// Story 5.4 UX: Dialog-based note creation (unified with card notes pattern).
fn view_notes(config: TaskDetailsConfig(msg)) -> Element(msg) {
  task_notes.view(task_notes.Config(
    locale: config.locale,
    current_user_id: config.current_user_id,
    can_manage_notes: config.can_manage_notes,
    notes: config.notes,
    dialog_mode: config.note_dialog_mode,
    note_content: config.note_content,
    note_error: config.note_error,
    note_in_flight: config.note_in_flight,
    delete_in_flight: config.note_delete_in_flight,
    on_dialog_opened: config.on_note_dialog_opened,
    on_dialog_closed: config.on_note_dialog_closed,
    on_content_changed: config.on_note_content_changed,
    on_submitted: config.on_note_submitted,
    on_delete: config.on_note_delete,
  ))
}

fn view_task_footer(config: TaskDetailsConfig(msg)) -> Element(msg) {
  task_detail_footer.view(task_detail_footer.Config(
    locale: config.locale,
    task: config.task,
    current_user_id: config.current_user_id,
    disable_actions: config.disable_actions,
    on_close: config.on_close,
    on_claim: config.on_claim,
    on_release: config.on_release,
    on_complete: config.on_complete,
  ))
}
