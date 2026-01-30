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
    icon: Option(lelement.Element(msg)),
    icon_class: Option(String),
    title: String,
    title_class: Option(String),
    secondary: lelement.Element(msg),
    actions: List(lelement.Element(msg)),
    testid: Option(String),
  )
}

pub fn view(config: Config(msg), wrapper: Wrapper) -> lelement.Element(msg) {
  let Config(
    container_class: container_class,
    content_class: content_class,
    on_click: on_click,
    icon: icon,
    icon_class: icon_class,
    title: title,
    title_class: title_class,
    secondary: secondary,
    actions: actions,
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

  let content = case on_click {
    Some(msg) ->
      button([attribute.class(content_class), event.on_click(msg)], [
        icon_el,
        span([attribute.class(title_css)], [text(title)]),
        secondary,
      ])
    None ->
      div([attribute.class(content_class)], [
        icon_el,
        span([attribute.class(title_css)], [text(title)]),
        secondary,
      ])
  }

  let children = [content, ..actions]

  case wrapper {
    Div -> div(container_attrs, children)
    ListItem -> li(container_attrs, children)
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
