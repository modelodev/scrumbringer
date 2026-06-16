//// Shared button primitive for semantic action hierarchy.
////
//// Feature code owns copy and messages. This module owns the visual contract:
//// intent, scope, shape, size, disabled state, and accessible labels.

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

import scrumbringer_client/ui/icons

/// Visual intent of an action.
pub type Intent {
  Neutral
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

/// Native button behavior.
pub type ButtonType {
  ClickButton
  SubmitButton
}

/// Button configuration.
pub opaque type Config(msg) {
  Config(
    label: String,
    on_click: Option(msg),
    intent: Intent,
    scope: Scope,
    shape: Shape,
    size: Size,
    button_type: ButtonType,
    disabled: Bool,
    autofocus: Bool,
    extra_class: Option(String),
    form_id: Option(String),
    accessible_label: Option(String),
    id: Option(String),
    testid: Option(String),
    tooltip: Option(String),
    stop_propagation: Bool,
    extra_attrs: List(Attribute(msg)),
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
    on_click: Some(on_click),
    intent:,
    scope:,
    shape: Text,
    size: Small,
    button_type: ClickButton,
    disabled: False,
    autofocus: False,
    extra_class: None,
    form_id: None,
    accessible_label: None,
    id: None,
    testid: None,
    tooltip: None,
    stop_propagation: False,
    extra_attrs: [],
  )
}

/// Creates a submit button. Use `with_form` when it submits an external form.
pub fn submit(label: String, intent: Intent, scope: Scope) -> Config(msg) {
  Config(
    label:,
    on_click: None,
    intent:,
    scope:,
    shape: Text,
    size: Small,
    button_type: SubmitButton,
    disabled: False,
    autofocus: False,
    extra_class: None,
    form_id: None,
    accessible_label: None,
    id: None,
    testid: None,
    tooltip: None,
    stop_propagation: False,
    extra_attrs: [],
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
    on_click: Some(on_click),
    intent:,
    scope:,
    shape: Icon(icon),
    size: ExtraSmall,
    button_type: ClickButton,
    disabled: False,
    autofocus: False,
    extra_class: None,
    form_id: None,
    accessible_label: None,
    id: None,
    testid: None,
    tooltip: None,
    stop_propagation: False,
    extra_attrs: [],
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
    on_click: Some(on_click),
    intent:,
    scope:,
    shape: IconText(icon),
    size: Small,
    button_type: ClickButton,
    disabled: False,
    autofocus: False,
    extra_class: None,
    form_id: None,
    accessible_label: None,
    id: None,
    testid: None,
    tooltip: None,
    stop_propagation: False,
    extra_attrs: [],
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

/// Sets native autofocus for dialogs where initial focus should land on an action.
pub fn with_autofocus(config: Config(msg), autofocus: Bool) -> Config(msg) {
  Config(..config, autofocus:)
}

/// Adds a compatibility class owned by the consuming feature.
pub fn with_class(config: Config(msg), extra_class: String) -> Config(msg) {
  let Config(extra_class: existing_class, ..) = config
  let combined_class = case existing_class {
    Some(existing) -> existing <> " " <> extra_class
    None -> extra_class
  }

  Config(..config, extra_class: Some(combined_class))
}

/// Associates the button with a form by id.
pub fn with_form(config: Config(msg), form_id: String) -> Config(msg) {
  Config(..config, form_id: Some(form_id))
}

/// Sets the accessible label and title when they need more context than the
/// visible button text.
pub fn with_accessible_label(config: Config(msg), label: String) -> Config(msg) {
  Config(..config, accessible_label: Some(label))
}

/// Adds an HTML id.
pub fn with_id(config: Config(msg), id: String) -> Config(msg) {
  Config(..config, id: Some(id))
}

/// Adds a test id.
pub fn with_testid(config: Config(msg), testid: String) -> Config(msg) {
  Config(..config, testid: Some(testid))
}

/// Adds a hover/focus tooltip while preserving the accessible label.
pub fn with_tooltip(config: Config(msg), tooltip: String) -> Config(msg) {
  Config(..config, tooltip: Some(tooltip))
}

/// Prevents the click event from bubbling to parent interactive containers.
pub fn with_stop_propagation(config: Config(msg)) -> Config(msg) {
  Config(..config, stop_propagation: True)
}

/// Adds a specific HTML attribute that is not part of the common button contract.
pub fn with_attribute(config: Config(msg), attr: Attribute(msg)) -> Config(msg) {
  Config(..config, extra_attrs: [attr, ..config.extra_attrs])
}

/// Renders a button element.
pub fn view(config: Config(msg)) -> Element(msg) {
  html.button(attrs(config), content(config))
}

fn attrs(config: Config(msg)) {
  let Config(
    label:,
    on_click:,
    button_type:,
    disabled:,
    autofocus:,
    form_id:,
    accessible_label:,
    id:,
    testid:,
    tooltip:,
    stop_propagation:,
    extra_attrs:,
    ..,
  ) = config

  let base =
    list.append(
      [
        attribute.class(class_name(config)),
        attribute.type_(button_type_to_string(button_type)),
        attribute.attribute(
          "title",
          accessible_label_value(label, accessible_label),
        ),
        attribute.attribute(
          "aria-label",
          accessible_label_value(label, accessible_label),
        ),
        attribute.disabled(disabled),
        attribute.autofocus(autofocus),
      ],
      extra_attrs,
    )

  let with_click = case on_click {
    Some(msg) -> list.append(base, [click_attr(msg, stop_propagation)])
    None -> base
  }

  let with_form = case form_id {
    Some(value) -> list.append(with_click, [attribute.form(value)])
    None -> with_click
  }

  let with_id = case id {
    Some(value) -> list.append(with_form, [attribute.id(value)])
    None -> with_form
  }

  let with_testid = case testid {
    Some(value) ->
      list.append(with_id, [attribute.attribute("data-testid", value)])
    None -> with_id
  }

  case tooltip {
    Some(value) ->
      list.append(with_testid, [attribute.attribute("data-tooltip", value)])
    None -> with_testid
  }
}

fn click_attr(msg: msg, stop_propagation: Bool) {
  let attr = event.on_click(msg)

  case stop_propagation {
    True -> event.stop_propagation(attr)
    False -> attr
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
    Neutral, _ -> ""
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

fn button_type_to_string(button_type: ButtonType) -> String {
  case button_type {
    ClickButton -> "button"
    SubmitButton -> "submit"
  }
}

fn option_class(class_name: Option(String)) -> String {
  case class_name {
    Some(value) -> value
    None -> ""
  }
}

fn accessible_label_value(
  label: String,
  accessible_label: Option(String),
) -> String {
  case accessible_label {
    Some(value) -> value
    None -> label
  }
}
