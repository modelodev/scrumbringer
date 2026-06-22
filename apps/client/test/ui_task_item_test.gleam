import gleam/option as opt
import gleam/string
import lustre/element
import lustre/element/html

import scrumbringer_client/ui/task_item

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

pub fn clickable_task_item_preserves_accessible_button_metadata_test() {
  let html =
    task_item.view(
      task_item.Config(
        container_class: "task-item",
        content_class: "task-item-content",
        on_click: opt.Some("open"),
        content_title: opt.Some("Fix login"),
        content_label: opt.Some("Open task: Fix login"),
        leading: opt.None,
        icon: opt.None,
        icon_class: opt.None,
        title: "Fix login",
        title_class: opt.None,
        secondary: html.span([], []),
        actions: task_item.no_actions(),
        reserve_actions_slot: False,
        action_slot_class: opt.None,
        content_testid: opt.Some("shared-task-item-open"),
        testid: opt.Some("shared-task-item"),
      ),
      task_item.Div,
    )
    |> element.to_document_string

  assert_contains(html, "data-testid=\"shared-task-item\"")
  assert_contains(html, "data-testid=\"shared-task-item-open\"")
  assert_contains(html, "title=\"Fix login\"")
  assert_contains(html, "aria-label=\"Open task: Fix login\"")
  assert_contains(html, "type=\"button\"")
}
