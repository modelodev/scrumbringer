import domain/card.{type Card, Active, Card, Closed}
import gleam/option.{None, Some}
import gleam/string
import lustre/element

import scrumbringer_client/i18n/locale
import scrumbringer_client/theme
import scrumbringer_client/ui/card_with_tasks_surface

fn assert_contains(text: String, fragment: String) {
  let assert True = string.contains(text, fragment)
}

fn assert_not_contains(text: String, fragment: String) {
  let assert False = string.contains(text, fragment)
}

pub fn overdue_open_card_uses_danger_due_date_style_test() {
  let html =
    card_with_tasks_surface.view(config(
      Card(..sample_card(), state: Active, due_date: Some("2026-06-18")),
    ))
    |> element.to_document_string

  assert_contains(html, "card-due-date")
  assert_contains(html, "card-due-date-overdue")
  assert_contains(html, "2026-06-18")
  assert_not_contains(html, "decay-shake")
}

pub fn closed_card_does_not_show_overdue_alarm_test() {
  let html =
    card_with_tasks_surface.view(config(
      Card(..sample_card(), state: Closed, due_date: Some("2026-06-18")),
    ))
    |> element.to_document_string

  assert_contains(html, "card-due-date")
  assert_contains(html, "2026-06-18")
  assert_not_contains(html, "card-due-date-overdue")
  assert_not_contains(html, "decay-shake")
}

pub fn invalid_card_due_date_does_not_show_overdue_alarm_test() {
  let html =
    card_with_tasks_surface.view(config(
      Card(..sample_card(), state: Active, due_date: Some("not-a-date")),
    ))
    |> element.to_document_string

  assert_contains(html, "card-due-date")
  assert_contains(html, "not-a-date")
  assert_not_contains(html, "card-due-date-overdue")
}

fn config(card: Card) {
  card_with_tasks_surface.Config(
    locale: locale.En,
    theme: theme.Default,
    card: card,
    tasks: [],
    org_users: [],
    preview_limit: 3,
    progress_closed: 0,
    progress_total: 0,
    project_today: "2026-06-19",
    description: None,
    status_items: [],
    on_card_click: None,
    on_task_click: fn(id) { id },
    on_task_claim: fn(id, _) { id },
    header_actions: [],
    footer_actions: [],
    root_attributes: [],
    task_item_testid: None,
  )
}

fn sample_card() {
  Card(
    id: 10,
    project_id: 1,
    parent_card_id: None,
    title: "Release train",
    description: "Cut the next release",
    color: None,
    state: Active,
    task_count: 2,
    closed_count: 0,
    created_by: 7,
    created_at: "2026-06-01T10:00:00Z",
    due_date: None,
    has_new_notes: False,
  )
}
