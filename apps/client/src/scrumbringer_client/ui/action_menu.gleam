import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element, none}
import lustre/element/html.{a, button, div, text}
import lustre/event

import scrumbringer_client/ui/icons

pub type Item(msg) {
  ButtonItem(
    label: String,
    testid: String,
    on_click: msg,
    disabled: Bool,
    title: Option(String),
  )
  LinkItem(label: String, testid: String, href: String)
}

pub type Trigger {
  IconTrigger(label: String, icon: icons.NavIcon)
}

pub fn item(label: String, testid: String, on_click: msg) -> Item(msg) {
  ButtonItem(label, testid, on_click, False, None)
}

pub fn disabled_item(
  label: String,
  testid: String,
  reason: String,
  on_click: msg,
) -> Item(msg) {
  ButtonItem(label, testid, on_click, True, Some(reason))
}

pub fn link_item(label: String, testid: String, href: String) -> Item(msg) {
  LinkItem(label, testid, href)
}

pub fn view_with_trigger(
  trigger: Trigger,
  trigger_testid: String,
  menu_id: String,
  menu_class: String,
  trigger_class: String,
  items_class: String,
  item_class: String,
  items: List(Item(msg)),
) -> Element(msg) {
  case items {
    [] -> none()
    _ -> {
      let panel_id = menu_id <> "-panel"

      div(
        [
          attribute.class("action-menu " <> menu_class),
          attribute.attribute("data-testid", menu_class),
        ],
        [
          button(
            [
              attribute.class("action-menu-trigger " <> trigger_class),
              attribute.attribute("data-testid", trigger_testid),
              attribute.attribute("type", "button"),
              attribute.attribute("role", "button"),
              attribute.attribute("aria-label", trigger_label(trigger)),
              attribute.attribute("title", trigger_label(trigger)),
              attribute.attribute("aria-haspopup", "menu"),
              attribute.attribute("aria-controls", panel_id),
              attribute.attribute("popovertarget", panel_id),
              attribute.attribute("style", anchor_name(menu_id)),
            ],
            trigger_children(trigger),
          ),
          div(
            [
              attribute.class("action-menu-panel " <> items_class),
              attribute.attribute("id", panel_id),
              attribute.attribute("popover", "auto"),
              attribute.attribute("role", "menu"),
              attribute.attribute("style", anchor_position(menu_id)),
            ],
            list.map(items, fn(menu_item) {
              case menu_item {
                ButtonItem(label:, testid:, on_click:, disabled:, title:) ->
                  button(
                    [
                      attribute.class("action-menu-item " <> item_class),
                      attribute.attribute("data-testid", testid),
                      attribute.attribute("type", "button"),
                      attribute.attribute("role", "menuitem"),
                      attribute.attribute(
                        "aria-disabled",
                        bool_string(disabled),
                      ),
                      attribute.attribute("title", option_to_string(title)),
                      attribute.attribute("popovertarget", panel_id),
                      attribute.attribute("popovertargetaction", "hide"),
                      attribute.disabled(disabled),
                      event.on_click(on_click),
                    ],
                    [text(label)],
                  )
                LinkItem(label:, testid:, href:) ->
                  a(
                    [
                      attribute.class("action-menu-item " <> item_class),
                      attribute.attribute("data-testid", testid),
                      attribute.href(href),
                      attribute.attribute("role", "menuitem"),
                    ],
                    [text(label)],
                  )
              }
            }),
          ),
        ],
      )
    }
  }
}

fn anchor_name(menu_id: String) -> String {
  "anchor-name: --" <> menu_id <> "-anchor;"
}

fn anchor_position(menu_id: String) -> String {
  "position-anchor: --"
  <> menu_id
  <> "-anchor; inset: auto; top: anchor(bottom); right: anchor(right); margin: 6px 0 0; position-try-fallbacks: flip-block, flip-inline;"
}

fn trigger_label(trigger: Trigger) -> String {
  case trigger {
    IconTrigger(label:, ..) -> label
  }
}

fn trigger_children(trigger: Trigger) -> List(Element(msg)) {
  case trigger {
    IconTrigger(label:, icon:) -> [
      icons.nav_icon(icon, icons.Small),
      element.element("span", [attribute.class("sr-only")], [text(label)]),
    ]
  }
}

fn option_to_string(value: Option(String)) -> String {
  case value {
    Some(text) -> text
    None -> ""
  }
}

fn bool_string(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}
