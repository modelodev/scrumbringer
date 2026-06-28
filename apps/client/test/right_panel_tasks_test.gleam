import domain/card
import domain/org_role
import domain/task.{type Task, Task}
import domain/task/state as task_state
import domain/user.{User}
import gleam/option.{None, Some}
import lustre/element
import support/domain_fixtures
import support/render_assertions

import scrumbringer_client/features/layout/right_panel
import scrumbringer_client/i18n/locale as i18n_locale
import scrumbringer_client/theme

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
    ..domain_fixtures.task(1, "Fix login", 1),
    state: state,
    card_title: Some("Sprint"),
    card_color: Some(card.Blue),
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

  render_assertions.contains(html, "active-task-card card-border-blue")
  render_assertions.contains(html, "task-type-icon")
  render_assertions.contains(html, "task-timer")
  render_assertions.contains(html, "title=\"Fix login\"")
  render_assertions.contains(html, "Close task")
  render_assertions.not_contains(html, "aria-label=\"Complete\"")
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

  render_assertions.contains(html, "task-item card-border-blue")
  render_assertions.contains(html, "task-card-identity-swatch")
  render_assertions.contains(html, "my-task-start-btn")
  render_assertions.contains(html, "my-task-release-btn")
  render_assertions.contains(html, "task-type-icon")
  render_assertions.contains(html, "type=\"button\"")
  render_assertions.contains(html, "aria-label=\"Open task: Fix login\"")
  render_assertions.contains(html, "title=\"Fix login\"")
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

  render_assertions.contains(html, "my-card-item card-border-blue")
  render_assertions.contains(html, "1 of 3 tasks closed")
  render_assertions.contains(html, "type=\"button\"")
  render_assertions.contains(html, "aria-label=\"Context: Sprint\"")
  render_assertions.contains(html, "title=\"Sprint\"")
}

pub fn right_panel_preferences_popup_is_accessible_dialog_test() {
  let html =
    right_panel.RightPanelConfig(
      ..base_config([], [], []),
      preferences_popup_open: True,
    )
    |> right_panel.view
    |> element.to_document_string

  render_assertions.contains(html, "role=\"dialog\"")
  render_assertions.contains(html, "aria-modal=\"true\"")
  render_assertions.contains(
    html,
    "aria-labelledby=\"preferences-popup-title\"",
  )
  render_assertions.contains(html, "id=\"preferences-popup-title\"")
  render_assertions.contains(html, "aria-label=\"Close\"")
  render_assertions.contains(html, "btn-global-action")
  render_assertions.contains(html, "btn-icon")
  render_assertions.contains(html, "Theme")
  render_assertions.contains(html, "Language")
}

pub fn right_panel_profile_actions_have_labels_and_expanded_state_test() {
  let user =
    User(
      ..domain_fixtures.user(
        1,
        "very.long.user.email.address@example-enterprise.test",
      ),
      org_role: org_role.Admin,
    )

  let html =
    right_panel.RightPanelConfig(
      ..base_config([], [], []),
      user: Some(user),
      preferences_popup_open: True,
    )
    |> right_panel.view
    |> element.to_document_string

  render_assertions.contains(html, "aria-live=\"polite\"")
  render_assertions.contains(
    html,
    "title=\"very.long.user.email.address@example-enterprise.test\"",
  )
  render_assertions.contains(html, "aria-label=\"Preferences\"")
  render_assertions.contains(html, "aria-haspopup=\"dialog\"")
  render_assertions.contains(html, "aria-expanded=\"true\"")
  render_assertions.contains(html, "aria-label=\"Logout\"")
  render_assertions.contains(html, "data-testid=\"preferences-btn\"")
  render_assertions.contains(html, "data-testid=\"logout-btn\"")
  render_assertions.contains(html, "btn-global-action")
  render_assertions.contains(html, "btn-icon")
  render_assertions.not_contains(html, "class=\"btn-icon-only\"")
  render_assertions.not_contains(html, "class=\"btn-icon-only btn-logout\"")
}
