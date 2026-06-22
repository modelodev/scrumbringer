import gleam/option.{None, Some}
import gleam/string
import lustre/element

import domain/remote
import domain/task.{type Task, Task}
import domain/task_state
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/features/pool/dialogs
import scrumbringer_client/i18n/locale
import scrumbringer_client/ui/show_tabs

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

pub fn task_show_renders_as_panel_not_modal_test() {
  let html =
    dialogs.view_task_details(config())
    |> element.to_document_string

  assert_contains(html, "task-show-panel")
  assert_contains(html, "task-show-content")
  assert_contains(html, "role=\"complementary\"")
  assert_contains(html, "task-action-bar")
  assert_not_contains(html, "aria-modal=\"true\"")
  assert_not_contains(html, "modal-backdrop")
}

fn config() -> dialogs.TaskDetailsConfig(String) {
  dialogs.TaskDetailsConfig(
    locale: locale.En,
    task_id: 42,
    task: Some(task()),
    parent_card: None,
    capability_name: Some("Backend"),
    current_user_id: Some(7),
    active_tab: show_tabs.TaskDetailsTab,
    dependencies: dependencies_config(),
    editor: editor_config(),
    notes: notes_config(),
    activity: remote.Loaded([]),
    activity_total: 0,
    activity_loading_more: False,
    on_activity_more: "activity-more",
    actions: dialogs.TaskActionsConfig(
      disable_actions: False,
      on_claim: fn(_, _) { "claim" },
      on_release: fn(_, _) { "release" },
      on_complete: fn(_, _) { "complete" },
      on_delete: fn(_) { "delete" },
    ),
    on_close: "close",
    on_open_parent_card: fn(_) { "open-card" },
    on_tab_clicked: fn(_) { "tab" },
  )
}

fn dependencies_config() -> dialogs.TaskDependenciesConfig(String) {
  dialogs.TaskDependenciesConfig(
    items: remote.Loaded([]),
    dialog_mode: dialog_mode.DialogClosed,
    search_query: "",
    candidates: remote.NotAsked,
    selected_task_id: None,
    add_in_flight: False,
    add_error: None,
    remove_in_flight: None,
    on_dialog_opened: "open-dependencies",
    on_dialog_closed: "close-dependencies",
    on_add_submitted: "add-dependency",
    on_search_changed: fn(_) { "search-dependencies" },
    on_selected: fn(_) { "select-dependency" },
    on_remove: fn(_) { "remove-dependency" },
  )
}

fn editor_config() -> dialogs.TaskEditorConfig(String) {
  dialogs.TaskEditorConfig(
    editing: False,
    edit_title: "Prepare release",
    edit_description: "Task description",
    edit_priority: "2",
    edit_type_id: "1",
    edit_card_id: "10",
    edit_error: None,
    edit_in_flight: False,
    task_types: remote.Loaded([]),
    cards: [],
    parent_card_title: Some("Release card"),
    on_edit_started: "edit",
    on_edit_cancelled: "cancel-edit",
    on_edit_title_changed: fn(_) { "title" },
    on_edit_description_changed: fn(_) { "description" },
    on_edit_priority_changed: fn(_) { "priority" },
    on_edit_type_id_changed: fn(_) { "type" },
    on_edit_card_id_changed: fn(_) { "card" },
    on_edit_submitted: "submit-edit",
  )
}

fn notes_config() -> dialogs.TaskNotesConfig(String) {
  dialogs.TaskNotesConfig(
    can_manage: False,
    items: remote.Loaded([]),
    dialog_mode: dialog_mode.DialogClosed,
    content: "",
    error: None,
    in_flight: False,
    delete_in_flight: None,
    pin_in_flight: None,
    on_dialog_opened: "open-note",
    on_dialog_closed: "close-note",
    on_content_changed: fn(_) { "content" },
    on_submitted: "submit-note",
    on_delete: fn(_) { "delete-note" },
    on_pin_toggle: fn(_, _) { "pin-note" },
  )
}

fn task() -> Task {
  Task(
    id: 42,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Feature", icon: "sparkles"),
    ongoing_by: None,
    title: "Prepare release",
    description: Some("Task description"),
    priority: 2,
    state: task_state.Available,
    created_by: 7,
    created_at: "2026-06-01T10:00:00Z",
    due_date: None,
    version: 3,
    parent_card_id: None,
    card_id: Some(10),
    card_title: Some("Release card"),
    card_color: None,
    has_new_notes: False,
    blocked_count: 0,
    dependencies: [],
  )
}
