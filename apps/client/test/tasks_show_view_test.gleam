import gleam/option.{None, Some}
import gleam/string
import lustre/element

import domain/card.{type Card, Active, Card}
import domain/remote
import domain/task.{type Task, Task}
import domain/task/state as task_state
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/features/tasks/show/view as task_show
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
    task_show.view_task_show(config())
    |> element.to_document_string

  assert_contains(html, "task-show-panel")
  assert_contains(html, "task-show-content")
  assert_contains(html, "data-testid=\"task-show\"")
  assert_contains(html, "data-testid=\"entity-tabs\"")
  assert_contains(html, "role=\"complementary\"")
  assert_contains(html, "task-action-bar")
  assert_not_contains(html, "aria-modal=\"true\"")
  assert_not_contains(html, "modal-backdrop")
}

pub fn task_show_renders_parent_card_navigation_in_header_test() {
  let html =
    task_show.view_task_show(config_with_parent_card())
    |> element.to_document_string

  assert_contains(html, "task-context-navigation")
  assert_contains(html, "Open in")
  assert_contains(html, "Open card")
  assert_contains(html, "View in Plan")
  assert_contains(
    html,
    "/app?project=1&amp;view=cards&amp;work_scope=card&amp;card=10",
  )
}

fn config() -> task_show.TaskShowConfig(String) {
  task_show.TaskShowConfig(
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
    actions: task_show.TaskActionsConfig(
      disable_actions: False,
      on_claim: fn(_, _) { "claim" },
      on_start_work: fn(_) { "start-work" },
      on_release: fn(_, _) { "release" },
      on_task_close: fn(_, _) { "task-close" },
      on_delete: fn(_) { "delete" },
    ),
    on_close: "close",
    on_open_parent_card: fn(_) { "open-card" },
    on_tab_clicked: fn(_) { "tab" },
  )
}

fn config_with_parent_card() -> task_show.TaskShowConfig(String) {
  task_show.TaskShowConfig(..config(), parent_card: Some(parent_card()))
}

fn parent_card() -> Card {
  Card(
    id: 10,
    project_id: 1,
    parent_card_id: None,
    title: "Release card",
    description: "Release",
    color: None,
    state: Active,
    task_count: 1,
    closed_count: 0,
    created_by: 7,
    created_at: "2026-03-20T10:00:00Z",
    due_date: None,
    has_new_notes: False,
  )
}

fn dependencies_config() -> task_show.TaskDependenciesConfig(String) {
  task_show.TaskDependenciesConfig(
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

fn editor_config() -> task_show.TaskEditorConfig(String) {
  task_show.TaskEditorConfig(
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

fn notes_config() -> task_show.TaskNotesConfig(String) {
  task_show.TaskNotesConfig(
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
    automation_origin: None,
  )
}
