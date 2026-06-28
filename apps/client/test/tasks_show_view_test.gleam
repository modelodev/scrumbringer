import gleam/list
import gleam/option.{None, Some}
import gleam/string
import support/render_assertions

import domain/card.{type Card, Active, Card}
import domain/remote
import domain/task.{type Task, Task}
import domain/task/state as task_state
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/features/tasks/show/view as task_show
import scrumbringer_client/i18n/locale
import scrumbringer_client/ui/show_tabs

fn forbidden_fragment(parts: List(String)) -> String {
  string.join(parts, "")
}

pub fn task_show_renders_as_panel_not_modal_test() {
  let html =
    task_show.view_task_show(config())
    |> render_assertions.html

  render_assertions.contains(html, "task-show-panel")
  render_assertions.contains(html, "task-show-content")
  render_assertions.contains(html, "inspector-shell")
  render_assertions.contains(html, "data-testid=\"task-show\"")
  render_assertions.contains(html, "data-testid=\"entity-tabs\"")
  render_assertions.contains(html, "role=\"dialog\"")
  render_assertions.contains(html, "aria-modal=\"true\"")
  render_assertions.contains(html, "task-inspector-actions")
  render_assertions.contains(
    html,
    "data-testid=\"task-inspector-primary-claim\"",
  )
  assert_fragment_order(html, "task-inspector-header", "task-inspector-actions")
  assert_fragment_order(html, "task-inspector-actions", "task-show-tabs")
  render_assertions.not_contains(html, "role=\"complementary\"")
  render_assertions.not_contains(
    html,
    forbidden_fragment(["task", "-action-bar"]),
  )
  render_assertions.not_contains(html, "modal-backdrop")
}

pub fn task_show_header_uses_operational_headline_without_legacy_meta_test() {
  let html =
    task_show.view_task_show(config_with_parent_card())
    |> render_assertions.html

  render_assertions.contains(html, "Ready to claim · Release card")
  render_assertions.contains(html, "Operational summary")
  render_assertions.contains(html, "Feature")
  render_assertions.contains(html, "P2")
  render_assertions.not_contains(html, "task-meta-chip")
  render_assertions.not_contains(html, "task-meta-type")
  render_assertions.not_contains(html, "task-meta-priority")
  render_assertions.not_contains(html, "task-meta-status")
  render_assertions.not_contains(html, "task-meta-assignee")
  render_assertions.not_contains(html, "task-meta-due")
  render_assertions.not_contains(html, "task-meta-blocking")
  render_assertions.not_contains(
    html,
    "data-testid=\"task-show-status-indicator\"",
  )
}

pub fn task_show_contains_parent_navigation_in_open_in_menu_test() {
  let html =
    task_show.view_task_show(config_with_parent_card())
    |> render_assertions.html

  render_assertions.contains(html, "data-testid=\"inspector-open-in-trigger\"")
  render_assertions.contains(html, "inspector-open-in-menu")
  render_assertions.contains(html, "Open card")
  render_assertions.contains(html, "View in Plan")
  render_assertions.contains(
    html,
    "/app?project=1&amp;view=cards&amp;work_scope=card&amp;card=10",
  )
  render_assertions.not_contains(
    html,
    forbidden_fragment(["task", "-context-navigation"]),
  )
  render_assertions.not_contains(html, "task-open-in-menu")
}

pub fn task_show_editing_uses_footer_edit_actions_only_test() {
  let html =
    task_show.view_task_show(
      task_show.TaskShowConfig(
        ..config(),
        editor: task_show.TaskEditorConfig(
          ..editor_config(),
          editing: True,
          edit_title: "Prepare final release",
        ),
      ),
    )
    |> render_assertions.html

  render_assertions.contains(html, "task-show-edit-form")
  render_assertions.contains(html, "task-inspector-edit-actions")
  render_assertions.contains(html, ">Cancel<")
  let assert 1 = occurrences(html, ">Save<")
  render_assertions.not_contains(html, "Release back to Pool")
  render_assertions.not_contains(html, "Start working")
  render_assertions.not_contains(html, "Claim task")
  render_assertions.not_contains(
    html,
    "data-testid=\"task-inspector-primary-close\"",
  )
}

fn occurrences(source: String, fragment: String) -> Int {
  list.length(string.split(source, fragment)) - 1
}

fn assert_fragment_order(source: String, before: String, after: String) {
  let assert [_, rest, ..] = string.split(source, before)
  render_assertions.contains(rest, after)
}

fn config() -> task_show.TaskShowConfig(String) {
  task_show.TaskShowConfig(
    locale: locale.En,
    task_id: 42,
    task: Some(task()),
    parent_card: None,
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
    edit_card_query: "",
    edit_error: None,
    edit_in_flight: False,
    task_types: remote.Loaded([]),
    cards: [],
    depth_names: [],
    parent_card_title: Some("Release card"),
    on_edit_started: "edit",
    on_edit_cancelled: "cancel-edit",
    on_edit_title_changed: fn(_) { "title" },
    on_edit_description_changed: fn(_) { "description" },
    on_edit_priority_changed: fn(_) { "priority" },
    on_edit_type_id_changed: fn(_) { "type" },
    on_edit_card_id_changed: fn(_) { "card" },
    on_edit_card_query_changed: fn(_) { "card-query" },
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
