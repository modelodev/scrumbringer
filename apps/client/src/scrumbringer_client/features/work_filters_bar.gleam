import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

import domain/capability.{type Capability}
import domain/task_type.{type TaskType}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{
  button, div, input, label, option as html_option, select, span, text,
}
import lustre/event

import scrumbringer_client/capability_scope.{
  type CapabilityScope, AllCapabilities, MyCapabilities,
}
import scrumbringer_client/features/pool/visibility as pool_visibility
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/attribute_value

pub type Config(msg) {
  Config(
    locale: Locale,
    id_prefix: String,
    task_types: List(TaskType),
    capabilities: List(Capability),
    capability_scope: CapabilityScope,
    type_filter: Option(Int),
    capability_filter: Option(Int),
    search_query: String,
    show_search: Bool,
    show_type: Bool,
    show_capability: Bool,
    show_capability_scope: Bool,
    visibility_control: VisibilityControl(msg),
    on_capability_scope_change: fn(CapabilityScope) -> msg,
    on_type_filter_change: fn(Option(Int)) -> msg,
    on_capability_filter_change: fn(Option(Int)) -> msg,
    on_search_change: fn(String) -> msg,
  )
}

pub type VisibilityControl(msg) {
  NoVisibilityControl
  PoolVisibilityControl(
    visibility: pool_visibility.PoolVisibility,
    on_change: fn(pool_visibility.PoolVisibility) -> msg,
  )
}

type Layout {
  Bar
  Refinement
}

pub fn view_bar(config: Config(msg)) -> Element(msg) {
  div(
    [
      attribute.class("work-filter-bar"),
      attribute.attribute("data-testid", "work-filter-bar"),
    ],
    view_controls(config, Bar),
  )
}

pub fn view_bar_controls(config: Config(msg)) -> List(Element(msg)) {
  view_controls(config, Bar)
}

pub fn view_refinement_controls(config: Config(msg)) -> List(Element(msg)) {
  view_controls(config, Refinement)
}

pub fn view_capability_scope_control(config: Config(msg)) -> Element(msg) {
  view_scope(config, Refinement)
}

fn view_controls(config: Config(msg), layout: Layout) -> List(Element(msg)) {
  [
    case config.show_search {
      True -> [view_search(config, layout)]
      False -> []
    },
    case config.show_type {
      True -> [view_type_filter(config, layout)]
      False -> []
    },
    case config.show_capability {
      True -> [view_capability_filter(config, layout)]
      False -> []
    },
    case config.show_capability_scope {
      True -> [view_scope(config, layout)]
      False -> []
    },
    case config.visibility_control {
      PoolVisibilityControl(visibility, on_change) -> [
        view_visibility_filter(config, layout, visibility, on_change),
      ]
      NoVisibilityControl -> []
    },
  ]
  |> list.flatten
}

fn view_search(config: Config(msg), layout: Layout) -> Element(msg) {
  let input_id = config.id_prefix <> "-q"

  case layout {
    Bar ->
      div([attribute.class("filter-field filter-search")], [
        label([attribute.attribute("for", input_id)], [
          text(i18n.t(config.locale, i18n_text.SearchLabel)),
        ]),
        input([
          attribute.id(input_id),
          attribute.attribute("data-testid", "work-filter-search"),
          attribute.type_("search"),
          attribute.placeholder(i18n.t(
            config.locale,
            i18n_text.SearchPlaceholder,
          )),
          attribute.value(config.search_query),
          event.on_input(config.on_search_change),
        ]),
      ])

    Refinement ->
      label(
        [attribute.class("plan-filter-control work-filter-search-control")],
        [
          span([], [text(i18n.t(config.locale, i18n_text.SearchLabel))]),
          input([
            attribute.type_("search"),
            attribute.attribute("data-testid", "work-filter-search"),
            attribute.placeholder(i18n.t(
              config.locale,
              i18n_text.SearchPlaceholder,
            )),
            attribute.value(config.search_query),
            event.on_input(config.on_search_change),
          ]),
        ],
      )
  }
}

fn view_type_filter(config: Config(msg), layout: Layout) -> Element(msg) {
  let attrs = [
    attribute.attribute("data-testid", "work-filter-type"),
    attribute.value(option_int_to_string(config.type_filter)),
    event.on_change(fn(value) {
      config.on_type_filter_change(option_int_from_string(value))
    }),
  ]
  let options =
    list.append(
      [
        html_option(
          [attribute.value("")],
          i18n.t(config.locale, i18n_text.AllOption),
        ),
      ],
      list.map(config.task_types, fn(task_type) {
        html_option(
          [
            attribute.value(int.to_string(task_type.id)),
            attribute.selected(Some(task_type.id) == config.type_filter),
          ],
          task_type.name,
        )
      }),
    )

  view_select_field(
    layout,
    config.id_prefix <> "-type-select",
    i18n.t(config.locale, i18n_text.TypeLabel),
    attrs,
    options,
  )
}

