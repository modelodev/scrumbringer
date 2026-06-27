//// Shared action bar for Card Show and Task Show inspectors.

import gleam/option.{type Option, None, Some}

import lustre/attribute
import lustre/element.{type Element, none}
import lustre/element/html.{div}

import scrumbringer_client/ui/action_menu
import scrumbringer_client/ui/icons

pub type Config(msg) {
  Config(
    id: String,
    primary: Option(Element(msg)),
    open_in_label: String,
    open_in_items: List(action_menu.Item(msg)),
    more_label: String,
    more_items: List(action_menu.Item(msg)),
    extra_class: String,
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  case config.primary, config.open_in_items, config.more_items {
    None, [], [] -> none()
    _, _, _ ->
      div(
        [
          attribute.class(
            "inspector-actions inspector-action-bar " <> config.extra_class,
          ),
        ],
        [
          case config.primary {
            Some(primary) ->
              div([attribute.class("inspector-primary-action")], [primary])
            None -> none()
          },
          open_in_menu(config),
          more_menu(config),
        ],
      )
  }
}

fn open_in_menu(config: Config(msg)) -> Element(msg) {
  action_menu.view_with_trigger(
    action_menu.IconTrigger(
      label: config.open_in_label,
      icon: icons.ExternalLink,
    ),
    "inspector-open-in-trigger",
    config.id <> "-open-in",
    "inspector-action-menu inspector-open-in-menu",
    "inspector-action-trigger inspector-open-in-trigger",
    "inspector-action-panel inspector-open-in-panel",
    "inspector-action-item inspector-open-in-item",
    config.open_in_items,
  )
}

fn more_menu(config: Config(msg)) -> Element(msg) {
  action_menu.view_with_trigger(
    action_menu.IconTrigger(
      label: config.more_label,
      icon: icons.MoreHorizontal,
    ),
    "inspector-more-actions-trigger",
    config.id <> "-more-actions",
    "inspector-action-menu inspector-more-actions-menu",
    "inspector-action-trigger inspector-more-actions-trigger",
    "inspector-action-panel inspector-more-actions-panel",
    "inspector-action-item inspector-more-actions-item",
    config.more_items,
  )
}
