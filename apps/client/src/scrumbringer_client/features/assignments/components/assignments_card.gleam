import lustre/attribute
import lustre/element
import lustre/element/html.{button, div, text}
import lustre/event

import scrumbringer_client/ui/expand_toggle
import scrumbringer_client/ui/icons

pub type Config(msg) {
  Config(
    title: String,
    icon: icons.NavIcon,
    badge: element.Element(msg),
    meta: String,
    expanded: Bool,
    toggle_label: String,
    on_toggle: msg,
    body: element.Element(msg),
  )
}

pub fn view(config: Config(msg)) -> element.Element(msg) {
  let Config(
    title: title,
    icon: icon,
    badge: badge,
    meta: meta,
    expanded: expanded,
    toggle_label: toggle_label,
    on_toggle: on_toggle,
    body: body,
  ) = config

  div([attribute.class("assignments-card")], [
    div([attribute.class("assignments-card-header")], [
      div([attribute.class("assignments-card-title")], [
        button(
          [
            attribute.class("btn-expand"),
            attribute.attribute("aria-label", toggle_label),
            attribute.attribute("aria-expanded", bool_to_string(expanded)),
            event.on_click(on_toggle),
          ],
          [expand_toggle.view(expanded)],
        ),
        span_icon(icon),
        text(title),
        badge,
      ]),
      div([attribute.class("assignments-card-meta")], [text(meta)]),
    ]),
    case expanded {
      True -> div([attribute.class("assignments-card-body")], [body])
      False -> element.none()
    },
  ])
}

fn span_icon(icon: icons.NavIcon) -> element.Element(msg) {
  div([attribute.class("assignments-card-icon")], [
    icons.nav_icon(icon, icons.Small),
  ])
}

fn bool_to_string(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}
