import gleam/int
import gleam/option.{type Option, None, Some}
import lustre/element
import lustre/element/html
import support/render_assertions

import domain/capability.{Capability}
import domain/task_type.{TaskType}
import scrumbringer_client/capability_scope
import scrumbringer_client/features/pool/visibility
import scrumbringer_client/features/work_filters_bar
import scrumbringer_client/i18n/locale

pub fn work_filters_bar_renders_scope_control_with_active_state_test() {
  let html =
    config()
    |> work_filters_bar.view_capability_scope_control
    |> element.to_document_string

  render_assertions.contains(
    html,
    "data-testid=\"work-filter-capability-scope\"",
  )
  render_assertions.contains(
    html,
    "data-testid=\"work-filter-capability-scope-all\"",
  )
  render_assertions.contains(
    html,
    "data-testid=\"work-filter-capability-scope-mine\"",
  )
  render_assertions.contains(html, ">Capacidades<")
  render_assertions.contains(html, ">Todas<")
  render_assertions.contains(html, ">Mías<")
  render_assertions.contains(html, "aria-pressed=\"true\"")
}

pub fn work_filters_bar_renders_enabled_controls_with_stable_testids_test() {
  let html =
    config()
    |> work_filters_bar.view_bar
    |> element.to_document_string

  render_assertions.contains(html, "data-testid=\"work-filter-bar\"")
  render_assertions.contains(html, "data-testid=\"work-filter-search\"")
  render_assertions.contains(html, "data-testid=\"work-filter-type\"")
  render_assertions.contains(html, "data-testid=\"work-filter-capability\"")
  render_assertions.contains(
    html,
    "data-testid=\"work-filter-capability-scope\"",
  )
  render_assertions.contains(html, "data-testid=\"work-filter-visibility\"")
  render_assertions.contains(html, ">Bug<")
  render_assertions.contains(html, ">Backend<")
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

  render_assertions.not_contains(html, "data-testid=\"work-filter-search\"")
  render_assertions.not_contains(html, "data-testid=\"work-filter-type\"")
  render_assertions.not_contains(html, "data-testid=\"work-filter-capability\"")
  render_assertions.not_contains(html, "data-testid=\"work-filter-visibility\"")
  render_assertions.contains(
    html,
    "data-testid=\"work-filter-capability-scope\"",
  )
}

pub fn work_filters_bar_refinement_controls_fit_plan_scope_bar_test() {
  let html =
    html.div([], work_filters_bar.view_refinement_controls(config()))
    |> element.to_document_string

  render_assertions.contains(html, "plan-filter-control")
  render_assertions.contains(
    html,
    "data-testid=\"work-filter-capability-scope\"",
  )
  render_assertions.contains(html, "data-testid=\"work-filter-search\"")
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
