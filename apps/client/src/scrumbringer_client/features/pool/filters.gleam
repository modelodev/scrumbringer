//// Pool Filters Component for Scrumbringer client.
////
//// ## Mission
////
//// Render the filter panel for the pool view with type, capability, and search.
////
//// ## Responsibilities
////
//// - Type filter dropdown
//// - Capability filter dropdown
//// - My capabilities quick toggle
//// - Search input with debounce
////
//// ## Non-responsibilities
////
//// - Filter state management (see features/pool/update.gleam)
//// - Task filtering logic (handled by server)
////
//// ## Relations
////
//// - **features/pool/view.gleam**: Imports and uses this component
//// - **client_state.gleam**: Provides Model, Msg types

import gleam/int
import gleam/list
import gleam/string

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{
  button, div, input, label, option, select, span, text,
}
import lustre/event

import scrumbringer_client/client_state.{
  type Model, type Msg, Loaded, MemberClearFilters, MemberCreateDialogOpened,
  MemberPoolCapabilityChanged, MemberPoolSearchChanged,
  MemberPoolSearchDebounced, MemberPoolTypeChanged,
  MemberToggleMyCapabilitiesQuick, pool_msg,
}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/icons
import scrumbringer_client/update_helpers

/// Counts how many filters are currently active.
fn count_active_filters(model: Model) -> Int {
  let type_active = case string.is_empty(model.member_filters_type_id) {
    True -> 0
    False -> 1
  }
  let cap_active = case string.is_empty(model.member_filters_capability_id) {
    True -> 0
    False -> 1
  }
  let search_active = case string.is_empty(model.member_filters_q) {
    True -> 0
    False -> 1
  }
  let my_caps_active = case model.member_quick_my_caps {
    True -> 1
    False -> 0
  }
  type_active + cap_active + search_active + my_caps_active
}

/// Renders the filter panel with type, capability, and search filters.
pub fn view(model: Model) -> Element(Msg) {
  let type_options = case model.member_task_types {
    Loaded(task_types) -> [
      option(
        [attribute.value("")],
        update_helpers.i18n_t(model, i18n_text.AllOption),
      ),
      ..list.map(task_types, fn(tt) {
        option([attribute.value(int.to_string(tt.id))], tt.name)
      })
    ]

    _ -> [
      option(
        [attribute.value("")],
        update_helpers.i18n_t(model, i18n_text.AllOption),
      ),
    ]
  }

  let capability_options = case model.capabilities {
    Loaded(caps) -> [
      option(
        [attribute.value("")],
        update_helpers.i18n_t(model, i18n_text.AllOption),
      ),
      ..list.map(caps, fn(c) {
        option([attribute.value(int.to_string(c.id))], c.name)
      })
    ]

    _ -> [
      option(
        [attribute.value("")],
        update_helpers.i18n_t(model, i18n_text.AllOption),
      ),
    ]
  }

  let my_caps_active = model.member_quick_my_caps

  let my_caps_class = case my_caps_active {
    True -> "btn-xs btn-icon"
    False -> "btn-xs btn-icon"
  }

  let active_count = count_active_filters(model)

  div([attribute.class("filters-row")], [
    view_type_filter(model, type_options),
    view_capability_filter(model, capability_options),
    view_my_capabilities_toggle(model, my_caps_class, my_caps_active),
    view_search_filter(model),
    view_filter_actions(model, active_count),
  ])
}

/// Renders the filter badge and clear button.
fn view_filter_actions(model: Model, active_count: Int) -> Element(Msg) {
  case active_count {
    0 -> element.none()
    count ->
      div([attribute.class("filter-actions")], [
        span(
          [
            attribute.class("filter-badge"),
            attribute.attribute(
              "aria-label",
              update_helpers.i18n_t(model, i18n_text.ActiveFilters(count)),
            ),
          ],
          [text(int.to_string(count))],
        ),
        button(
          [
            attribute.class("btn-xs btn-clear-filters"),
            attribute.attribute("data-testid", "clear-filters-btn"),
            attribute.attribute(
              "title",
              update_helpers.i18n_t(model, i18n_text.ClearFilters),
            ),
            event.on_click(pool_msg(MemberClearFilters)),
          ],
          [text(update_helpers.i18n_t(model, i18n_text.ClearFilters))],
        ),
      ])
  }
}

fn view_type_filter(
  model: Model,
  options: List(element.Element(Msg)),
) -> Element(Msg) {
  div([attribute.class("field")], [
    span([attribute.class("filter-tooltip")], [
      text(update_helpers.i18n_t(model, i18n_text.TypeLabel)),
    ]),
    span(
      [
        attribute.class("filter-icon"),
        attribute.attribute(
          "title",
          update_helpers.i18n_t(model, i18n_text.TypeLabel),
        ),
        attribute.attribute("aria-hidden", "true"),
      ],
      [icons.nav_icon(icons.TagLabel, icons.Small)],
    ),
    label(
      [
        attribute.class("filter-label"),
        attribute.attribute("for", "pool-filter-type"),
      ],
      [text(update_helpers.i18n_t(model, i18n_text.TypeLabel))],
    ),
    select(
      [
        attribute.attribute("id", "pool-filter-type"),
        attribute.attribute(
          "aria-label",
          update_helpers.i18n_t(model, i18n_text.TypeLabel),
        ),
        attribute.value(model.member_filters_type_id),
        event.on_input(fn(value) { pool_msg(MemberPoolTypeChanged(value)) }),
        attribute.disabled(case model.member_task_types {
          Loaded(_) -> False
          _ -> True
        }),
      ],
      options,
    ),
  ])
}

