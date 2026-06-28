import domain/card.{type Card, Active, Card, Closed}
import gleam/option.{None, Some}
import lustre/element
import support/domain_fixtures
import support/render_assertions

import scrumbringer_client/i18n/locale
import scrumbringer_client/theme
import scrumbringer_client/ui/card_with_tasks_surface

pub fn overdue_open_card_uses_danger_due_date_style_test() {
  let html =
    card_with_tasks_surface.view(config(
      Card(..sample_card(), state: Active, due_date: Some("2026-06-18")),
    ))
    |> element.to_document_string

  render_assertions.contains(html, "card-due-date")
  render_assertions.contains(html, "card-due-date-overdue")
  render_assertions.contains(html, "2026-06-18")
  render_assertions.not_contains(html, "decay-shake")
}

pub fn closed_card_does_not_show_overdue_alarm_test() {
  let html =
    card_with_tasks_surface.view(config(
      Card(..sample_card(), state: Closed, due_date: Some("2026-06-18")),
    ))
    |> element.to_document_string

  render_assertions.contains(html, "card-due-date")
  render_assertions.contains(html, "2026-06-18")
  render_assertions.not_contains(html, "card-due-date-overdue")
  render_assertions.not_contains(html, "decay-shake")
}

pub fn invalid_card_due_date_does_not_show_overdue_alarm_test() {
  let html =
    card_with_tasks_surface.view(config(
      Card(..sample_card(), state: Active, due_date: Some("not-a-date")),
    ))
    |> element.to_document_string

  render_assertions.contains(html, "card-due-date")
  render_assertions.contains(html, "not-a-date")
  render_assertions.not_contains(html, "card-due-date-overdue")
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
    ..domain_fixtures.card(10, 1, "Release train"),
    description: "Cut the next release",
    state: Active,
    task_count: 2,
    created_by: 7,
    created_at: "2026-06-01T10:00:00Z",
  )
}
