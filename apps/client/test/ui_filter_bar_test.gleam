import lustre/element
import support/render_assertions

import scrumbringer_client/ui/filter_bar

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

  render_assertions.contains(html, "filter-bar task-filters")
  render_assertions.contains(html, "data-testid=\"task-filter-bar\"")
  render_assertions.contains(html, "data-testid=\"filter-search\"")
  render_assertions.contains(html, "placeholder=\"Search tasks\"")
  render_assertions.contains(html, "value=\"api\"")
  render_assertions.contains(html, "custom-search")
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

  render_assertions.contains(html, "data-testid=\"filter-type\"")
  render_assertions.contains(html, "value=\"2\"")
  render_assertions.contains(html, ">All<")
  render_assertions.contains(html, ">Feature<")
  render_assertions.contains(html, "selected")
}
