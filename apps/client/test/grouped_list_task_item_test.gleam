import domain/card.{type Card, Card, EnCurso}
import domain/org.{OrgUser}
import domain/task.{type Task, Task}
import domain/task_status
import domain/task_type.{TaskTypeInline}
import gleam/dict
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import lustre/element

import scrumbringer_client/features/views/grouped_list
import scrumbringer_client/i18n/locale as i18n_locale
import scrumbringer_client/theme

fn base_config(
  tasks: List(Task),
  cards: List(Card),
) -> grouped_list.GroupedListConfig(Int) {
  grouped_list.GroupedListConfig(
    locale: i18n_locale.En,
    theme: theme.Default,
    tasks: tasks,
    cards: cards,
    org_users: [
      OrgUser(
        id: 1,
        email: "admin@example.com",
        org_role: "admin",
        created_at: "2026-01-01T00:00:00Z",
      ),
    ],
    expanded_cards: dict.new(),
    hide_completed: False,
    on_toggle_card: fn(id) { id },
    on_toggle_hide_completed: 0,
    on_task_click: fn(id) { id },
    on_task_claim: fn(a, b) { a + b },
  )
}

fn sample_card() -> Card {
  Card(
    id: 1,
    project_id: 1,
    title: "Sprint",
    description: "",
    color: Some("blue"),
    state: EnCurso,
    task_count: 1,
    completed_count: 0,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    has_new_notes: False,
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
  )
}

pub fn grouped_list_renders_claimed_by_and_border_class_test() {
  let html =
    base_config([claimed_task()], [sample_card()])
    |> grouped_list.view
    |> element.to_document_string

  string.contains(html, "Claimed by admin@example.com") |> should.be_true
  string.contains(html, "task-claimed-icon") |> should.be_true
  string.contains(html, "task-item card-border-blue") |> should.be_true
  string.contains(html, "task-type-icon") |> should.be_true
}

pub fn grouped_list_renders_available_label_and_claim_button_test() {
  let html =
    base_config([available_task()], [sample_card()])
    |> grouped_list.view
    |> element.to_document_string

  string.contains(html, "Available") |> should.be_true
  string.contains(html, "task-claim-btn") |> should.be_true
}

pub fn grouped_list_shows_notes_indicator_test() {
  let card = Card(..sample_card(), has_new_notes: True)

  let html =
    base_config([available_task()], [card])
    |> grouped_list.view
    |> element.to_document_string

  string.contains(html, "card-notes-indicator") |> should.be_true
}
