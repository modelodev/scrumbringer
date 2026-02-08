//// Semantic wrappers for icon-only actions.
////
//// Keeps feature views expressive (`icon_actions.delete(...)`) while reusing
//// the shared `action_buttons` rendering contracts.

import lustre/element.{type Element}

import scrumbringer_client/ui/action_buttons

pub fn edit(title: String, on_click: msg) -> Element(msg) {
  action_buttons.edit_button(title, on_click)
}

pub fn edit_with_testid(
  title: String,
  on_click: msg,
  testid: String,
) -> Element(msg) {
  action_buttons.edit_button_with_testid(title, on_click, testid)
}

pub fn delete(title: String, on_click: msg) -> Element(msg) {
  action_buttons.delete_button(title, on_click)
}

pub fn delete_with_testid(
  title: String,
  on_click: msg,
  testid: String,
) -> Element(msg) {
  action_buttons.delete_button_with_testid(title, on_click, testid)
}

pub fn settings(title: String, on_click: msg) -> Element(msg) {
  action_buttons.settings_button(title, on_click)
}

pub fn settings_with_testid(
  title: String,
  on_click: msg,
  testid: String,
) -> Element(msg) {
  action_buttons.settings_button_with_testid(title, on_click, testid)
}
