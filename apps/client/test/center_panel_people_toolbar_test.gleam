import lustre/element/html
import support/render_assertions

import scrumbringer_client/features/layout/center_panel
import scrumbringer_client/i18n/locale

import domain/view_mode

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
    |> render_assertions.html

  render_assertions.contains(html, "data-testid=\"people-view\"")
  render_assertions.not_contains(html, "data-testid=\"people-toolbar\"")
  render_assertions.not_contains(html, "data-testid=\"filter-search-people\"")
  render_assertions.not_contains(html, "data-testid=\"filter-type\"")
  render_assertions.not_contains(html, "data-testid=\"filter-capability\"")
}

pub fn pool_toolbar_is_owned_by_pool_view_test() {
  let html =
    center_panel.view(base_config(view_mode.Pool))
    |> render_assertions.html

  render_assertions.contains(html, "data-testid=\"pool-canvas\"")
  render_assertions.not_contains(html, "data-testid=\"filter-type\"")
  render_assertions.not_contains(html, "data-testid=\"filter-capability\"")
  render_assertions.not_contains(
    html,
    "data-testid=\"filter-capability-scope\"",
  )
}

pub fn plan_toolbar_does_not_render_pool_filters_test() {
  let html =
    center_panel.view(base_config(view_mode.Cards))
    |> render_assertions.html

  render_assertions.contains(html, "data-testid=\"plan-view\"")
  render_assertions.not_contains(html, "data-testid=\"filter-type\"")
  render_assertions.not_contains(html, "data-testid=\"filter-capability\"")
  render_assertions.not_contains(
    html,
    "data-testid=\"filter-capability-scope\"",
  )
}

pub fn capabilities_toolbar_does_not_render_global_pool_filters_test() {
  let html =
    center_panel.view(base_config(view_mode.Capabilities))
    |> render_assertions.html

  render_assertions.contains(html, "data-testid=\"capabilities-view\"")
  render_assertions.not_contains(html, "data-testid=\"capabilities-toolbar\"")
  render_assertions.not_contains(html, "data-testid=\"filter-type\"")
  render_assertions.not_contains(
    html,
    "data-testid=\"filter-search-capabilities\"",
  )
  render_assertions.not_contains(
    html,
    "data-testid=\"filter-capability-scope\"",
  )
  render_assertions.not_contains(html, "data-testid=\"filter-capability\"")
}
