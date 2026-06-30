import gleam/option.{None, Some}

import domain/card
import domain/task.{type Task, AutomationOrigin, Task, TaskDependency}
import domain/task/state as task_state
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/features/pool/task_card
import scrumbringer_client/i18n/locale
import scrumbringer_client/theme
import support/domain_fixtures
import support/render_assertions

pub fn task_card_renders_blocked_canvas_card_test() {
  let html =
    task_card.view(config(
      Task(
        ..sample_task(),
        blocked_count: 1,
        dependencies: [
          TaskDependency(
            depends_on_task_id: 9,
            title: "API contract",
            state: task_state.Available,
            claimed_by: None,
          ),
          TaskDependency(
            depends_on_task_id: 10,
            title: "Closed dependency",
            state: task_state.Closed(
              task_state.ClosedByClaimant,
              "2026-06-01T10:00:00Z",
              7,
            ),
            claimed_by: None,
          ),
        ],
        due_date: Some("2026-06-18"),
      ),
      x: 800,
      age_days: 20,
      touch_preview: True,
      highlight_class: " highlighted",
    ))
    |> render_assertions.html

  render_assertions.contains(html, "task-card preview-left")
  render_assertions.contains(html, "decay-shake-high")
  render_assertions.contains(html, "task-blocked")
  render_assertions.contains(html, "highlighted")
  render_assertions.contains(html, "touch-preview")
  render_assertions.contains(html, "Prepare release")
  render_assertions.contains(html, "Blocked by 1 tasks")
  render_assertions.contains(html, "data-testid=\"task-card-signal-due\"")
  render_assertions.contains(html, "Overdue since 2026-06-18")
  render_assertions.contains(html, "API contract")
  render_assertions.contains(html, "task-card-open-action")
  render_assertions.contains(html, "aria-label=\"Open task: Prepare release\"")
  render_assertions.contains(html, "task-card-primary-action")
  render_assertions.contains(html, "task-card-primary-action-blocked")
  render_assertions.contains(html, "aria-disabled=\"true\"")
  render_assertions.not_contains(html, "task-blocked-card")
  render_assertions.not_contains(html, "Task has open dependencies")
  render_assertions.not_contains(html, "Closed dependency")
}

pub fn task_card_renders_due_today_signal_without_canvas_text_test() {
  let html =
    task_card.view(config(
      Task(..sample_task(), due_date: Some("2026-06-19")),
      x: 100,
      age_days: 1,
      touch_preview: False,
      highlight_class: "",
    ))
    |> render_assertions.html

  render_assertions.contains(html, "data-testid=\"task-card-signal-due\"")
  render_assertions.contains(html, "is-due-today")
  render_assertions.contains(html, "aria-label=\"Due today\"")
  render_assertions.not_contains(html, ">Due today<")
  render_assertions.contains(html, "width:128px; height:128px;")
}

pub fn task_card_renders_due_soon_signal_without_long_date_text_test() {
  let html =
    task_card.view(config(
      Task(..sample_task(), due_date: Some("2026-06-24")),
      x: 100,
      age_days: 1,
      touch_preview: False,
      highlight_class: "",
    ))
    |> render_assertions.html

  render_assertions.contains(html, "data-testid=\"task-card-signal-due\"")
  render_assertions.contains(html, "is-due-soon")
  render_assertions.contains(html, "Due soon: 2026-06-24")
  render_assertions.not_contains(html, ">2026-06-24<")
}

pub fn task_card_ignores_invalid_due_date_signal_test() {
  let html =
    task_card.view(config(
      Task(..sample_task(), due_date: Some("not-a-date")),
      x: 100,
      age_days: 1,
      touch_preview: False,
      highlight_class: "",
    ))
    |> render_assertions.html

  render_assertions.not_contains(html, "data-testid=\"task-card-signal-due\"")
  render_assertions.not_contains(html, "is-overdue")
  render_assertions.not_contains(html, "is-due-today")
  render_assertions.not_contains(html, "is-due-soon")
}

pub fn task_card_localizes_automation_signal_test() {
  let html =
    task_card.view(
      task_card.Config(
        ..config(
          Task(
            ..sample_task(),
            automation_origin: Some(AutomationOrigin(
              rule_id: 8,
              workflow_id: Some(3),
              workflow_name: Some("Release flow"),
              rule_name: Some("Development closed"),
              execution_id: Some(101),
              template_id: Some(12),
              template_name: Some("QA Verification"),
              template_version: Some(3),
            )),
          ),
          x: 100,
          age_days: 1,
          touch_preview: False,
          highlight_class: "",
        ),
        locale: locale.Es,
      ),
    )
    |> render_assertions.html

  render_assertions.contains(html, "task-card-signal-automation")
  render_assertions.contains(
    html,
    "data-testid=\"automation-created-task-origin\"",
  )
  render_assertions.contains(
    html,
    "aria-label=\"Creada por regla de automatización #8\"",
  )
  render_assertions.not_contains(html, "Created by automation")
}

