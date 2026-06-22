import gleam/list
import gleam/option.{type Option, None, Some}

import lustre/attribute
import lustre/element as lelement
import lustre/element/html.{button, div, li, span, text}
import lustre/event

pub type Wrapper {
  Div
  ListItem
}

pub type Config(msg) {
  Config(
    container_class: String,
    content_class: String,
    on_click: Option(msg),
    content_title: Option(String),
    content_label: Option(String),
    leading: Option(lelement.Element(msg)),
    icon: Option(lelement.Element(msg)),
    icon_class: Option(String),
    title: String,
    title_class: Option(String),
    secondary: lelement.Element(msg),
    actions: List(lelement.Element(msg)),
    reserve_actions_slot: Bool,
    action_slot_class: Option(String),
    content_testid: Option(String),
    testid: Option(String),
  )
}

pub fn view(config: Config(msg), wrapper: Wrapper) -> lelement.Element(msg) {
  let Config(
    container_class: container_class,
    content_class: content_class,
    on_click: on_click,
    content_title: content_title,
    content_label: content_label,
    leading: leading,
    icon: icon,
    icon_class: icon_class,
    title: title,
    title_class: title_class,
    secondary: secondary,
    actions: actions,
    reserve_actions_slot: reserve_actions_slot,
    action_slot_class: action_slot_class,
    content_testid: content_testid,
    testid: testid,
  ) = config

  let testid_attr = case testid {
    Some(value) -> [attribute.attribute("data-testid", value)]
    None -> []
  }

  let base_attrs = [attribute.class(container_class)]
  let container_attrs = list.append(base_attrs, testid_attr)

  let icon_css = case icon_class {
    Some(value) -> value
    None -> "task-type-icon"
  }

  let title_css = case title_class {
    Some(value) -> value
    None -> "task-title"
  }

  let icon_el = case icon {
    Some(view) -> span([attribute.class(icon_css)], [view])
    None -> lelement.none()
  }

  let leading_el = case leading {
    Some(view) -> view
    None -> lelement.none()
  }

  let content = case on_click {
    Some(msg) ->
      button(
        content_button_attrs(
          content_class,
          msg,
          content_title,
          content_label,
          content_testid,
        ),
        [
          icon_el,
          span([attribute.class(title_css)], [text(title)]),
          secondary,
        ],
      )
    None ->
      div([attribute.class(content_class)], [
        icon_el,
        span([attribute.class(title_css)], [text(title)]),
        secondary,
      ])
  }

  let slot_class = case action_slot_class {
    Some(value) -> "task-item-action-slot " <> value
    None -> "task-item-action-slot"
  }

  let actions_slot = case actions, reserve_actions_slot {
    [], False -> lelement.none()
    [], True ->
      div([attribute.class(slot_class)], [
        span([attribute.class("task-item-action-slot-placeholder")], []),
      ])
    _, _ -> div([attribute.class(slot_class)], actions)
  }

  let children = [leading_el, content, actions_slot]

  case wrapper {
    Div -> div(container_attrs, children)
    ListItem -> li(container_attrs, children)
  }
}

fn content_button_attrs(
  content_class: String,
  msg: msg,
  content_title: Option(String),
  content_label: Option(String),
  content_testid: Option(String),
) -> List(attribute.Attribute(msg)) {
  let base = [
    attribute.class(content_class),
    attribute.type_("button"),
    event.on_click(msg),
  ]

  let with_title = case content_title {
    Some(value) -> list.append(base, [attribute.attribute("title", value)])
    None -> base
  }

  let with_label = case content_label {
    Some(value) ->
      list.append(with_title, [attribute.attribute("aria-label", value)])
    None -> with_title
  }

  case content_testid {
    Some(value) ->
      list.append(with_label, [attribute.attribute("data-testid", value)])
    None -> with_label
  }
}

pub fn no_actions() -> List(lelement.Element(msg)) {
  []
}

pub fn single_action(
  action: lelement.Element(msg),
) -> List(lelement.Element(msg)) {
  [action]
}

pub fn empty_secondary() -> lelement.Element(msg) {
  lelement.none()
}
