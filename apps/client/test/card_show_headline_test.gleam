import gleam/option.{None, Some}
import support/domain_fixtures

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
    ..domain_fixtures.card(4, 7, "Customer Card"),
    state: Active,
    task_count: task_count,
    closed_count: closed_count,
    due_date: due_date,
  )
}
