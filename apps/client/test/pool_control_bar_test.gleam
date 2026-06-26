import gleam/option.{None}
import gleam/string
import lustre/element

import domain/capability.{Capability}
import domain/task_type.{TaskType}
import scrumbringer_client/capability_scope.{AllCapabilities}
import scrumbringer_client/features/pool/control_bar
import scrumbringer_client/features/pool/visibility.{AllOpen}
import scrumbringer_client/i18n/locale
import scrumbringer_client/pool_prefs

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

pub fn pool_control_bar_renders_visibility_selector_test() {
  let html =
    control_bar.view(config())
    |> element.to_document_string

  assert_contains(html, "data-testid=\"pool-control-bar\"")
  assert_contains(html, "data-testid=\"work-filter-visibility\"")
  assert_contains(html, ">Ver<")
  assert_contains(html, ">Abiertas<")
  assert_contains(html, ">Reclamables<")
  assert_contains(html, ">Bloqueadas<")
}

pub fn pool_control_bar_renders_canvas_list_toggle_test() {
  let html =
    control_bar.view(config())
    |> element.to_document_string

  assert_contains(html, "data-testid=\"pool-view-mode-toggle\"")
  assert_contains(html, "data-testid=\"pool-view-mode-canvas\"")
  assert_contains(html, "data-testid=\"pool-view-mode-list\"")
  assert_contains(html, ">Lienzo<")
  assert_contains(html, ">Lista<")
}

pub fn pool_control_bar_renders_pool_owned_work_filters_test() {
  let html =
    control_bar.view(config())
    |> element.to_document_string

  assert_contains(html, "data-testid=\"work-filter-search\"")
  assert_contains(html, "data-testid=\"work-filter-type\"")
  assert_contains(html, "data-testid=\"work-filter-capability\"")
  assert_contains(html, "data-testid=\"work-filter-capability-scope\"")
  assert_contains(html, "id=\"pool-work-filter-q\"")
}

fn config() -> control_bar.Config(String) {
  control_bar.Config(
    locale: locale.Es,
    task_types: [
      TaskType(
        id: 1,
        name: "Bug",
        icon: "bug-ant",
        capability_id: None,
        tasks_count: 0,
      ),
    ],
    capabilities: [Capability(id: 2, name: "Backend")],
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
