//// Tests for generic tabs component.

import gleam/option.{None, Some}
import gleam/string
import lustre/element

import scrumbringer_client/ui/tabs.{TabItem}

// =============================================================================
// Test Helpers
// =============================================================================

type TestTab {
  FirstTab
  SecondTab
}

fn render_to_string(cfg: tabs.Config(id, msg)) -> String {
  tabs.view(cfg) |> element.to_string()
}

fn assert_contains(html: String, text: String) {
  let assert True = string.contains(html, text)
}

fn assert_not_contains(html: String, text: String) {
  let assert False = string.contains(html, text)
}

// =============================================================================
// Tests
// =============================================================================

pub fn renders_all_tabs_test() {
  // Given: Config with 2 tabs
  let cfg =
    tabs.config(
      tabs: [
        TabItem(id: FirstTab, label: "First", count: None, has_indicator: False),
        TabItem(
          id: SecondTab,
          label: "Second",
          count: Some(5),
          has_indicator: True,
        ),
      ],
      active: FirstTab,
      container_class: "test-tabs",
      tab_class: "test-tab",
      on_click: fn(_) { Nil },
    )

  // When: render
  let html = render_to_string(cfg)

  // Then: Contains both labels
  assert_contains(html, "First")
  assert_contains(html, "Second")
}

pub fn active_tab_has_correct_class_test() {
  // Given: Config with SecondTab active
  let cfg =
    tabs.config(
      tabs: [
        TabItem(id: FirstTab, label: "Tab A", count: None, has_indicator: False),
        TabItem(
          id: SecondTab,
          label: "Tab B",
          count: None,
          has_indicator: False,
        ),
      ],
      active: SecondTab,
      container_class: "tabs",
      tab_class: "tab",
      on_click: fn(_) { Nil },
    )

  // When: render
  let html = render_to_string(cfg)

  // Then: Contains tab-active class
  assert_contains(html, "tab-active")
}

pub fn count_hidden_when_zero_test() {
  // Given: Tab with count = 0
  let cfg =
    tabs.config(
      tabs: [
        TabItem(
          id: FirstTab,
          label: "Notes",
          count: Some(0),
          has_indicator: False,
        ),
      ],
      active: FirstTab,
      container_class: "tabs",
      tab_class: "tab",
      on_click: fn(_) { Nil },
    )

  // When: render
  let html = render_to_string(cfg)

  // Then: Should NOT contain "(0)"
  assert_not_contains(html, "(0)")
}

pub fn count_shows_when_positive_test() {
  // Given: Tab with count = 7
  let cfg =
    tabs.config(
      tabs: [
        TabItem(
          id: FirstTab,
          label: "Notes",
          count: Some(7),
          has_indicator: False,
        ),
      ],
      active: FirstTab,
      container_class: "tabs",
      tab_class: "tab",
      on_click: fn(_) { Nil },
    )

  // When: render
  let html = render_to_string(cfg)

  // Then: Contains "(7)"
  assert_contains(html, "(7)")
}

pub fn indicator_shows_when_enabled_test() {
  // Given: Tab with has_indicator = True
  let cfg =
    tabs.config(
      tabs: [
        TabItem(id: FirstTab, label: "Notes", count: None, has_indicator: True),
      ],
      active: FirstTab,
      container_class: "tabs",
      tab_class: "tab",
      on_click: fn(_) { Nil },
    )

  // When: render
  let html = render_to_string(cfg)

  // Then: Contains indicator
  assert_contains(html, "new-notes-indicator")
}

pub fn aria_attributes_correct_test() {
  // Given: Config with 2 tabs, first active
  let cfg =
    tabs.config(
      tabs: [
        TabItem(
          id: FirstTab,
          label: "Active",
          count: None,
          has_indicator: False,
        ),
        TabItem(
          id: SecondTab,
          label: "Inactive",
          count: None,
          has_indicator: False,
        ),
      ],
      active: FirstTab,
      container_class: "tabs",
      tab_class: "tab",
      on_click: fn(_) { Nil },
    )

  // When: render
  let html = render_to_string(cfg)

  // Then: Container has tablist role
  assert_contains(html, "role=\"tablist\"")
  // Tabs have tab role
  assert_contains(html, "role=\"tab\"")
  // Active tab has aria-selected="true"
  assert_contains(html, "aria-selected=\"true\"")
  // Tabs are linked to tabpanels
  assert_contains(html, "id=\"modal-tab-0\"")
  assert_contains(html, "aria-controls=\"modal-tabpanel-0\"")
  assert_contains(html, "id=\"modal-tab-1\"")
  assert_contains(html, "aria-controls=\"modal-tabpanel-1\"")
  // Roving tabindex contract
  assert_contains(html, "tabindex=\"0\"")
  assert_contains(html, "tabindex=\"-1\"")
}