fn view_capability_filter(config: Config(msg), layout: Layout) -> Element(msg) {
  let attrs = [
    attribute.attribute("data-testid", "work-filter-capability"),
    attribute.value(option_int_to_string(config.capability_filter)),
    event.on_change(fn(value) {
      config.on_capability_filter_change(option_int_from_string(value))
    }),
  ]
  let options =
    list.append(
      [
        html_option(
          [attribute.value("")],
          i18n.t(config.locale, i18n_text.AllOption),
        ),
      ],
      list.map(config.capabilities, fn(capability) {
        html_option(
          [
            attribute.value(int.to_string(capability.id)),
            attribute.selected(Some(capability.id) == config.capability_filter),
          ],
          capability.name,
        )
      }),
    )

  view_select_field(
    layout,
    config.id_prefix <> "-capability-select",
    i18n.t(config.locale, i18n_text.CapabilityLabel),
    attrs,
    options,
  )
}

fn view_select_field(
  layout: Layout,
  id: String,
  label_text: String,
  attrs: List(attribute.Attribute(msg)),
  options: List(Element(msg)),
) -> Element(msg) {
  case layout {
    Bar ->
      div([attribute.class("filter-field")], [
        label([attribute.attribute("for", id)], [text(label_text)]),
        select([attribute.id(id), ..attrs], options),
      ])

    Refinement ->
      label([attribute.class("plan-filter-control")], [
        span([], [text(label_text)]),
        select(attrs, options),
      ])
  }
}

fn view_scope(config: Config(msg), layout: Layout) -> Element(msg) {
  let label_text = i18n.t(config.locale, i18n_text.CapabilityScopeLabel)
  let toggle =
    div(
      [
        attribute.class("scope-toggle"),
        attribute.attribute("data-testid", "work-filter-capability-scope"),
      ],
      [
        view_scope_toggle_button(config, AllCapabilities, i18n_text.ScopeAll),
        view_scope_toggle_button(config, MyCapabilities, i18n_text.ScopeMine),
      ],
    )

  case layout {
    Bar ->
      div(
        [
          attribute.class(
            "filter-field filter-field-scope work-filter-scope-control",
          ),
        ],
        [
          label([], [text(label_text)]),
          toggle,
        ],
      )

    Refinement ->
      label([attribute.class("plan-filter-control work-filter-scope-control")], [
        span([], [text(label_text)]),
        toggle,
      ])
  }
}

fn view_scope_toggle_button(
  config: Config(msg),
  scope: CapabilityScope,
  label_key: i18n_text.Text,
) -> Element(msg) {
  let is_active = config.capability_scope == scope
  let css = case is_active {
    True -> "scope-toggle-btn is-active"
    False -> "scope-toggle-btn"
  }

  button(
    [
      attribute.class(css),
      attribute.type_("button"),
      attribute.attribute(
        "data-testid",
        "work-filter-capability-scope-" <> capability_scope.to_string(scope),
      ),
      attribute.attribute("aria-pressed", attribute_value.boolean(is_active)),
      event.on_click(config.on_capability_scope_change(scope)),
    ],
    [text(i18n.t(config.locale, label_key))],
  )
}

fn view_visibility_filter(
  config: Config(msg),
  layout: Layout,
  visibility: pool_visibility.PoolVisibility,
  on_change: fn(pool_visibility.PoolVisibility) -> msg,
) -> Element(msg) {
  let attrs = [
    attribute.attribute("data-testid", "work-filter-visibility"),
    attribute.value(pool_visibility.to_string(visibility)),
    event.on_change(fn(value) {
      on_change(visibility_from_string(visibility, value))
    }),
  ]
  let options = [
    visibility_option(config, visibility, pool_visibility.AllOpen),
    visibility_option(config, visibility, pool_visibility.ReadyToClaim),
    visibility_option(config, visibility, pool_visibility.Blocked),
  ]

  view_select_field(
    layout,
    config.id_prefix <> "-visibility-select",
    i18n.t(config.locale, i18n_text.PoolVisibilityLabel),
    attrs,
    options,
  )
}

fn visibility_option(
  config: Config(msg),
  current: pool_visibility.PoolVisibility,
  item: pool_visibility.PoolVisibility,
) -> Element(msg) {
  html_option(
    [
      attribute.value(pool_visibility.to_string(item)),
      attribute.selected(current == item),
    ],
    pool_visibility.label(config.locale, item),
  )
}

fn option_int_to_string(value: Option(Int)) -> String {
  case value {
    Some(i) -> int.to_string(i)
    None -> ""
  }
}

fn option_int_from_string(value: String) -> Option(Int) {
  case string.trim(value) {
    "" -> None
    raw -> {
      case int.parse(raw) {
        Ok(i) -> Some(i)
        Error(_) -> None
      }
    }
  }
}

fn visibility_from_string(
  current: pool_visibility.PoolVisibility,
  value: String,
) -> pool_visibility.PoolVisibility {
  case pool_visibility.parse(value) {
    Ok(visibility) -> visibility
    Error(_) -> current
  }
}
