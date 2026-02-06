import gleam/option
import gleam/string
import gleeunit/should
import lustre/element
import lustre/element/html

import scrumbringer_client/features/layout/center_panel
import scrumbringer_client/i18n/locale

import domain/view_mode

fn base_config(
  mode: view_mode.ViewMode,
) -> center_panel.CenterPanelConfig(String) {
  center_panel.CenterPanelConfig(
    locale: locale.En,
    view_mode: mode,
    on_view_mode_change: fn(_mode) { "msg" },
    task_types: [],
    capabilities: [],
    type_filter: option.None,
    capability_filter: option.None,
    search_query: "",
    on_type_filter_change: fn(_value) { "msg" },
    on_capability_filter_change: fn(_value) { "msg" },
    on_search_change: fn(_value) { "msg" },
    pool_content: html.text("pool"),
    list_content: html.text("list"),
    cards_content: html.text("cards"),
    people_content: html.text("people"),
    on_drag_move: fn(_x, _y) { "msg" },
    on_drag_end: "msg",
  )
}

pub fn people_toolbar_renders_only_search_test() {
  let html =
    center_panel.view(base_config(view_mode.People))
    |> element.to_document_string

  string.contains(html, "data-testid=\"people-toolbar\"") |> should.be_true
  string.contains(html, "data-testid=\"filter-search-people\"")
  |> should.be_true
  string.contains(html, "data-testid=\"filter-type\"") |> should.be_false
  string.contains(html, "data-testid=\"filter-capability\"") |> should.be_false
}

pub fn work_toolbar_keeps_type_and_capability_filters_test() {
  let html =
    center_panel.view(base_config(view_mode.Pool))
    |> element.to_document_string

  string.contains(html, "data-testid=\"filter-type\"") |> should.be_true
  string.contains(html, "data-testid=\"filter-capability\"") |> should.be_true
}
