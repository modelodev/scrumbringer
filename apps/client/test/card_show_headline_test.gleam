import gleam/option.{None, Some}

import domain/card.{type Card, Active, Card}
import scrumbringer_client/features/cards/show/headline as card_show_headline
import scrumbringer_client/i18n/locale

pub fn active_empty_card_headline_is_compact_operational_copy_test() {
  let copy =
    card_show_headline.text(card_show_headline.Config(
      locale: locale.En,
      card: card(0, 0, None),
    ))

  let assert "Active · No due date · No tasks" = copy
}

pub fn card_headline_includes_due_date_and_work_progress_test() {
  let copy =
    card_show_headline.text(card_show_headline.Config(
      locale: locale.En,
      card: card(4, 1, Some("2026-06-24")),
    ))

  let assert "Active · Due 2026-06-24 · 1 closed · 4 Tasks" = copy
}

fn card(task_count: Int, closed_count: Int, due_date) -> Card {
  Card(
    id: 4,
    project_id: 7,
    parent_card_id: None,
    title: "Customer Card",
    description: "Customer-facing card",
    color: None,
    state: Active,
    task_count: task_count,
    closed_count: closed_count,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    due_date: due_date,
    has_new_notes: False,
  )
}
