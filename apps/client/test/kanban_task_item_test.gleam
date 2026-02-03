import domain/card.{Card, Pendiente}
import domain/org.{OrgUser}
import domain/org_role.{Admin}
import domain/task.{type Task, Task}
import domain/task_status
import domain/task_type.{TaskTypeInline}
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import lustre/element

import scrumbringer_client/features/views/kanban_board
import scrumbringer_client/i18n/locale as i18n_locale
import scrumbringer_client/theme

fn base_config(tasks: List(Task)) -> kanban_board.KanbanConfig(Int) {
  let card =
    Card(
      id: 1,
      project_id: 1,
      title: "Sprint",
      description: "",
      color: Some("blue"),
      state: Pendiente,
      task_count: list.length(tasks),
      completed_count: 0,
      created_by: 1,
      created_at: "2026-01-01T00:00:00Z",
      has_new_notes: False,
    )

  kanban_board.KanbanConfig(
    locale: i18n_locale.En,
    theme: theme.Default,
    cards: [card],
    tasks: tasks,
    org_users: [
      OrgUser(
        id: 1,
        email: "admin@example.com",
        org_role: Admin,
        created_at: "2026-01-01T00:00:00Z",
      ),
    ],
    is_pm_or_admin: False,
    on_card_click: fn(id) { id },
    on_card_edit: fn(id) { id },
    on_card_delete: fn(id) { id },
    on_new_card: 0,
    on_task_click: fn(id) { id },
    on_task_claim: fn(a, b) { a + b },
    on_create_task_in_card: fn(id) { id },
  )
}

fn claimed_task() -> Task {
  Task(
    id: 1,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Bug", icon: "bug-ant"),
    ongoing_by: None,
    title: "Fix login",
    description: None,
    priority: 3,
    status: task_status.Claimed(task_status.Ongoing),
    work_state: task_status.WorkOngoing,
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
    blocked_count: 0,
    dependencies: [],
  )
}

fn available_task() -> Task {
  Task(
    id: 2,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Bug", icon: "bug-ant"),
    ongoing_by: None,
    title: "Review copy",
    description: None,
    priority: 2,
    status: task_status.Available,
    work_state: task_status.WorkAvailable,
    created_by: 1,
    claimed_by: None,
    claimed_at: None,
    completed_at: None,
    created_at: "2026-01-01T00:00:00Z",
    version: 2,
    card_id: Some(1),
    card_title: Some("Sprint"),
    card_color: Some("blue"),
    has_new_notes: False,
    blocked_count: 0,
    dependencies: [],
  )
}

pub fn kanban_task_item_renders_claimed_by_and_icon_test() {
  let html =
    base_config([claimed_task()])
    |> kanban_board.view
    |> element.to_document_string

  string.contains(html, "kanban-task-item") |> should.be_true
  string.contains(html, "task-claimed-by") |> should.be_true
  string.contains(html, "task-type-icon") |> should.be_true
  string.contains(html, "admin") |> should.be_true
}

pub fn kanban_task_item_renders_claim_button_for_available_test() {
  let html =
    base_config([available_task()])
    |> kanban_board.view
    |> element.to_document_string

  string.contains(html, "btn-claim-mini") |> should.be_true
}

pub fn kanban_card_shows_notes_indicator_test() {
  let config = base_config([available_task()])
  let card = case config.cards {
    [first, ..] -> card.Card(..first, has_new_notes: True)
    [] -> panic
  }

  let html =
    kanban_board.KanbanConfig(..config, cards: [card])
    |> kanban_board.view
    |> element.to_document_string

  string.contains(html, "card-notes-indicator") |> should.be_true
}
