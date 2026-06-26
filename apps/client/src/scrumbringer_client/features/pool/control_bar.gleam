import gleam/int
import gleam/option.{type Option, None, Some}

import domain/capability.{type Capability}
import domain/task_type.{type TaskType}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, span, text}
import lustre/event

import scrumbringer_client/capability_scope.{
  type CapabilityScope, to_string as capability_scope_to_string,
}
import scrumbringer_client/features/pool/visibility.{
  type PoolVisibility, to_string as visibility_to_string,
}
import scrumbringer_client/features/work_filters_bar
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/pool_prefs
import scrumbringer_client/ui/attribute_value

pub type Config(msg) {
  Config(
    locale: Locale,
    task_types: List(TaskType),
    capabilities: List(Capability),
    capability_scope: CapabilityScope,
    type_filter: Option(Int),
    capability_filter: Option(Int),
    search_query: String,
    visibility: PoolVisibility,
    view_mode: pool_prefs.ViewMode,
    on_capability_scope_change: fn(String) -> msg,
    on_type_filter_change: fn(String) -> msg,
    on_capability_filter_change: fn(String) -> msg,
    on_search_change: fn(String) -> msg,
    on_visibility_change: fn(String) -> msg,
    on_view_mode_change: fn(pool_prefs.ViewMode) -> msg,
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  div(
    [
      attribute.class("pool-control-bar"),
      attribute.attribute("data-testid", "pool-control-bar"),
    ],
    [
      work_filters_bar.view_bar(work_filters_config(config)),
      view_mode_toggle(config),
    ],
  )
}

fn work_filters_config(config: Config(msg)) -> work_filters_bar.Config(msg) {
  work_filters_bar.Config(
    locale: config.locale,
    id_prefix: "pool-work-filter",
    task_types: config.task_types,
    capabilities: config.capabilities,
    capability_scope: config.capability_scope,
    type_filter: config.type_filter,
    capability_filter: config.capability_filter,
    search_query: config.search_query,
    show_search: True,
    show_type: True,
    show_capability: True,
    show_capability_scope: True,
    visibility_control: work_filters_bar.PoolVisibilityControl(
      visibility: config.visibility,
      on_change: fn(visibility) {
        config.on_visibility_change(visibility_to_string(visibility))
      },
    ),
    on_capability_scope_change: fn(scope) {
      config.on_capability_scope_change(capability_scope_to_string(scope))
    },
    on_type_filter_change: fn(value) {
      config.on_type_filter_change(option_int_to_string(value))
    },
    on_capability_filter_change: fn(value) {
      config.on_capability_filter_change(option_int_to_string(value))
    },
    on_search_change: config.on_search_change,
  )
}

fn option_int_to_string(value: Option(Int)) -> String {
  case value {
    Some(i) -> int.to_string(i)
    None -> ""
  }
}

fn view_mode_toggle(config: Config(msg)) -> Element(msg) {
  div([attribute.class("filter-field pool-view-mode-field")], [
    span([attribute.class("filter-label")], [
      text(i18n.t(config.locale, i18n_text.WorkSurfaceView)),
    ]),
    div(
      [
        attribute.class("view-mode-toggle pool-view-mode-toggle"),
        attribute.attribute("data-testid", "pool-view-mode-toggle"),
      ],
      [
        view_mode_button(config, pool_prefs.Canvas, i18n_text.Canvas),
        view_mode_button(config, pool_prefs.List, i18n_text.List),
      ],
    ),
  ])
}

fn view_mode_button(
  config: Config(msg),
  mode: pool_prefs.ViewMode,
  label_key: i18n_text.Text,
) -> Element(msg) {
  let is_active = config.view_mode == mode
  let css = case is_active {
    True -> "view-mode-btn active"
    False -> "view-mode-btn"
  }
  let testid = case mode {
    pool_prefs.Canvas -> "pool-view-mode-canvas"
    pool_prefs.List -> "pool-view-mode-list"
  }

  button(
    [
      attribute.class(css),
      attribute.type_("button"),
      attribute.attribute("data-testid", testid),
      attribute.attribute("aria-pressed", attribute_value.boolean(is_active)),
      event.on_click(config.on_view_mode_change(mode)),
    ],
    [
      span([attribute.class("view-mode-label")], [
        text(i18n.t(config.locale, label_key)),
      ]),
    ],
  )
}
