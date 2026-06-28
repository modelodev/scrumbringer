import gleam/option
import gleam/string

import lustre/element
import lustre/element/html.{span, text}

import domain/card.{type Card, Active, Card}
import scrumbringer_client/features/cards/show/summary
import scrumbringer_client/i18n/locale.{En}
import scrumbringer_client/ui/pinned_context

fn card() -> Card {
  Card(
    id: 42,
    project_id: 1,
    parent_card_id: option.None,
    title: "Checkout",
    description: "Ship checkout",
    color: option.None,
    state: Active,
    task_count: 4,
    closed_count: 2,
    created_by: 1,
    created_at: "2026-01-20T00:00:00Z",
    due_date: option.None,
    has_new_notes: False,
  )
}

fn render(blocked_count: Int) -> String {
  summary.view(summary.Config(
    locale: En,
    card: card(),
    blocked_count: blocked_count,
    path: span([], [text("Roadmap > Checkout")]),
    pinned_notes: [
      pinned_context.PinnedNote(id: 1, content: "Decision", url: option.None),
    ],
    on_open_notes: Nil,
  ))
  |> element.to_document_string
}

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

pub fn summary_renders_compact_metrics_and_structure_test() {
  let html = render(0)

  assert_contains(html, "card-summary-section")
  assert_contains(html, "card-summary-metric-total")
  assert_contains(html, "card-summary-metric-closed")
  assert_contains(html, "card-summary-metric-blocked")
  assert_contains(html, "is-compact")
  assert_not_contains(html, "task-metric-chip-label")
  assert_contains(html, "Roadmap &gt; Checkout")
  assert_contains(html, "Decision")
}

pub fn summary_uses_blocked_signal_when_blockers_exist_test() {
  let html = render(1)

  assert_contains(html, "card-summary-signal is-blocked")
}
