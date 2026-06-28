import domain/card.{type Card, Active, Card}
import domain/org.{OrgUser}
import domain/org_role.{Admin}
import domain/task.{type Task, Task}
import domain/task/state as task_state
import gleam/dict
import gleam/option.{None, Some}
import lustre/element
import support/domain_fixtures
import support/render_assertions

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
        org_role: Admin,
        created_at: "2026-01-01T00:00:00Z",
      ),
    ],
    expanded_cards: dict.new(),
    hide_closed: False,
    on_toggle_card: fn(id) { id },
    on_toggle_hide_closed: 0,
    on_task_click: fn(id) { id },
    on_task_claim: fn(a, b) { a + b },
  )
}

fn sample_card() -> Card {
  Card(
    id: 1,
    project_id: 1,
    parent_card_id: None,
    title: "Sprint",
    description: "",
    color: Some(card.Blue),
    state: Active,
    task_count: 1,
    closed_count: 0,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    due_date: None,
    has_new_notes: False,
  )
}

fn claimed_task() -> Task {
  let state =
    task_state.Claimed(
      claimed_by: 1,
      claimed_at: "2026-01-01T00:00:00Z",
      mode: task_state.Ongoing,
    )

  Task(
    ..domain_fixtures.task(1, "Fix login", 1),
    description: None,
    priority: 3,
    state: state,
    card_id: Some(1),
    card_title: Some("Sprint"),
    card_color: Some(card.Blue),
  )
}

fn available_task() -> Task {
  Task(
    ..domain_fixtures.task(2, "Review copy", 1),
    description: None,
    priority: 2,
    version: 2,
    card_id: Some(1),
    card_title: Some("Sprint"),
    card_color: Some(card.Blue),
  )
}

pub fn grouped_list_renders_claimed_by_and_border_class_test() {
  let html =
    base_config([claimed_task()], [sample_card()])
    |> grouped_list.view
    |> element.to_document_string

  render_assertions.contains(html, "Claimed by admin@example.com")
  render_assertions.contains(html, "task-status-indicator")
  render_assertions.contains(html, "task-claimed-by")
  render_assertions.contains(html, "task-item card-border-blue")
  render_assertions.contains(html, "task-type-icon")
}

pub fn grouped_list_renders_available_label_and_claim_button_test() {
  let html =
    base_config([available_task()], [sample_card()])
    |> grouped_list.view
    |> element.to_document_string

  render_assertions.contains(html, "Available")
  render_assertions.contains(html, "task-claim-btn")
}

pub fn grouped_list_shows_notes_indicator_test() {
  let card = Card(..sample_card(), has_new_notes: True)

  let html =
    base_config([available_task()], [card])
    |> grouped_list.view
    |> element.to_document_string

  render_assertions.contains(html, "card-notes-indicator")
}
