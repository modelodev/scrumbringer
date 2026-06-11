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

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
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

fn task(id: Int, title: String, card_id: opt.Option(Int)) -> Task {
  let state = task_state.Available

  Task(
    id: id,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Task", icon: "check"),
    ongoing_by: opt.None,
    title: title,
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
    loose_tasks: [task(20, "Loose Task 20", opt.None)],
    org_users: [],
    tasks_for_card: fn(_) { [task(30, "Card Task 30", opt.Some(10))] },
    destinations: [destination(2)],
    can_move: True,
    can_drag: True,
    is_card_expanded: fn(_) { False },
    on_card_toggle: fn(id) { "toggle-card:" <> int.to_string(id) },
    on_view_kanban: "view-kanban",
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

fn expanded_config() -> work_items.Config(String) {
  work_items.Config(..config(), is_card_expanded: fn(id) { id == 10 })
}

fn empty_expanded_config() -> work_items.Config(String) {
  work_items.Config(
    ..expanded_config(),
    cards: [Card(..card(10), task_count: 0)],
    tasks_for_card: fn(_) { [] },
  )
}

pub fn work_items_renders_cards_from_config_without_root_model_test() {
  let html =
    work_items.view_cards_section(config())
    |> element.to_document_string

  assert_contains(html, "Planning Card 10")
  assert_contains(html, "milestone-card-row:1:10")
  assert_contains(html, "milestone-delivery-card")
  assert_contains(html, "milestone-card-status-chip")
  assert_contains(html, "milestone-card-toggle:1:10")
  assert_contains(html, "aria-expanded=\"false\"")
  assert_contains(html, "aria-controls=\"milestone-card-tasks-1-10\"")
  assert_contains(html, "Blocked")
  assert_contains(html, "0/1")
  assert_not_contains(html, "Card Task 30")
  assert_not_contains(html, "milestone-card-health-chip")
  assert_contains(html, "View in Kanban")
  assert_contains(html, "milestone-card-kanban:1:10")
  assert_contains(html, "milestone-move-menu-card:1:10")
  assert_contains(html, "draggable=\"true\"")
}

pub fn work_items_renders_expanded_card_tasks_inline_test() {
  let html =
    work_items.view_cards_section(expanded_config())
    |> element.to_document_string

  assert_contains(html, "aria-expanded=\"true\"")
  assert_contains(html, "aria-label=\"Tasks for Planning Card 10\"")
  assert_contains(html, "Card Task 30")
  assert_contains(html, "milestone-card-task-row:1:30")
  assert_contains(html, "milestone-card-tasks-panel")
}

pub fn work_items_renders_expanded_empty_card_state_test() {
  let html =
    work_items.view_cards_section(empty_expanded_config())
    |> element.to_document_string

  assert_contains(html, "This card has no tasks yet")
  assert_contains(html, "milestone-card-tasks-panel")
}

pub fn work_items_renders_loose_tasks_from_config_without_root_model_test() {
  let html =
    work_items.view_loose_tasks_panel(config())
    |> element.to_document_string

  assert_contains(html, "Loose Task 20")
  assert_contains(html, "Available")
  assert_contains(html, "Tasks without card")
  assert_not_contains(html, "These tasks are not grouped inside a card yet")
  assert_contains(html, "milestone-task-row:1:20")
  assert_contains(html, "milestone-move-menu-task:1:20")
  assert_contains(html, "draggable=\"true\"")
}