fn view_capability_filter(
  model: Model,
  options: List(element.Element(Msg)),
) -> Element(Msg) {
  div([attribute.class("field")], [
    span([attribute.class("filter-tooltip")], [
      text(update_helpers.i18n_t(model, i18n_text.CapabilityLabel)),
    ]),
    span(
      [
        attribute.class("filter-icon"),
        attribute.attribute(
          "title",
          update_helpers.i18n_t(model, i18n_text.CapabilityLabel),
        ),
        attribute.attribute("aria-hidden", "true"),
      ],
      [icons.nav_icon(icons.Crosshairs, icons.Small)],
    ),
    label(
      [
        attribute.class("filter-label"),
        attribute.attribute("for", "pool-filter-capability"),
      ],
      [text(update_helpers.i18n_t(model, i18n_text.CapabilityLabel))],
    ),
    select(
      [
        attribute.attribute("id", "pool-filter-capability"),
        attribute.attribute(
          "aria-label",
          update_helpers.i18n_t(model, i18n_text.CapabilityLabel),
        ),
        attribute.value(model.member_filters_capability_id),
        event.on_input(fn(value) {
          pool_msg(MemberPoolCapabilityChanged(value))
        }),
      ],
      options,
    ),
  ])
}

fn view_my_capabilities_toggle(
  model: Model,
  button_class: String,
  is_active: Bool,
) -> Element(Msg) {
  div([attribute.class("field")], [
    span([attribute.class("filter-tooltip")], [
      text(update_helpers.i18n_t(model, i18n_text.MyCapabilitiesLabel)),
    ]),
    span(
      [
        attribute.class("filter-icon"),
        attribute.attribute(
          "title",
          update_helpers.i18n_t(model, i18n_text.MyCapabilitiesLabel),
        ),
        attribute.attribute("aria-hidden", "true"),
      ],
      [icons.nav_icon(icons.Star, icons.Small)],
    ),
    label([attribute.class("filter-label")], [
      text(update_helpers.i18n_t(model, i18n_text.MyCapabilitiesLabel)),
    ]),
    button(
      [
        attribute.class(button_class),
        attribute.attribute(
          "title",
          update_helpers.i18n_t(model, i18n_text.MyCapabilitiesHint),
        ),
        attribute.attribute(
          "aria-label",
          update_helpers.i18n_t(model, i18n_text.MyCapabilitiesLabel)
            <> ": "
            <> case is_active {
            True -> update_helpers.i18n_t(model, i18n_text.MyCapabilitiesOn)
            False -> update_helpers.i18n_t(model, i18n_text.MyCapabilitiesOff)
          },
        ),
        event.on_click(pool_msg(MemberToggleMyCapabilitiesQuick)),
      ],
      [
        case is_active {
          True -> icons.nav_icon(icons.Star, icons.Small)
          False -> icons.nav_icon(icons.StarOutline, icons.Small)
        },
      ],
    ),
  ])
}

fn view_search_filter(model: Model) -> Element(Msg) {
  div([attribute.class("field filter-q")], [
    span([attribute.class("filter-tooltip")], [
      text(update_helpers.i18n_t(model, i18n_text.SearchLabel)),
    ]),
    span(
      [
        attribute.class("filter-icon"),
        attribute.attribute(
          "title",
          update_helpers.i18n_t(model, i18n_text.SearchLabel),
        ),
        attribute.attribute("aria-hidden", "true"),
      ],
      [icons.nav_icon(icons.MagnifyingGlass, icons.Small)],
    ),
    label(
      [
        attribute.class("filter-label"),
        attribute.attribute("for", "pool-filter-q"),
      ],
      [text(update_helpers.i18n_t(model, i18n_text.SearchLabel))],
    ),
    input([
      attribute.attribute("id", "pool-filter-q"),
      attribute.attribute(
        "aria-label",
        update_helpers.i18n_t(model, i18n_text.SearchLabel),
      ),
      attribute.type_("text"),
      attribute.value(model.member_filters_q),
      event.on_input(fn(value) { pool_msg(MemberPoolSearchChanged(value)) }),
      event.debounce(
        event.on_input(fn(value) { pool_msg(MemberPoolSearchDebounced(value)) }),
        350,
      ),
      attribute.placeholder(update_helpers.i18n_t(
        model,
        i18n_text.SearchPlaceholder,
      )),
    ]),
  ])
}

// =============================================================================
// Unified Toolbar (Story 4.8: Single collapsible bar)
// =============================================================================

/// Renders a minimal toolbar with just the new task button.
///
/// Story 4.8 AC40-42: Pool is always canvas mode. Lista is accessible only
/// from main navigation (sidebar). Filters are shown in center_panel header.
pub fn view_unified_toolbar(model: Model) -> Element(Msg) {
  // Simple toolbar: only "Nueva tarea" button
  // Filters are handled by center_panel (top right: Tipo, Capacidad, Buscar)
  div([attribute.class("pool-toolbar pool-toolbar-minimal")], [
    div([attribute.class("pool-toolbar-spacer")], []),
    div([attribute.class("pool-toolbar-right")], [
      button(
        [
          attribute.class("btn-sm btn-primary"),
          attribute.attribute("data-testid", "btn-new-task-pool"),
          event.on_click(pool_msg(MemberCreateDialogOpened)),
        ],
        [
          span([attribute.class("btn-icon-left")], [text("+")]),
          text(update_helpers.i18n_t(model, i18n_text.NewTask)),
        ],
      ),
    ]),
  ])
}
