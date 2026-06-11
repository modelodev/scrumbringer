//// Mobile member shell layout.
////
//// Keeps mobile chrome and drawer composition out of the root view assembler.

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, text}
import lustre/event

import scrumbringer_client/features/layout/responsive_drawer
import scrumbringer_client/features/now_working/mobile as now_working_mobile
import scrumbringer_client/theme.{type Theme}
import scrumbringer_client/ui/icons

pub type Config(msg) {
  Config(
    title: String,
    theme: Theme,
    left_drawer_open: Bool,
    right_drawer_open: Bool,
    main_content: Element(msg),
    left_content: Element(msg),
    right_content: Element(msg),
    now_working: now_working_mobile.Config(msg),
    on_left_drawer_toggle: msg,
    on_right_drawer_toggle: msg,
    on_drawers_close: msg,
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  div([attribute.class("member member-mobile")], [
    view_topbar(config),
    div(
      [
        attribute.class("content member-content-mobile"),
        attribute.attribute("id", "main-content"),
        attribute.attribute("tabindex", "-1"),
      ],
      [config.main_content],
    ),
    now_working_mobile.view_mini_bar(config.now_working),
    now_working_mobile.view_overlay(config.now_working),
    now_working_mobile.view_panel_sheet(config.now_working),
    responsive_drawer.view(
      config.left_drawer_open,
      responsive_drawer.Left,
      config.on_drawers_close,
      config.left_content,
    ),
    responsive_drawer.view(
      config.right_drawer_open,
      responsive_drawer.Right,
      config.on_drawers_close,
      config.right_content,
    ),
  ])
}

fn view_topbar(config: Config(msg)) -> Element(msg) {
  div([attribute.class("mobile-topbar")], [
    button(
      [
        attribute.class("mobile-menu-btn"),
        attribute.attribute("data-testid", "mobile-menu-btn"),
        attribute.attribute("aria-label", "Open navigation menu"),
        attribute.attribute("aria-expanded", bool_attr(config.left_drawer_open)),
        event.on_click(config.on_left_drawer_toggle),
      ],
      [icons.view_heroicon_inline("bars-3", 24, config.theme)],
    ),
    div([attribute.class("topbar-title-mobile")], [text(config.title)]),
    button(
      [
        attribute.class("mobile-user-btn"),
        attribute.attribute("data-testid", "mobile-user-btn"),
        attribute.attribute("aria-label", "Open activity panel"),
        attribute.attribute(
          "aria-expanded",
          bool_attr(config.right_drawer_open),
        ),
        event.on_click(config.on_right_drawer_toggle),
      ],
      [icons.view_heroicon_inline("user-circle", 24, config.theme)],
    ),
  ])
}

fn bool_attr(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}
