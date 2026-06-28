import gleam/option.{None, Some}
import lustre/element
import lustre/element/html
import support/render_assertions

import scrumbringer_client/ui/action_menu
import scrumbringer_client/ui/inspector_actions

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

  render_assertions.contains(html, "inspector-action-bar")
  render_assertions.contains(html, "card-inspector-actions")
  render_assertions.contains(html, "data-testid=\"inspector-open-in-trigger\"")
  render_assertions.contains(
    html,
    "data-testid=\"inspector-more-actions-trigger\"",
  )
  render_assertions.contains(html, "id=\"card-4-open-in-panel\"")
  render_assertions.contains(html, "id=\"card-4-more-actions-panel\"")
  render_assertions.contains(html, "popover=\"auto\"")
  render_assertions.contains(html, "aria-disabled=\"true\"")
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

  render_assertions.not_contains(html, "inspector-action-bar")
  render_assertions.not_contains(html, "inspector-open-in-trigger")
  render_assertions.not_contains(html, "inspector-more-actions-trigger")
}
