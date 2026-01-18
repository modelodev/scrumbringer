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

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, input, label, option, select, span, text}
import lustre/event

import scrumbringer_client/client_state.{
  type Model, type Msg, Loaded,
  MemberPoolCapabilityChanged, MemberPoolSearchChanged,
  MemberPoolSearchDebounced, MemberPoolTypeChanged,
  MemberToggleMyCapabilitiesQuick,
}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/update_helpers

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

  div([attribute.class("filters-row")], [
    view_type_filter(model, type_options),
    view_capability_filter(model, capability_options),
    view_my_capabilities_toggle(model, my_caps_class, my_caps_active),
    view_search_filter(model),
  ])
}

fn view_type_filter(model: Model, options: List(element.Element(Msg))) -> Element(Msg) {
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
      [text("🏷")],
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
        event.on_input(MemberPoolTypeChanged),
        attribute.disabled(case model.member_task_types {
          Loaded(_) -> False
          _ -> True
        }),
      ],
      options,
    ),
  ])
}

fn view_capability_filter(model: Model, options: List(element.Element(Msg))) -> Element(Msg) {
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
      [text("🎯")],
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
        event.on_input(MemberPoolCapabilityChanged),
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
      [text("★")],
    ),
    label([attribute.class("filter-label")], [
      text(update_helpers.i18n_t(model, i18n_text.MyCapabilitiesLabel)),
    ]),
    button(
      [
        attribute.class(button_class),
        attribute.attribute(
          "title",
          update_helpers.i18n_t(model, i18n_text.MyCapabilitiesLabel),
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
        event.on_click(MemberToggleMyCapabilitiesQuick),
      ],
      [
        text(case is_active {
          True -> "★"
          False -> "☆"
        }),
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
      [text("⌕")],
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
      event.on_input(MemberPoolSearchChanged),
      event.debounce(event.on_input(MemberPoolSearchDebounced), 350),
      attribute.placeholder(update_helpers.i18n_t(
        model,
        i18n_text.SearchPlaceholder,
      )),
    ]),
  ])
}
