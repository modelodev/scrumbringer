import gleam/list
import lustre/element.{type Element}

import scrumbringer_client/ui/action_menu

pub type MoveOption(msg) {
  MoveOption(label: String, testid: String, on_click: msg)
}

pub fn option(label: String, testid: String, on_click: msg) -> MoveOption(msg) {
  MoveOption(label, testid, on_click)
}

pub fn view(
  trigger_label: String,
  trigger_testid: String,
  options: List(MoveOption(msg)),
) -> Element(msg) {
  action_menu.view(
    trigger_label,
    trigger_testid,
    "move-menu",
    "move-menu-trigger",
    "move-menu-actions",
    "move-menu-option",
    list.map(options, fn(option) {
      let MoveOption(label:, testid:, on_click:) = option
      action_menu.item(label, testid, on_click)
    }),
  )
}
