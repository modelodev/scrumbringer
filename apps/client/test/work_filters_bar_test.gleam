import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/element
import lustre/element/html

import domain/capability.{Capability}
import domain/task_type.{TaskType}
import scrumbringer_client/capability_scope
import scrumbringer_client/features/pool/visibility
import scrumbringer_client/features/work_filters_bar
import scrumbringer_client/i18n/locale

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

pub fn work_filters_bar_renders_scope_control_with_active_state_test() {
  let html =
    config()
    |> work_filters_bar.view_capability_scope_control
    |> element.to_document_string

  assert_contains(html, "data-testid=\"work-filter-capability-scope\"")
  assert_contains(html, "data-testid=\"work-filter-capability-scope-all\"")
  assert_contains(html, "data-testid=\"work-filter-capability-scope-mine\"")
  assert_contains(html, ">Capacidades<")
  assert_contains(html, ">Todas<")
  assert_contains(html, ">Mías<")
  assert_contains(html, "aria-pressed=\"true\"")
}

pub fn work_filters_bar_renders_enabled_controls_with_stable_testids_test() {
  let html =
    config()
    |> work_filters_bar.view_bar
    |> element.to_document_string

  assert_contains(html, "data-testid=\"work-filter-bar\"")
  assert_contains(html, "data-testid=\"work-filter-search\"")
  assert_contains(html, "data-testid=\"work-filter-type\"")
  assert_contains(html, "data-testid=\"work-filter-capability\"")
  assert_contains(html, "data-testid=\"work-filter-capability-scope\"")
  assert_contains(html, "data-testid=\"work-filter-visibility\"")
  assert_contains(html, ">Bug<")
  assert_contains(html, ">Backend<")
}

pub fn work_filters_bar_hides_disabled_controls_test() {
  let html =
    work_filters_bar.Config(
      ..config(),
      show_search: False,
      show_type: False,
      show_capability: False,
      visibility_control: work_filters_bar.NoVisibilityControl,
    )
    |> work_filters_bar.view_bar
    |> element.to_document_string

  assert_not_contains(html, "data-testid=\"work-filter-search\"")
  assert_not_contains(html, "data-testid=\"work-filter-type\"")
  assert_not_contains(html, "data-testid=\"work-filter-capability\"")
  assert_not_contains(html, "data-testid=\"work-filter-visibility\"")
  assert_contains(html, "data-testid=\"work-filter-capability-scope\"")
}

pub fn work_filters_bar_refinement_controls_fit_plan_scope_bar_test() {
  let html =
    html.div([], work_filters_bar.view_refinement_controls(config()))
    |> element.to_document_string

  assert_contains(html, "plan-filter-control")
  assert_contains(html, "data-testid=\"work-filter-capability-scope\"")
  assert_contains(html, "data-testid=\"work-filter-search\"")
}

fn config() -> work_filters_bar.Config(String) {
  work_filters_bar.Config(
    locale: locale.Es,
    id_prefix: "test-work-filter",
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
    capability_scope: capability_scope.AllCapabilities,
    type_filter: None,
    capability_filter: None,
    search_query: "",
    show_search: True,
    show_type: True,
    show_capability: True,
    show_capability_scope: True,
    visibility_control: work_filters_bar.PoolVisibilityControl(
      visibility: visibility.AllOpen,
      on_change: fn(value) { "visibility:" <> visibility.to_string(value) },
    ),
    on_capability_scope_change: fn(value) {
      "scope:" <> capability_scope.to_string(value)
    },
    on_type_filter_change: fn(value) { "type:" <> option_int_to_string(value) },
    on_capability_filter_change: fn(value) {
      "cap:" <> option_int_to_string(value)
    },
    on_search_change: fn(value) { "search:" <> value },
  )
}

fn option_int_to_string(value: Option(Int)) -> String {
  case value {
    Some(i) -> int.to_string(i)
    None -> ""
  }
}
