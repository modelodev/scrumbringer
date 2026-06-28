//// Tests for generic tabs component.

import gleam/option.{None, Some}
import lustre/element
import support/render_assertions

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
  render_assertions.contains(html, "First")
  render_assertions.contains(html, "Second")
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
  render_assertions.contains(html, "tab-active")
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
  render_assertions.not_contains(html, "(0)")
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
  render_assertions.contains(html, "(7)")
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
  render_assertions.contains(html, "new-notes-indicator")
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
  render_assertions.contains(html, "role=\"tablist\"")
  // Tabs have tab role
  render_assertions.contains(html, "role=\"tab\"")
  // Active tab has aria-selected="true"
  render_assertions.contains(html, "aria-selected=\"true\"")
  // Tabs are linked to tabpanels
  render_assertions.contains(html, "id=\"modal-tab-0\"")
  render_assertions.contains(html, "aria-controls=\"modal-tabpanel-0\"")
  render_assertions.contains(html, "id=\"modal-tab-1\"")
  render_assertions.contains(html, "aria-controls=\"modal-tabpanel-1\"")
  // Roving tabindex contract
  render_assertions.contains(html, "tabindex=\"0\"")
  render_assertions.contains(html, "tabindex=\"-1\"")
}
