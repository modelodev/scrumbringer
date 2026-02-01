import domain/task.{type Task, Task}
import domain/task_status
import domain/task_type.{TaskTypeInline}
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import lustre/element

import scrumbringer_client/client_state
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
    model: client_state.default_model(),
    user: None,
    my_tasks: my_tasks,
    my_cards: my_cards,
    active_tasks: active_tasks,
    on_task_start: fn(id) { id },
    on_task_pause: fn(id) { id },
    on_task_complete: fn(id) { id },
    on_task_release: fn(id) { id },
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

fn sample_task(
  status: task_status.TaskStatus,
  work_state: task_status.WorkState,
) -> Task {
  Task(
    id: 1,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Bug", icon: "bug-ant"),
    ongoing_by: None,
    title: "Fix login",
    description: None,
    priority: 3,
    status: status,
    work_state: work_state,
    created_by: 1,
    claimed_by: Some(1),
    claimed_at: None,
    completed_at: None,
    created_at: "2026-01-01T00:00:00Z",
    version: 1,
    card_id: Some(1),
    card_title: Some("Sprint"),
    card_color: Some("blue"),
    has_new_notes: False,
  )
}

pub fn right_panel_active_task_renders_border_and_icon_test() {
  let active =
    right_panel.ActiveTaskInfo(
      task_id: 1,
      task_title: "Fix login",
      task_type_icon: "bug-ant",
      card_color: Some("blue"),
      elapsed_display: "00:10",
      is_paused: False,
    )

  let html =
    base_config([], [active], [])
    |> right_panel.view
    |> element.to_document_string

  string.contains(html, "active-task-card card-border-blue") |> should.be_true
  string.contains(html, "task-type-icon") |> should.be_true
  string.contains(html, "task-timer") |> should.be_true
}

pub fn right_panel_my_task_renders_border_and_actions_test() {
  let task =
    sample_task(task_status.Claimed(task_status.Taken), task_status.WorkClaimed)

  let html =
    base_config([task], [], [])
    |> right_panel.view
    |> element.to_document_string

  string.contains(html, "task-item card-border-blue") |> should.be_true
  string.contains(html, "my-task-start-btn") |> should.be_true
  string.contains(html, "my-task-release-btn") |> should.be_true
  string.contains(html, "task-type-icon") |> should.be_true
}

pub fn right_panel_my_cards_renders_border_and_progress_test() {
  let card =
    right_panel.MyCardProgress(
      card_id: 1,
      card_title: "Sprint",
      card_color: Some("blue"),
      completed: 1,
      total: 3,
    )

  let html =
    base_config([], [], [card])
    |> right_panel.view
    |> element.to_document_string

  string.contains(html, "my-card-item card-border-blue") |> should.be_true
  string.contains(html, "1/3") |> should.be_true
}
