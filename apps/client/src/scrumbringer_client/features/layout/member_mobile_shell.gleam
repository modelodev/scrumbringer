//// Mobile member shell layout.
////
//// Keeps mobile chrome and drawer composition out of the root view assembler.

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, text}

import scrumbringer_client/features/layout/responsive_drawer
import scrumbringer_client/features/now_working/mobile as now_working_mobile
import scrumbringer_client/theme.{type Theme}
import scrumbringer_client/ui/button as ui_button
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
    drawer_button(
      "Open navigation menu",
      icons.Menu,
      "mobile-menu-btn",
      config.left_drawer_open,
      config.on_left_drawer_toggle,
    ),
    div([attribute.class("topbar-title-mobile")], [text(config.title)]),
    drawer_button(
      "Open activity panel",
      icons.UserCircle,
      "mobile-user-btn",
      config.right_drawer_open,
      config.on_right_drawer_toggle,
    ),
  ])
}

fn drawer_button(
  label: String,
  icon: icons.NavIcon,
  class_name: String,
  is_open: Bool,
  on_click: msg,
) -> Element(msg) {
  ui_button.icon(
    label,
    on_click,
    icon,
    ui_button.Neutral,
    ui_button.GlobalAction,
  )
  |> ui_button.with_class(class_name)
  |> ui_button.with_testid(class_name)
  |> ui_button.with_attribute(attribute.attribute(
    "aria-expanded",
    bool_attr(is_open),
  ))
  |> ui_button.view
}

fn bool_attr(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}
