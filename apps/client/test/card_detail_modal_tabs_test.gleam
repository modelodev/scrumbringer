//// Tests for card detail modal tabs layout.

import gleam/string
import lustre/element

import scrumbringer_client/ui/card_tabs

fn assert_contains(text: String, fragment: String) {
  let assert True = string.contains(text, fragment)
}

pub fn renders_tabs_with_correct_labels_test() {
  let config =
    card_tabs.Config(
      active_tab: card_tabs.TasksTab,
      notes_count: 3,
      has_new_notes: False,
      labels: card_tabs.Labels(
        tasks: "TAREAS",
        notes: "NOTAS",
        metrics: "METRICAS",
      ),
      on_tab_click: fn(tab) { tab },
    )

  let html = card_tabs.view(config) |> element.to_document_string

  assert_contains(html, "TAREAS")
  assert_contains(html, "NOTAS")
  assert_contains(html, "(3)")
}

pub fn tareas_tab_active_by_default_test() {
  let config =
    card_tabs.Config(
      active_tab: card_tabs.TasksTab,
      notes_count: 0,
      has_new_notes: False,
      labels: card_tabs.Labels(
        tasks: "TAREAS",
        notes: "NOTAS",
        metrics: "METRICAS",
      ),
      on_tab_click: fn(tab) { tab },
    )

  let html = card_tabs.view(config) |> element.to_document_string

  // The active tab should have an "active" class
  assert_contains(html, "tab-active")
}

pub fn notes_tab_shows_badge_for_new_notes_test() {
  let config =
    card_tabs.Config(
      active_tab: card_tabs.TasksTab,
      notes_count: 2,
      has_new_notes: True,
      labels: card_tabs.Labels(
        tasks: "TAREAS",
        notes: "NOTAS",
        metrics: "METRICAS",
      ),
      on_tab_click: fn(tab) { tab },
    )

  let html = card_tabs.view(config) |> element.to_document_string

  // Should have some indicator for new notes
  assert_contains(html, "new-notes-indicator")
}
