import domain/card
import domain/org_role
import domain/task.{type Task, Task}
import domain/task/state as task_state
import domain/task_type.{TaskTypeInline}
import domain/user.{User}
import gleam/option.{None, Some}
import gleam/string
import lustre/element

import scrumbringer_client/features/layout/right_panel
import scrumbringer_client/i18n/locale as i18n_locale
import scrumbringer_client/theme

fn assert_contains(html: String, text: String) {
  let assert True = string.contains(html, text)
}

fn assert_not_contains(html: String, text: String) {
  let assert False = string.contains(html, text)
}

fn base_config(
  my_tasks: List(Task),
  active_tasks: List(right_panel.ActiveTaskInfo),
  my_cards: List(right_panel.MyCardProgress),
) -> right_panel.RightPanelConfig(Int) {
  right_panel.RightPanelConfig(
    locale: i18n_locale.En,
    user: None,
    my_tasks: my_tasks,
    my_cards: my_cards,
    active_tasks: active_tasks,
    task_card_color: fn(task) { task.card_color },
    on_task_start: fn(id) { id },
    on_task_pause: fn(id) { id },
    on_task_close: fn(id) { id },
    on_task_release: fn(id) { id },
    on_task_click: fn(id) { id },
    on_card_click: fn(id) { id },
    on_logout: 0,
    drag_armed: False,
    drag_over_my_tasks: False,
    preferences_popup_open: False,
    on_preferences_toggle: 0,
    current_theme: theme.Default,
    on_theme_change: fn(_) { 0 },
    on_locale_change: fn(_) { 0 },
    disable_actions: False,
  )
}

fn sample_task(state: task_state.TaskExecutionState) -> Task {
  Task(
    id: 1,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Bug", icon: "bug-ant"),
    ongoing_by: None,
    title: "Fix login",
    description: None,
    priority: 3,
    state: state,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    due_date: None,
    version: 1,
    parent_card_id: None,
    card_id: Some(1),
    card_title: Some("Sprint"),
    card_color: Some(card.Blue),
    has_new_notes: False,
    blocked_count: 0,
    dependencies: [],
    automation_origin: None,
  )
}

pub fn right_panel_active_task_renders_border_and_icon_test() {
  let active =
    right_panel.ActiveTaskInfo(
      task_id: 1,
      task_title: "Fix login",
      task_type_icon: "bug-ant",
      card_color: Some(card.Blue),
      elapsed_display: "00:10",
      is_paused: False,
    )

  let html =
    base_config([], [active], [])
    |> right_panel.view
    |> element.to_document_string

  assert_contains(html, "active-task-card card-border-blue")
  assert_contains(html, "task-type-icon")
  assert_contains(html, "task-timer")
  assert_contains(html, "title=\"Fix login\"")
  assert_contains(html, "Close task")
  assert_not_contains(html, "aria-label=\"Complete\"")
}

pub fn right_panel_my_task_renders_border_and_actions_test() {
  let task =
    sample_task(task_state.Claimed(
      claimed_by: 1,
      claimed_at: "2026-01-01T00:00:00Z",
      mode: task_state.Taken,
    ))

  let html =
    base_config([task], [], [])
    |> right_panel.view
    |> element.to_document_string

  assert_contains(html, "task-item card-border-blue")
  assert_contains(html, "task-card-identity-swatch")
  assert_contains(html, "my-task-start-btn")
  assert_contains(html, "my-task-release-btn")
  assert_contains(html, "task-type-icon")
  assert_contains(html, "type=\"button\"")
  assert_contains(html, "aria-label=\"Open task: Fix login\"")
  assert_contains(html, "title=\"Fix login\"")
}

pub fn right_panel_my_cards_renders_border_and_progress_test() {
  let card =
    right_panel.MyCardProgress(
      card_id: 1,
      card_title: "Sprint",
      card_color: Some(card.Blue),
      closed: 1,
      total: 3,
    )

  let html =
    base_config([], [], [card])
    |> right_panel.view
    |> element.to_document_string

  assert_contains(html, "my-card-item card-border-blue")
  assert_contains(html, "1 of 3 tasks closed")
  assert_contains(html, "type=\"button\"")
  assert_contains(html, "aria-label=\"Context: Sprint\"")
  assert_contains(html, "title=\"Sprint\"")
}

pub fn right_panel_preferences_popup_is_accessible_dialog_test() {
  let html =
    right_panel.RightPanelConfig(
      ..base_config([], [], []),
      preferences_popup_open: True,
    )
    |> right_panel.view
    |> element.to_document_string

  assert_contains(html, "role=\"dialog\"")
  assert_contains(html, "aria-modal=\"true\"")
  assert_contains(html, "aria-labelledby=\"preferences-popup-title\"")
  assert_contains(html, "id=\"preferences-popup-title\"")
  assert_contains(html, "aria-label=\"Close\"")
  assert_contains(html, "btn-global-action")
  assert_contains(html, "btn-icon")
  assert_contains(html, "Theme")
  assert_contains(html, "Language")
}

pub fn right_panel_profile_actions_have_labels_and_expanded_state_test() {
  let user =
    User(
      id: 1,
      email: "very.long.user.email.address@example-enterprise.test",
      org_id: 1,
      org_role: org_role.Admin,
      created_at: "2026-01-01T00:00:00Z",
    )

  let html =
    right_panel.RightPanelConfig(
      ..base_config([], [], []),
      user: Some(user),
      preferences_popup_open: True,
    )
    |> right_panel.view
    |> element.to_document_string

  assert_contains(html, "aria-live=\"polite\"")
  assert_contains(
    html,
    "title=\"very.long.user.email.address@example-enterprise.test\"",
  )
  assert_contains(html, "aria-label=\"Preferences\"")
  assert_contains(html, "aria-haspopup=\"dialog\"")
  assert_contains(html, "aria-expanded=\"true\"")
  assert_contains(html, "aria-label=\"Logout\"")
  assert_contains(html, "data-testid=\"preferences-btn\"")
  assert_contains(html, "data-testid=\"logout-btn\"")
  assert_contains(html, "btn-global-action")
  assert_contains(html, "btn-icon")
  assert_not_contains(html, "class=\"btn-icon-only\"")
  assert_not_contains(html, "class=\"btn-icon-only btn-logout\"")
}
