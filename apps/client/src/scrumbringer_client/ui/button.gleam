//// Shared button primitive for semantic action hierarchy.
////
//// Feature code owns copy and messages. This module owns the visual contract:
//// intent, scope, shape, size, disabled state, and accessible labels.

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

import scrumbringer_client/ui/icons

/// Visual intent of an action.
pub type Intent {
  Primary
  Secondary
  Ghost
  Danger
}

/// Product scope of an action.
pub type Scope {
  GlobalAction
  ViewAction
  EntityAction
}

/// Button content shape.
pub type Shape {
  Text
  Icon(icons.NavIcon)
  IconText(icons.NavIcon)
}

/// Button size.
pub type Size {
  Small
  ExtraSmall
}

/// Button configuration.
pub opaque type Config(msg) {
  Config(
    label: String,
    on_click: msg,
    intent: Intent,
    scope: Scope,
    shape: Shape,
    size: Size,
    disabled: Bool,
    extra_class: Option(String),
    id: Option(String),
    testid: Option(String),
  )
}

/// Creates a text button.
pub fn text(
  label: String,
  on_click: msg,
  intent: Intent,
  scope: Scope,
) -> Config(msg) {
  Config(
    label:,
    on_click:,
    intent:,
    scope:,
    shape: Text,
    size: Small,
    disabled: False,
    extra_class: None,
    id: None,
    testid: None,
  )
}

/// Creates an icon-only button. The label is used as `title` and `aria-label`.
pub fn icon(
  label: String,
  on_click: msg,
  icon: icons.NavIcon,
  intent: Intent,
  scope: Scope,
) -> Config(msg) {
  Config(
    label:,
    on_click:,
    intent:,
    scope:,
    shape: Icon(icon),
    size: ExtraSmall,
    disabled: False,
    extra_class: None,
    id: None,
    testid: None,
  )
}

/// Creates a button with icon and visible text.
pub fn icon_text(
  label: String,
  on_click: msg,
  icon: icons.NavIcon,
  intent: Intent,
  scope: Scope,
) -> Config(msg) {
  Config(
    label:,
    on_click:,
    intent:,
    scope:,
    shape: IconText(icon),
    size: Small,
    disabled: False,
    extra_class: None,
    id: None,
    testid: None,
  )
}

/// Sets the size.
pub fn with_size(config: Config(msg), size: Size) -> Config(msg) {
  Config(..config, size:)
}

/// Sets the disabled state.
pub fn with_disabled(config: Config(msg), disabled: Bool) -> Config(msg) {
  Config(..config, disabled:)
}

/// Adds a compatibility class owned by the consuming feature.
pub fn with_class(config: Config(msg), extra_class: String) -> Config(msg) {
  Config(..config, extra_class: Some(extra_class))
}

/// Adds an HTML id.
pub fn with_id(config: Config(msg), id: String) -> Config(msg) {
  Config(..config, id: Some(id))
}

/// Adds a test id.
pub fn with_testid(config: Config(msg), testid: String) -> Config(msg) {
  Config(..config, testid: Some(testid))
}

/// Renders a button element.
pub fn view(config: Config(msg)) -> Element(msg) {
  html.button(attrs(config), content(config))
}

fn attrs(config: Config(msg)) {
  let Config(label:, on_click:, disabled:, id:, testid:, ..) = config

  let base = [
    attribute.class(class_name(config)),
    attribute.type_("button"),
    attribute.attribute("title", label),
    attribute.attribute("aria-label", label),
    attribute.disabled(disabled),
    event.on_click(on_click),
  ]

  let with_id = case id {
    Some(value) -> list.append(base, [attribute.id(value)])
    None -> base
  }

  case testid {
    Some(value) ->
      list.append(with_id, [attribute.attribute("data-testid", value)])
    None -> with_id
  }
}

fn content(config: Config(msg)) -> List(Element(msg)) {
  let Config(label:, shape:, ..) = config

  case shape {
    Text -> [html.text(label)]
    Icon(icon) -> [icons.nav_icon(icon, icons.Small)]
    IconText(icon) -> [
      html.span([attribute.class("btn-icon-prefix")], [
        icons.nav_icon(icon, icons.Small),
      ]),
      html.text(label),
    ]
  }
}

fn class_name(config: Config(msg)) -> String {
  let Config(intent:, scope:, shape:, size:, extra_class:, ..) = config

  [
    "btn",
    intent_class(intent, shape),
    option_class(extra_class),
    scope_class(scope),
    shape_class(shape),
    size_class(size),
  ]
  |> list.filter(fn(class) { !string.is_empty(class) })
  |> string.join(" ")
}

fn intent_class(intent: Intent, shape: Shape) -> String {
  case intent, shape {
    Danger, Icon(_) -> "btn-danger-icon"
    Danger, _ -> "btn-danger"
    Primary, _ -> "btn-primary"
    Secondary, _ -> "btn-secondary"
    Ghost, _ -> "btn-ghost"
  }
}

fn scope_class(scope: Scope) -> String {
  case scope {
    GlobalAction -> "btn-global-action"
    ViewAction -> "btn-view-action"
    EntityAction -> "btn-entity-action"
  }
}

fn shape_class(shape: Shape) -> String {
  case shape {
    Text -> "btn-text"
    Icon(_) -> "btn-icon"
    IconText(_) -> "btn-icon-text"
  }
}

fn size_class(size: Size) -> String {
  case size {
    Small -> "btn-sm"
    ExtraSmall -> "btn-xs"
  }
}

fn option_class(class_name: Option(String)) -> String {
  case class_name {
    Some(value) -> value
    None -> ""
  }
}
