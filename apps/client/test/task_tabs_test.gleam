//// Tests for task tabs component.

import gleam/string
import lustre/element

import scrumbringer_client/ui/task_tabs.{
  type Config, Config, Labels, NotesTab, TasksTab,
}

// =============================================================================
// Test Helpers
// =============================================================================

fn render_to_string(config: Config(msg)) -> String {
  task_tabs.view(config) |> element.to_string()
}

fn assert_contains(html: String, text: String) {
  let assert True = string.contains(html, text)
}

// =============================================================================
// Tests
// =============================================================================

pub fn renders_tasks_notes_and_metrics_tabs_test() {
  // Given: Config with TasksTab active
  let config =
    Config(
      active_tab: TasksTab,
      notes_count: 3,
      has_new_notes: True,
      labels: Labels(tasks: "Tareas", notes: "Notas", metrics: "Metricas"),
      on_tab_click: fn(_) { Nil },
    )

  // When: render
  let html = render_to_string(config)

  // Then: Contains both tab labels
  assert_contains(html, "Tareas")
  assert_contains(html, "Notas")
  assert_contains(html, "Metricas")
  assert_contains(html, "(3)")
}

pub fn active_tab_has_active_class_test() {
  // Given: Config with NotesTab active
  let config =
    Config(
      active_tab: NotesTab,
      notes_count: 0,
      has_new_notes: False,
      labels: Labels(tasks: "Tasks", notes: "Notes", metrics: "Metrics"),
      on_tab_click: fn(_) { Nil },
    )

  // When: render
  let html = render_to_string(config)

  // Then: Contains tab-active class
  assert_contains(html, "tab-active")
}

pub fn shows_new_notes_indicator_test() {
  // Given: has_new_notes = True
  let config =
    Config(
      active_tab: TasksTab,
      notes_count: 5,
      has_new_notes: True,
      labels: Labels(tasks: "Tasks", notes: "Notes", metrics: "Metrics"),
      on_tab_click: fn(_) { Nil },
    )

  // When: render
  let html = render_to_string(config)

  // Then: Contains indicator
  assert_contains(html, "new-notes-indicator")
}

pub fn uses_task_tabs_class_test() {
  // Given: any config
  let config =
    Config(
      active_tab: TasksTab,
      notes_count: 0,
      has_new_notes: False,
      labels: Labels(tasks: "T", notes: "N", metrics: "M"),
      on_tab_click: fn(_) { Nil },
    )

  // When: render
  let html = render_to_string(config)

  // Then: Uses task-tabs container class
  assert_contains(html, "task-tabs")
}
