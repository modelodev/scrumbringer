//// Tests for task tabs component.

import gleam/string
import gleeunit/should
import lustre/element

import scrumbringer_client/ui/task_tabs.{
  type Config, Config, DetailsTab, Labels, NotesTab,
}

// =============================================================================
// Test Helpers
// =============================================================================

fn render_to_string(config: Config(msg)) -> String {
  task_tabs.view(config) |> element.to_string()
}

// =============================================================================
// Tests
// =============================================================================

pub fn renders_details_and_notes_tabs_test() {
  // Given: Config with DetailsTab active
  let config =
    Config(
      active_tab: DetailsTab,
      notes_count: 3,
      has_new_notes: True,
      labels: Labels(details: "Detalles", notes: "Notas"),
      on_tab_click: fn(_) { Nil },
    )

  // When: render
  let html = render_to_string(config)

  // Then: Contains both tab labels
  html |> string.contains("Detalles") |> should.be_true()
  html |> string.contains("Notas") |> should.be_true()
  html |> string.contains("(3)") |> should.be_true()
}

pub fn active_tab_has_active_class_test() {
  // Given: Config with NotesTab active
  let config =
    Config(
      active_tab: NotesTab,
      notes_count: 0,
      has_new_notes: False,
      labels: Labels(details: "Details", notes: "Notes"),
      on_tab_click: fn(_) { Nil },
    )

  // When: render
  let html = render_to_string(config)

  // Then: Contains tab-active class
  html |> string.contains("tab-active") |> should.be_true()
}

pub fn shows_new_notes_indicator_test() {
  // Given: has_new_notes = True
  let config =
    Config(
      active_tab: DetailsTab,
      notes_count: 5,
      has_new_notes: True,
      labels: Labels(details: "Details", notes: "Notes"),
      on_tab_click: fn(_) { Nil },
    )

  // When: render
  let html = render_to_string(config)

  // Then: Contains indicator
  html |> string.contains("new-notes-indicator") |> should.be_true()
}

pub fn uses_task_tabs_class_test() {
  // Given: any config
  let config =
    Config(
      active_tab: DetailsTab,
      notes_count: 0,
      has_new_notes: False,
      labels: Labels(details: "D", notes: "N"),
      on_tab_click: fn(_) { Nil },
    )

  // When: render
  let html = render_to_string(config)

  // Then: Uses task-tabs container class
  html |> string.contains("task-tabs") |> should.be_true()
}
