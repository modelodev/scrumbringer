import gleam/int
import gleam/option as opt
import gleam/string
import lustre/element

import domain/card.{type Card, Card, Pendiente}
import domain/milestone.{type Milestone, Milestone, Ready}
import domain/task.{type Task, Task}
import domain/task_state
import domain/task_status.{type TaskStatus, Available}
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/features/milestones/work_items
import scrumbringer_client/i18n/locale
import scrumbringer_client/theme

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn card(id: Int) -> Card {
  Card(
    id: id,
    project_id: 1,
    milestone_id: opt.Some(1),
    title: "Planning Card " <> int.to_string(id),
    description: "",
    color: opt.None,
    state: Pendiente,
    task_count: 1,
    completed_count: 0,
    created_by: 1,
    created_at: "2026-02-06T00:00:00Z",
    has_new_notes: False,
  )
}

fn task(id: Int, card_id: opt.Option(Int)) -> Task {
  let state = task_state.Available

  Task(
    id: id,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Task", icon: "check"),
    ongoing_by: opt.None,
    title: "Loose Task " <> int.to_string(id),
    description: opt.None,
    priority: 1,
    state: state,
    status: task_state.to_status(state),
    work_state: task_state.to_work_state(state),
    created_by: 1,
    created_at: "2026-02-06T00:00:00Z",
    version: 1,
    milestone_id: opt.Some(1),
    card_id: card_id,
    card_title: opt.None,
    card_color: opt.None,
    has_new_notes: False,
    blocked_count: 1,
    dependencies: [],
  )
}

fn destination(id: Int) -> Milestone {
  Milestone(
    id: id,
    project_id: 1,
    name: "Destination " <> int.to_string(id),
    description: opt.None,
    state: Ready,
    position: id,
    created_by: 1,
    created_at: "2026-02-06T00:00:00Z",
    activated_at: opt.None,
    completed_at: opt.None,
  )
}

fn status_label(status: TaskStatus) -> String {
  case status {
    Available -> "Available"
    _ -> "Other"
  }
}

fn config() -> work_items.Config(String) {
  work_items.Config(
    locale: locale.En,
    theme: theme.Default,
    milestone_id: 1,
    cards: [card(10)],
    loose_tasks: [task(20, opt.None)],
    org_users: [],
    tasks_for_card: fn(_) { [task(30, opt.Some(10))] },
    destinations: [destination(2)],
    can_move: True,
    can_drag: True,
    card_header_actions: fn(_) { [] },
    on_task_open: fn(id) { "open:" <> int.to_string(id) },
    on_task_claim: fn(id, _) { "claim:" <> int.to_string(id) },
    on_card_drag_started: fn(id) { "drag-card:" <> int.to_string(id) },
    on_task_drag_started: fn(id) { "drag-task:" <> int.to_string(id) },
    on_drag_ended: "drag-ended",
    on_card_move: fn(card_id, destination_id) {
      "move-card:"
      <> int.to_string(card_id)
      <> ":"
      <> int.to_string(destination_id)
    },
    on_task_move: fn(task_id, destination_id) {
      "move-task:"
      <> int.to_string(task_id)
      <> ":"
      <> int.to_string(destination_id)
    },
    task_status_label: status_label,
  )
}

pub fn work_items_renders_cards_from_config_without_root_model_test() {
  let html =
    work_items.view_cards_section(config())
    |> element.to_document_string

  assert_contains(html, "Planning Card 10")
  assert_contains(html, "Loose Task 30")
  assert_contains(html, "milestone-card-row:1:10")
  assert_contains(html, "milestone-card-health-chip")
  assert_contains(html, "Available: 1")
  assert_contains(html, "Blocked: 1")
  assert_contains(html, "milestone-move-menu-card:1:10")
  assert_contains(html, "draggable=\"true\"")
}

pub fn work_items_renders_loose_tasks_from_config_without_root_model_test() {
  let html =
    work_items.view_loose_tasks_panel(config())
    |> element.to_document_string

  assert_contains(html, "Loose Task 20")
  assert_contains(html, "Available")
  assert_contains(html, "Loose tasks")
  assert_contains(html, "These tasks are not grouped inside a card yet")
  assert_contains(html, "milestone-task-row:1:20")
  assert_contains(html, "milestone-move-menu-task:1:20")
  assert_contains(html, "draggable=\"true\"")
}
