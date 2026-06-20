import gleam/option.{None, Some}
import gleam/string
import lustre/element

import domain/task.{type Task, Task, TaskDependency}
import domain/task_state
import domain/task_status.{
  Available, Claimed, Done, Taken, WorkAvailable, WorkClaimed,
}
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/features/pool/task_card
import scrumbringer_client/i18n/locale
import scrumbringer_client/theme

fn assert_contains(text: String, fragment: String) {
  let assert True = string.contains(text, fragment)
}

fn assert_not_contains(text: String, fragment: String) {
  let assert False = string.contains(text, fragment)
}

pub fn task_card_renders_blocked_canvas_card_test() {
  let html =
    task_card.view(config(
      Task(..sample_task(), blocked_count: 1, dependencies: [
        TaskDependency(
          depends_on_task_id: 9,
          title: "API contract",
          status: Available,
          claimed_by: None,
        ),
        TaskDependency(
          depends_on_task_id: 10,
          title: "Done dependency",
          status: Done,
          claimed_by: None,
        ),
      ]),
      x: 800,
      age_days: 20,
      touch_preview: True,
      highlight_class: " highlighted",
    ))
    |> element.to_document_string

  assert_contains(html, "task-card preview-left")
  assert_contains(html, "decay-shake-medium")
  assert_contains(html, "task-blocked")
  assert_contains(html, "highlighted")
  assert_contains(html, "touch-preview")
  assert_contains(html, "Prepare release")
  assert_contains(html, "Blocked by 1 tasks")
  assert_contains(html, "API contract")
  assert_not_contains(html, "Done dependency")
  assert_not_contains(html, "task-card-primary-action")
}

pub fn task_card_renders_claimed_owner_actions_test() {
  let html =
    task_card.view(config(
      Task(
        ..sample_task(),
        state: task_state.Claimed(
          claimed_by: 7,
          claimed_at: "2026-06-01T11:00:00Z",
          mode: Taken,
        ),
        status: Claimed(Taken),
        work_state: WorkClaimed,
      ),
      x: 100,
      age_days: 1,
      touch_preview: False,
      highlight_class: "",
    ))
    |> element.to_document_string

  assert_contains(html, "task-card")
  assert_contains(html, "Release")
  assert_contains(html, "Complete")
  assert_not_contains(html, "task-card-primary-action")
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
    |> element.to_document_string

  assert_contains(html, "task-card-actions-left")
  assert_contains(html, "task-card-primary-action")
  assert_contains(html, "btn-entity-action")
  assert_contains(html, "btn-icon")
  assert_contains(html, "aria-label=\"Claim to My Tasks\"")
  assert_contains(html, "task-card-open-action")
  assert_contains(html, "aria-label=\"Open task: Prepare release\"")
  assert_not_contains(html, "class=\"task-card-primary-action\"")
  assert_not_contains(html, "task-card-primary-label")
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
    |> element.to_document_string

  assert_contains(html, "left:max(0px,900px)")
  assert_not_contains(html, "left:clamp")
  assert_not_contains(html, "calc(100% - 128px)")
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
    |> element.to_document_string

  assert_contains(html, "task-card-mobile-context")
  assert_contains(html, "Release card")
  assert_contains(html, "3 days ago")
  assert_contains(html, "Task description")
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
    on_complete: "complete",
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
    id: 42,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Feature", icon: "sparkles"),
    ongoing_by: None,
    title: "Prepare release",
    description: Some("Task description"),
    priority: 2,
    state: task_state.Available,
    status: Available,
    work_state: WorkAvailable,
    created_by: 7,
    created_at: "2026-06-01T10:00:00Z",
    due_date: None,
    version: 1,
    parent_card_id: None,
    card_id: Some(10),
    card_title: Some("Release card"),
    card_color: None,
    has_new_notes: False,
    blocked_count: 0,
    dependencies: [],
  )
}
