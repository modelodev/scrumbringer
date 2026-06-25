import gleam/string
import lustre/element

import scrumbringer_client/ui/button
import scrumbringer_client/ui/filter_bar

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

pub fn filter_bar_search_preserves_value_placeholder_and_testid_test() {
  let html =
    filter_bar.new([
      filter_bar.search_input(
        "Search tasks",
        "api",
        fn(value) { value },
        "filter-search",
        "custom-search",
      ),
    ])
    |> filter_bar.with_class("task-filters")
    |> filter_bar.with_testid("task-filter-bar")
    |> filter_bar.view
    |> element.to_document_string

  assert_contains(html, "filter-bar task-filters")
  assert_contains(html, "data-testid=\"task-filter-bar\"")
  assert_contains(html, "data-testid=\"filter-search\"")
  assert_contains(html, "placeholder=\"Search tasks\"")
  assert_contains(html, "value=\"api\"")
  assert_contains(html, "custom-search")
}

pub fn filter_bar_select_renders_options_and_selected_value_test() {
  let html =
    filter_bar.new([
      filter_bar.select_field(
        "Type",
        "2",
        [
          filter_bar.SelectOption("", "All", False),
          filter_bar.SelectOption("2", "Feature", True),
        ],
        fn(value) { value },
        "filter-type",
      ),
    ])
    |> filter_bar.view
    |> element.to_document_string

  assert_contains(html, "data-testid=\"filter-type\"")
  assert_contains(html, "value=\"2\"")
  assert_contains(html, ">All<")
  assert_contains(html, ">Feature<")
  assert_contains(html, "selected")
}

pub fn filter_bar_checkbox_and_actions_use_separate_slots_test() {
  let html =
    filter_bar.new([
      filter_bar.checkbox_chip(
        "Show closed",
        True,
        fn(value) { value },
        "filter-closed",
        "filter-chip",
        "filter-checkbox",
      ),
    ])
    |> filter_bar.with_actions([
      button.text("Clear", False, button.Ghost, button.ViewAction)
      |> button.view,
    ])
    |> filter_bar.view
    |> element.to_document_string

  assert_contains(html, "filter-bar-fields")
  assert_contains(html, "filter-bar-actions")
  assert_contains(html, "data-testid=\"filter-closed\"")
  assert_contains(html, "checked")
  assert_contains(html, "Show closed")
  assert_contains(html, ">Clear<")
}
