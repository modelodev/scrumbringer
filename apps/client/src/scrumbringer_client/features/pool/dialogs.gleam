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
//// - Dialog state management (see features/pool/update.gleam, features/tasks/detail_update.gleam)
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
import scrumbringer_client/features/tasks/detail_editor
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/ui/task_tabs

pub type TaskDetailsConfig(msg) {
  TaskDetailsConfig(
    locale: Locale,
    task_id: Int,
    task: opt.Option(Task),
    current_user_id: opt.Option(Int),
    active_tab: task_tabs.Tab,
    metrics: Remote(TaskModalMetrics),
    dependencies: TaskDependenciesConfig(msg),
    editor: TaskEditorConfig(msg),
    notes: TaskNotesConfig(msg),
    actions: TaskActionsConfig(msg),
    on_close: msg,
    on_tab_clicked: fn(task_tabs.Tab) -> msg,
  )
}

pub type TaskDependenciesConfig(msg) {
  TaskDependenciesConfig(
    items: Remote(List(TaskDependency)),
    dialog_mode: dialog_mode.DialogMode,
    search_query: String,
    candidates: Remote(List(Task)),
    selected_task_id: opt.Option(Int),
    add_in_flight: Bool,
    add_error: opt.Option(String),
    remove_in_flight: opt.Option(Int),
    on_dialog_opened: msg,
    on_dialog_closed: msg,
    on_add_submitted: msg,
    on_search_changed: fn(String) -> msg,
    on_selected: fn(Int) -> msg,
    on_remove: fn(Int) -> msg,
  )
}

pub type TaskEditorConfig(msg) {
  TaskEditorConfig(
    editing: Bool,
    edit_title: String,
    edit_description: String,
    edit_priority: String,
    edit_type_id: String,
    edit_card_id: String,
    edit_error: opt.Option(String),
    edit_in_flight: Bool,
    task_types: Remote(List(TaskType)),
    cards: List(Card),
    parent_card_title: opt.Option(String),
    on_edit_started: msg,
    on_edit_cancelled: msg,
    on_edit_title_changed: fn(String) -> msg,
    on_edit_description_changed: fn(String) -> msg,
    on_edit_priority_changed: fn(String) -> msg,
    on_edit_type_id_changed: fn(String) -> msg,
    on_edit_card_id_changed: fn(String) -> msg,
    on_edit_submitted: msg,
  )
}

pub type TaskNotesConfig(msg) {
  TaskNotesConfig(
    can_manage: Bool,
    items: Remote(List(TaskNote)),
    dialog_mode: dialog_mode.DialogMode,
    content: String,
    error: opt.Option(String),
    in_flight: Bool,
    delete_in_flight: opt.Option(Int),
    on_dialog_opened: msg,
    on_dialog_closed: msg,
    on_content_changed: fn(String) -> msg,
    on_submitted: msg,
    on_delete: fn(Int) -> msg,
  )
}

pub type TaskActionsConfig(msg) {
  TaskActionsConfig(
    disable_actions: Bool,
    on_claim: fn(Int, Int) -> msg,
    on_release: fn(Int, Int) -> msg,
    on_complete: fn(Int, Int) -> msg,
  )
}

pub fn view_task_details(config: TaskDetailsConfig(msg)) -> Element(msg) {
  div([attribute.class("task-detail-modal")], [
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
            view_task_header(config),
            view_task_tabs(config),
          ],
        ),
        div([attribute.class("modal-body task-detail-body")], [
          view_task_tab_content(config),
        ]),
        view_task_footer(config),
      ],
    ),
  ])
}

fn view_task_header(config: TaskDetailsConfig(msg)) -> Element(msg) {
  task_detail_header.view(task_detail_header.Config(
    locale: config.locale,
    task: config.task,
    on_close: config.on_close,
  ))
}