pub fn task_card_renders_claimed_owner_actions_test() {
  let html =
    task_card.view(config(
      Task(
        ..sample_task(),
        state: task_state.Claimed(
          claimed_by: 7,
          claimed_at: "2026-06-01T11:00:00Z",
          mode: task_state.Taken,
        ),
      ),
      x: 100,
      age_days: 1,
      touch_preview: False,
      highlight_class: "",
    ))
    |> render_assertions.html

  render_assertions.contains(html, "task-card")
  render_assertions.contains(html, "Release")
  render_assertions.contains(html, "Close task")
  render_assertions.not_contains(html, "task-card-primary-action")
}

pub fn task_card_renders_available_claim_action_test() {
  let html =
    task_card.view(config(
      sample_task(),
      x: 100,
      age_days: 1,
      touch_preview: False,
      highlight_class: "",
    ))
    |> render_assertions.html

  render_assertions.contains(html, "task-card-actions-left")
  render_assertions.contains(html, "task-card-primary-action")
  render_assertions.contains(html, "btn-entity-action")
  render_assertions.contains(html, "btn-icon")
  render_assertions.contains(html, "aria-label=\"Claim to My Tasks\"")
  render_assertions.contains(html, "task-card-open-action")
  render_assertions.contains(html, "aria-label=\"Open task: Prepare release\"")
  render_assertions.not_contains(html, "class=\"task-card-primary-action\"")
  render_assertions.not_contains(html, "task-card-primary-label")
}

pub fn task_card_renders_card_color_identity_class_test() {
  let html =
    task_card.view(
      task_card.Config(
        ..config(
          sample_task(),
          x: 100,
          age_days: 1,
          touch_preview: False,
          highlight_class: "",
        ),
        card_color: Some(card.Blue),
      ),
    )
    |> render_assertions.html

  render_assertions.contains(html, "task-card card-border-blue")
}

pub fn task_card_position_does_not_clamp_cards_into_overlap_test() {
  let html =
    task_card.view(config(
      sample_task(),
      x: 900,
      age_days: 1,
      touch_preview: False,
      highlight_class: "",
    ))
    |> render_assertions.html

  render_assertions.contains(html, "left:max(0px,900px)")
  render_assertions.not_contains(html, "left:clamp")
  render_assertions.not_contains(html, "calc(100% - 128px)")
}

pub fn task_card_renders_mobile_context_for_touch_layout_test() {
  let html =
    task_card.view(config(
      sample_task(),
      x: 100,
      age_days: 3,
      touch_preview: False,
      highlight_class: "",
    ))
    |> render_assertions.html

  render_assertions.contains(html, "task-card-mobile-context")
  render_assertions.contains(html, "Release card")
  render_assertions.contains(html, "3 days ago")
  render_assertions.contains(html, "Task description")
}

fn config(
  task: Task,
  x x: Int,
  age_days age_days: Int,
  touch_preview touch_preview: Bool,
  highlight_class highlight_class: String,
) {
  task_card.Config(
    locale: locale.En,
    theme: theme.Default,
    task: task,
    current_user_id: Some(7),
    card_title: Some("Release card"),
    card_color: None,
    x: x,
    y: 40,
    age_days: age_days,
    project_today: "2026-06-19",
    highlight_class: highlight_class,
    touch_preview: touch_preview,
    disable_actions: False,
    hidden_blocked_count: None,
    notes: [],
    on_claim: "claim",
    on_release: "release",
    on_close: "close",
    on_open: "open",
    on_hover_opened: "hover-opened",
    on_hover_closed: "hover-closed",
    on_focused: "focused",
    on_blurred: "blurred",
    on_drag_started: fn(_, _) { "drag" },
    on_touch_started: fn(_, _) { "touch-start" },
    on_touch_ended: "touch-end",
  )
}

fn sample_task() {
  Task(
    ..domain_fixtures.task(42, "Prepare release", 1),
    task_type: TaskTypeInline(id: 1, name: "Feature", icon: "sparkles"),
  )
}
