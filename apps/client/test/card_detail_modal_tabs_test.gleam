//// Tests for card detail modal tabs layout.

import gleam/string
import gleeunit/should
import lustre/element

import scrumbringer_client/ui/card_tabs

pub fn renders_tabs_with_correct_labels_test() {
  let config =
    card_tabs.Config(
      active_tab: card_tabs.TasksTab,
      notes_count: 3,
      has_new_notes: False,
      labels: card_tabs.Labels(tasks: "TAREAS", notes: "NOTAS"),
      on_tab_click: fn(tab) { tab },
    )

  let html = card_tabs.view(config) |> element.to_document_string

  string.contains(html, "TAREAS") |> should.be_true
  string.contains(html, "NOTAS") |> should.be_true
  string.contains(html, "(3)") |> should.be_true
}

pub fn tareas_tab_active_by_default_test() {
  let config =
    card_tabs.Config(
      active_tab: card_tabs.TasksTab,
      notes_count: 0,
      has_new_notes: False,
      labels: card_tabs.Labels(tasks: "TAREAS", notes: "NOTAS"),
      on_tab_click: fn(tab) { tab },
    )

  let html = card_tabs.view(config) |> element.to_document_string

  // The active tab should have an "active" class
  string.contains(html, "tab-active") |> should.be_true
}

pub fn notes_tab_shows_badge_for_new_notes_test() {
  let config =
    card_tabs.Config(
      active_tab: card_tabs.TasksTab,
      notes_count: 2,
      has_new_notes: True,
      labels: card_tabs.Labels(tasks: "TAREAS", notes: "NOTAS"),
      on_tab_click: fn(tab) { tab },
    )

  let html = card_tabs.view(config) |> element.to_document_string

  // Should have some indicator for new notes
  string.contains(html, "new-notes-indicator")
  |> should.be_true
}