fn view_task_tabs(config: TaskDetailsConfig(msg)) -> Element(msg) {
  task_detail_tabs.view(task_detail_tabs.Config(
    locale: config.locale,
    active_tab: config.active_tab,
    notes: config.notes.items,
    on_tab_clicked: config.on_tab_clicked,
  ))
}

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
    dependencies: config.dependencies.items,
    dialog_mode: config.dependencies.dialog_mode,
    search_query: config.dependencies.search_query,
    candidates: config.dependencies.candidates,
    selected_task_id: config.dependencies.selected_task_id,
    add_in_flight: config.dependencies.add_in_flight,
    add_error: config.dependencies.add_error,
    remove_in_flight: config.dependencies.remove_in_flight,
    on_dialog_opened: config.dependencies.on_dialog_opened,
    on_dialog_closed: config.dependencies.on_dialog_closed,
    on_add_submitted: config.dependencies.on_add_submitted,
    on_search_changed: config.dependencies.on_search_changed,
    on_selected: config.dependencies.on_selected,
    on_remove: config.dependencies.on_remove,
  ))
}

fn view_task_details_tab(config: TaskDetailsConfig(msg)) -> Element(msg) {
  task_detail_details.view(details_config(config))
}

fn details_config(
  config: TaskDetailsConfig(msg),
) -> task_detail_details.Config(msg) {
  task_detail_details.Config(
    locale: config.locale,
    task: config.task,
    dependencies: config.dependencies.items,
    parent_card_title: config.editor.parent_card_title,
    editor: editor_config(config),
  )
}

fn editor_config(config: TaskDetailsConfig(msg)) -> detail_editor.Config(msg) {
  detail_editor.Config(
    locale: config.locale,
    current_user_id: config.current_user_id,
    editing: config.editor.editing,
    edit_title: config.editor.edit_title,
    edit_description: config.editor.edit_description,
    edit_priority: config.editor.edit_priority,
    edit_type_id: config.editor.edit_type_id,
    edit_card_id: config.editor.edit_card_id,
    edit_error: config.editor.edit_error,
    edit_in_flight: config.editor.edit_in_flight,
    task_types: config.editor.task_types,
    cards: config.editor.cards,
    on_edit_started: config.editor.on_edit_started,
    on_edit_cancelled: config.editor.on_edit_cancelled,
    on_title_changed: config.editor.on_edit_title_changed,
    on_description_changed: config.editor.on_edit_description_changed,
    on_priority_changed: config.editor.on_edit_priority_changed,
    on_type_id_changed: config.editor.on_edit_type_id_changed,
    on_card_id_changed: config.editor.on_edit_card_id_changed,
    on_submitted: config.editor.on_edit_submitted,
  )
}

fn view_notes(config: TaskDetailsConfig(msg)) -> Element(msg) {
  task_notes.view(task_notes.Config(
    locale: config.locale,
    current_user_id: config.current_user_id,
    can_manage_notes: config.notes.can_manage,
    notes: config.notes.items,
    dialog_mode: config.notes.dialog_mode,
    note_content: config.notes.content,
    note_error: config.notes.error,
    note_in_flight: config.notes.in_flight,
    delete_in_flight: config.notes.delete_in_flight,
    on_dialog_opened: config.notes.on_dialog_opened,
    on_dialog_closed: config.notes.on_dialog_closed,
    on_content_changed: config.notes.on_content_changed,
    on_submitted: config.notes.on_submitted,
    on_delete: config.notes.on_delete,
  ))
}

fn view_task_footer(config: TaskDetailsConfig(msg)) -> Element(msg) {
  task_detail_footer.view(task_detail_footer.Config(
    locale: config.locale,
    task: config.task,
    current_user_id: config.current_user_id,
    disable_actions: config.actions.disable_actions,
    editing: config.editor.editing,
    edit_in_flight: config.editor.edit_in_flight,
    edit_dirty: edit_dirty(config),
    on_close: config.on_close,
    on_edit_cancelled: config.editor.on_edit_cancelled,
    on_edit_submitted: config.editor.on_edit_submitted,
    on_claim: config.actions.on_claim,
    on_release: config.actions.on_release,
    on_complete: config.actions.on_complete,
  ))
}

fn edit_dirty(config: TaskDetailsConfig(msg)) -> Bool {
  case config.task {
    opt.Some(task) -> task_detail_details.is_dirty(details_config(config), task)
    opt.None -> False
  }
}
