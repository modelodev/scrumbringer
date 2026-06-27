import gleam/option.{None, Some}
import gleam/string
import lustre/element
import lustre/element/html

import scrumbringer_client/ui/action_menu
import scrumbringer_client/ui/inspector_actions

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

pub fn inspector_actions_renders_shared_open_and_more_menus_test() {
  let html =
    inspector_actions.view(inspector_actions.Config(
      id: "card-4",
      primary: Some(html.button([], [html.text("Create")])),
      open_in_label: "Open in",
      open_in_items: [
        action_menu.link_item("Plan", "open-plan", "/app?view=cards"),
      ],
      more_label: "More actions",
      more_items: [
        action_menu.item("Move", "move-action", "move"),
        action_menu.disabled_item("Delete", "delete-action", "No", "delete"),
      ],
      extra_class: "card-inspector-actions",
    ))
    |> element.to_document_string

  assert_contains(html, "inspector-action-bar")
  assert_contains(html, "card-inspector-actions")
  assert_contains(html, "data-testid=\"inspector-open-in-trigger\"")
  assert_contains(html, "data-testid=\"inspector-more-actions-trigger\"")
  assert_contains(html, "id=\"card-4-open-in-panel\"")
  assert_contains(html, "id=\"card-4-more-actions-panel\"")
  assert_contains(html, "popover=\"auto\"")
  assert_contains(html, "aria-disabled=\"true\"")
}

pub fn inspector_actions_omits_empty_menus_test() {
  let html =
    inspector_actions.view(inspector_actions.Config(
      id: "task-8",
      primary: None,
      open_in_label: "Open in",
      open_in_items: [],
      more_label: "More actions",
      more_items: [],
      extra_class: "task-inspector-actions",
    ))
    |> element.to_document_string

  assert_not_contains(html, "inspector-action-bar")
  assert_not_contains(html, "inspector-open-in-trigger")
  assert_not_contains(html, "inspector-more-actions-trigger")
}
