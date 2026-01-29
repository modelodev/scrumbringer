//// Generic tab bar component.
////
//// ## Mission
////
//// Provides a reusable, type-safe tab navigation system.
//// Extracted from card_tabs.gleam to enable DRY reuse across
//// card detail modal and task detail modal contexts.
////
//// ## Usage
////
//// ```gleam
//// tabs.view(tabs.config(
////   tabs: [
////     tabs.TabItem(id: MyTab1, label: "First", count: None, has_indicator: False),
////     tabs.TabItem(id: MyTab2, label: "Second", count: Some(5), has_indicator: True),
////   ],
////   active: MyTab1,
////   container_class: "my-tabs",
////   tab_class: "my-tab",
////   on_click: fn(id) { TabClicked(id) },
//// ))
//// ```

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, span, text}
import lustre/event

// =============================================================================
// Types
// =============================================================================

/// A single tab item configuration.
pub type TabItem(id) {
  TabItem(id: id, label: String, count: Option(Int), has_indicator: Bool)
}

/// Configuration for the generic tabs component.
pub type Config(id, msg) {
  Config(
    tabs: List(TabItem(id)),
    active: id,
    container_class: String,
    tab_class: String,
    on_click: fn(id) -> msg,
  )
}

// =============================================================================
// Constructors
// =============================================================================

/// Create a tabs configuration.
pub fn config(
  tabs tabs: List(TabItem(id)),
  active active: id,
  container_class container_class: String,
  tab_class tab_class: String,
  on_click on_click: fn(id) -> msg,
) -> Config(id, msg) {
  Config(tabs:, active:, container_class:, tab_class:, on_click:)
}

// =============================================================================
// View
// =============================================================================

/// Renders the tab bar with ARIA attributes for accessibility.
pub fn view(cfg: Config(id, msg)) -> Element(msg) {
  let Config(tabs:, active:, container_class:, tab_class:, on_click:) = cfg

  div(
    [attribute.class(container_class), attribute.role("tablist")],
    list.map(tabs, fn(item) {
      tab_button(item, item.id == active, tab_class, on_click)
    }),
  )
}

// =============================================================================
// Internal
// =============================================================================

fn tab_button(
  item: TabItem(id),
  is_active: Bool,
  base_class: String,
  on_click: fn(id) -> msg,
) -> Element(msg) {
  let active_class = case is_active {
    True -> base_class <> " tab-active"
    False -> base_class
  }

  button(
    [
      attribute.class(active_class),
      attribute.role("tab"),
      attribute.attribute("aria-selected", bool_to_string(is_active)),
      event.on_click(on_click(item.id)),
    ],
    [
      text(item.label),
      view_count(item.count),
      view_indicator(item.has_indicator),
    ],
  )
}

fn view_count(count: Option(Int)) -> Element(msg) {
  case count {
    Some(n) if n > 0 ->
      span([attribute.class("tab-count")], [
        text(" (" <> int.to_string(n) <> ")"),
      ])
    Some(_) -> element.none()
    None -> element.none()
  }
}

fn view_indicator(has_indicator: Bool) -> Element(msg) {
  case has_indicator {
    True -> span([attribute.class("new-notes-indicator")], [text("●")])
    False -> element.none()
  }
}

fn bool_to_string(b: Bool) -> String {
  case b {
    True -> "true"
    False -> "false"
  }
}
