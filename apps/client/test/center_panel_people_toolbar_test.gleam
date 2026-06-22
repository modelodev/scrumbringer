import gleam/string
import lustre/element
import lustre/element/html

import scrumbringer_client/features/layout/center_panel
import scrumbringer_client/i18n/locale

import domain/view_mode

fn assert_contains(html: String, text: String) {
  let assert True = string.contains(html, text)
}

fn assert_not_contains(html: String, text: String) {
  let assert False = string.contains(html, text)
}

fn base_config(
  mode: view_mode.ViewMode,
) -> center_panel.CenterPanelConfig(String) {
  center_panel.CenterPanelConfig(
    locale: locale.En,
    view_mode: mode,
    pool_content: html.text("pool"),
    cards_content: html.text("cards"),
    capabilities_content: html.text("capabilities"),
    people_content: html.text("people"),
    on_drag_move: fn(_x, _y) { "msg" },
    on_drag_end: "msg",
  )
}

pub fn people_toolbar_is_owned_by_people_view_test() {
  let html =
    center_panel.view(base_config(view_mode.People))
    |> element.to_document_string

  assert_contains(html, "data-testid=\"people-view\"")
  assert_not_contains(html, "data-testid=\"people-toolbar\"")
  assert_not_contains(html, "data-testid=\"filter-search-people\"")
  assert_not_contains(html, "data-testid=\"filter-type\"")
  assert_not_contains(html, "data-testid=\"filter-capability\"")
}

pub fn pool_toolbar_is_owned_by_pool_view_test() {
  let html =
    center_panel.view(base_config(view_mode.Pool))
    |> element.to_document_string

  assert_contains(html, "data-testid=\"pool-canvas\"")
  assert_not_contains(html, "data-testid=\"filter-type\"")
  assert_not_contains(html, "data-testid=\"filter-capability\"")
  assert_not_contains(html, "data-testid=\"filter-capability-scope\"")
}

pub fn plan_toolbar_does_not_render_pool_filters_test() {
  let html =
    center_panel.view(base_config(view_mode.Cards))
    |> element.to_document_string

  assert_contains(html, "data-testid=\"plan-view\"")
  assert_not_contains(html, "data-testid=\"filter-type\"")
  assert_not_contains(html, "data-testid=\"filter-capability\"")
  assert_not_contains(html, "data-testid=\"filter-capability-scope\"")
}

pub fn capabilities_toolbar_does_not_render_global_pool_filters_test() {
  let html =
    center_panel.view(base_config(view_mode.Capabilities))
    |> element.to_document_string

  assert_contains(html, "data-testid=\"capabilities-view\"")
  assert_not_contains(html, "data-testid=\"capabilities-toolbar\"")
  assert_not_contains(html, "data-testid=\"filter-type\"")
  assert_not_contains(html, "data-testid=\"filter-search-capabilities\"")
  assert_not_contains(html, "data-testid=\"filter-capability-scope\"")
  assert_not_contains(html, "data-testid=\"filter-capability\"")
}
