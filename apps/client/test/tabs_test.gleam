//// Tests for generic tabs component.

import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
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
  html |> string.contains("First") |> should.be_true()
  html |> string.contains("Second") |> should.be_true()
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
  html |> string.contains("tab-active") |> should.be_true()
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
  html |> string.contains("(0)") |> should.be_false()
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
  html |> string.contains("(7)") |> should.be_true()
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
  html |> string.contains("new-notes-indicator") |> should.be_true()
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
  html |> string.contains("role=\"tablist\"") |> should.be_true()
  // Tabs have tab role
  html |> string.contains("role=\"tab\"") |> should.be_true()
  // Active tab has aria-selected="true"
  html |> string.contains("aria-selected=\"true\"") |> should.be_true()
  // Tabs are linked to tabpanels
  html |> string.contains("id=\"modal-tab-0\"") |> should.be_true()
  html
  |> string.contains("aria-controls=\"modal-tabpanel-0\"")
  |> should.be_true()
  html |> string.contains("id=\"modal-tab-1\"") |> should.be_true()
  html
  |> string.contains("aria-controls=\"modal-tabpanel-1\"")
  |> should.be_true()
  // Roving tabindex contract
  html |> string.contains("tabindex=\"0\"") |> should.be_true()
  html |> string.contains("tabindex=\"-1\"") |> should.be_true()
}
