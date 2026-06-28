import gleam/option.{None}
import lustre/element
import support/domain_fixtures
import support/render_assertions

import scrumbringer_client/capability_scope.{AllCapabilities}
import scrumbringer_client/features/pool/control_bar
import scrumbringer_client/features/pool/visibility.{AllOpen}
import scrumbringer_client/i18n/locale
import scrumbringer_client/pool_prefs

pub fn pool_control_bar_renders_visibility_selector_test() {
  let html =
    control_bar.view(config())
    |> element.to_document_string

  render_assertions.contains(html, "data-testid=\"pool-control-bar\"")
  render_assertions.contains(html, "data-testid=\"work-filter-visibility\"")
  render_assertions.contains(html, ">Ver<")
  render_assertions.contains(html, ">Abiertas<")
  render_assertions.contains(html, ">Reclamables<")
  render_assertions.contains(html, ">Bloqueadas<")
}

pub fn pool_control_bar_renders_canvas_list_toggle_test() {
  let html =
    control_bar.view(config())
    |> element.to_document_string

  render_assertions.contains(html, "data-testid=\"pool-view-mode-toggle\"")
  render_assertions.contains(html, "data-testid=\"pool-view-mode-canvas\"")
  render_assertions.contains(html, "data-testid=\"pool-view-mode-list\"")
  render_assertions.contains(html, ">Lienzo<")
  render_assertions.contains(html, ">Lista<")
}

pub fn pool_control_bar_renders_pool_owned_work_filters_test() {
  let html =
    control_bar.view(config())
    |> element.to_document_string

  render_assertions.contains(html, "data-testid=\"work-filter-search\"")
  render_assertions.contains(html, "data-testid=\"work-filter-type\"")
  render_assertions.contains(html, "data-testid=\"work-filter-capability\"")
  render_assertions.contains(
    html,
    "data-testid=\"work-filter-capability-scope\"",
  )
  render_assertions.contains(html, "id=\"pool-work-filter-q\"")
}

fn config() -> control_bar.Config(String) {
  control_bar.Config(
    locale: locale.Es,
    task_types: [domain_fixtures.task_type(1, "Bug")],
    capabilities: [domain_fixtures.capability(2, "Backend")],
    capability_scope: AllCapabilities,
    type_filter: None,
    capability_filter: None,
    search_query: "",
    visibility: AllOpen,
    view_mode: pool_prefs.Canvas,
    on_capability_scope_change: fn(_) { "scope" },
    on_type_filter_change: fn(_) { "type" },
    on_capability_filter_change: fn(_) { "capability" },
    on_search_change: fn(_) { "search" },
    on_visibility_change: fn(_) { "visibility" },
    on_view_mode_change: fn(_) { "view-mode" },
  )
}
