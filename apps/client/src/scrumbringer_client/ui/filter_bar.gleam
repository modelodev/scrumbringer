//// Shared structure for filter toolbars.
////
//// Features own filter meaning and messages. This module keeps grouping,
//// test ids, and common controls consistent.

import gleam/list
import gleam/option.{type Option, None, Some}

import lustre/attribute
import lustre/element.{type Element, none}
import lustre/element/html.{div, input, label, option, select, text}
import lustre/event

/// Select option for filter selects.
pub type SelectOption {
  SelectOption(value: String, label: String, selected: Bool)
}

/// Filter bar configuration.
pub opaque type Config(msg) {
  Config(
    fields: List(Element(msg)),
    actions: List(Element(msg)),
    extra_class: Option(String),
    testid: Option(String),
  )
}

/// Creates a filter bar from field elements.
pub fn new(fields: List(Element(msg))) -> Config(msg) {
  Config(fields:, actions: [], extra_class: None, testid: None)
}

/// Adds actions in a separate slot.
pub fn with_actions(
  config: Config(msg),
  actions: List(Element(msg)),
) -> Config(msg) {
  Config(..config, actions:)
}

/// Adds a feature-specific class.
pub fn with_class(config: Config(msg), extra_class: String) -> Config(msg) {
  Config(..config, extra_class: Some(extra_class))
}

/// Adds a test id.
pub fn with_testid(config: Config(msg), testid: String) -> Config(msg) {
  Config(..config, testid: Some(testid))
}

/// Renders the filter bar.
pub fn view(config: Config(msg)) -> Element(msg) {
  div(root_attrs(config), [
    div([attribute.class("filter-bar-fields")], config.fields),
    case config.actions {
      [] -> none()
      _ -> div([attribute.class("filter-bar-actions")], config.actions)
    },
  ])
}

/// Renders a standalone search input field.
pub fn search_input(
  placeholder: String,
  value: String,
  on_input: fn(String) -> msg,
  testid: String,
  extra_class: String,
) -> Element(msg) {
  input([
    attribute.type_("search"),
    attribute.class(extra_class),
    attribute.attribute("data-testid", testid),
    attribute.placeholder(placeholder),
    attribute.value(value),
    event.on_input(on_input),
  ])
}

/// Renders a labeled select filter.
pub fn select_field(
  label_text: String,
  value: String,
  options: List(SelectOption),
  on_input: fn(String) -> msg,
  testid: String,
) -> Element(msg) {
  div([attribute.class("filter-field")], [
    label([], [text(label_text)]),
    select(
      [
        attribute.attribute("data-testid", testid),
        attribute.value(value),
        event.on_input(on_input),
      ],
      list.map(options, view_select_option),
    ),
  ])
}

fn root_attrs(config: Config(msg)) {
  let class = case config.extra_class {
    Some(extra) -> "filter-bar " <> extra
    None -> "filter-bar"
  }

  list.append([attribute.class(class)], case config.testid {
    Some(value) -> [attribute.attribute("data-testid", value)]
    None -> []
  })
}

fn view_select_option(item: SelectOption) -> Element(msg) {
  option(
    [attribute.value(item.value), attribute.selected(item.selected)],
    item.label,
  )
}
