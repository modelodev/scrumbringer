//// Center Panel - Main content area with filters and view content
////
//// Mission: Render the center panel content based on current view mode,
//// including toolbar with filters and view content.
////
//// Responsibilities:
//// - Filter controls (type, capability, search)
//// - Content routing based on view mode
////
//// Non-responsibilities:
//// - View mode navigation (handled by sidebar - Story 4.8 UX)
//// - Individual view implementations (delegated to view modules)
//// - State management (handled by parent)

import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, input, label, option, select, text}
import lustre/event

import domain/capability.{type Capability}
import domain/task_type.{type TaskType}
import domain/view_mode.{
  type ViewMode, Capabilities, Cards, Milestones, People, Pool,
}
import scrumbringer_client/capability_scope.{
  type CapabilityScope, AllCapabilities, MyCapabilities,
}
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/event_decoders

// =============================================================================
// Types
// =============================================================================

/// Configuration for the center panel
pub type CenterPanelConfig(msg) {
  CenterPanelConfig(
    locale: Locale,
    view_mode: ViewMode,
    on_view_mode_change: fn(ViewMode) -> msg,
    // Filters
    task_types: List(TaskType),
    capabilities: List(Capability),
    capability_scope: CapabilityScope,
    type_filter: Option(Int),
    capability_filter: Option(Int),
    search_query: String,
    on_capability_scope_change: fn(String) -> msg,
    on_type_filter_change: fn(String) -> msg,
    on_capability_filter_change: fn(String) -> msg,
    on_search_change: fn(String) -> msg,
    // Content
    pool_content: Element(msg),
    milestones_content: Element(msg),
    cards_content: Element(msg),
    capabilities_content: Element(msg),
    people_content: Element(msg),
    // Drag handlers for pool (Story 4.7 fix)
    on_drag_move: fn(Int, Int) -> msg,
    on_drag_end: msg,
  )
}

// =============================================================================
// View
// =============================================================================

/// Renders the center panel with toolbar and content
pub fn view(config: CenterPanelConfig(msg)) -> Element(msg) {
  div([attribute.class("center-panel-content")], [
    // Toolbar: view mode toggle + filters
    view_toolbar(config),
    // Content based on view mode
    view_content(config),
  ])
}

fn view_toolbar(config: CenterPanelConfig(msg)) -> Element(msg) {
  div([attribute.class("center-toolbar")], [
    // Filters only - navigation moved to sidebar (Story 4.8 UX)
    view_filters(config),
  ])
}

fn view_filters(config: CenterPanelConfig(msg)) -> Element(msg) {
  case config.view_mode {
    People -> view_people_filters(config)
    Milestones -> element.none()
    Capabilities ->
      view_work_filters_variant(
        config,
        show_capability_filter: False,
        toolbar_testid: Some("capabilities-toolbar"),
        search_testid: Some("filter-search-capabilities"),
      )
    _ -> view_work_filters(config)
  }
}

fn view_work_filters(config: CenterPanelConfig(msg)) -> Element(msg) {
  view_work_filters_variant(
    config,
    show_capability_filter: True,
    toolbar_testid: None,
    search_testid: None,
  )
}

fn view_work_filters_variant(
  config: CenterPanelConfig(msg),
  show_capability_filter show_capability_filter: Bool,
  toolbar_testid toolbar_testid: Option(String),
  search_testid search_testid: Option(String),
) -> Element(msg) {
  let toolbar_class = case show_capability_filter {
    True -> "center-filters center-filters-work"
    False -> "center-filters center-filters-work center-filters-capabilities"
  }
  let search_attrs =
    list.append(
      [
        attribute.type_("search"),
        attribute.placeholder(i18n.t(config.locale, i18n_text.SearchPlaceholder)),
        attribute.value(config.search_query),
        event.on_input(config.on_search_change),
      ],
      optional_testid(search_testid),
    )
  let toolbar_attrs =
    list.append(
      [attribute.class(toolbar_class)],
      optional_testid(toolbar_testid),
    )
  let type_options =
    list.append(
      [
        option(
          [attribute.value("")],
          i18n.t(config.locale, i18n_text.AllOption),
        ),
      ],
      list_map(config.task_types, fn(tt) {
        option(
          [
            attribute.value(int_to_string(tt.id)),
            attribute.selected(Some(tt.id) == config.type_filter),
          ],
          tt.name,
        )
      }),
    )
  let capability_options =
    list.append(
      [
        option(
          [attribute.value("")],
          i18n.t(config.locale, i18n_text.AllOption),
        ),
      ],
      list_map(config.capabilities, fn(cap) {
        option(
          [
            attribute.value(int_to_string(cap.id)),
            attribute.selected(Some(cap.id) == config.capability_filter),
          ],
          cap.name,
        )
      }),
    )
  let capability_filter_element = case show_capability_filter {
    True ->
      div([attribute.class("filter-field")], [
        label([], [text(i18n.t(config.locale, i18n_text.CapabilityLabel))]),
        select(
          [
            attribute.attribute("data-testid", "filter-capability"),
            attribute.value(option_int_to_string(config.capability_filter)),
            event.on_input(config.on_capability_filter_change),
          ],
          capability_options,
        ),
      ])
    False -> element.none()
  }

  div(toolbar_attrs, [
    view_capability_scope_filter(config),
    // Type filter
    div([attribute.class("filter-field")], [
      label([], [text(i18n.t(config.locale, i18n_text.TypeLabel))]),
      select(
        [
          attribute.attribute("data-testid", "filter-type"),
          attribute.value(option_int_to_string(config.type_filter)),
          event.on_input(config.on_type_filter_change),
        ],
        type_options,
      ),
    ]),
    capability_filter_element,
    // Search
    div([attribute.class("filter-field filter-search")], [
      label([], [text(i18n.t(config.locale, i18n_text.SearchLabel))]),
      input(search_attrs),
    ]),
  ])
}

fn view_capability_scope_filter(config: CenterPanelConfig(msg)) -> Element(msg) {
  div(
    [
      attribute.class("filter-field filter-field-scope"),
      attribute.attribute("data-testid", "filter-capability-scope"),
    ],
    [
      label([], [text(i18n.t(config.locale, i18n_text.MyCapabilitiesLabel))]),
      div([attribute.class("scope-toggle")], [
        view_scope_button(config, AllCapabilities, i18n_text.ScopeAll),
        view_scope_button(config, MyCapabilities, i18n_text.ScopeMine),
      ]),
    ],
  )
}

fn view_scope_button(
  config: CenterPanelConfig(msg),
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
        "filter-capability-scope-" <> capability_scope.to_string(scope),
      ),
      attribute.attribute("aria-pressed", case is_active {
        True -> "true"
        False -> "false"
      }),
      event.on_click(
        config.on_capability_scope_change(capability_scope.to_string(scope)),
      ),
    ],
    [text(i18n.t(config.locale, label_key))],
  )
}

fn view_people_filters(config: CenterPanelConfig(msg)) -> Element(msg) {
  div(
    [
      attribute.class("center-filters center-filters-people"),
      attribute.attribute("data-testid", "people-toolbar"),
    ],
    [
      div([attribute.class("filter-field filter-search")], [
        label([], [text(i18n.t(config.locale, i18n_text.SearchLabel))]),
        input([
          attribute.type_("search"),
          attribute.attribute("data-testid", "filter-search-people"),
          attribute.placeholder(i18n.t(
            config.locale,
            i18n_text.PeopleSearchPlaceholder,
          )),
          attribute.value(config.search_query),
          event.on_input(config.on_search_change),
        ]),
      ]),
    ],
  )
}

fn view_content(config: CenterPanelConfig(msg)) -> Element(msg) {
  let content = case config.view_mode {
    Pool -> config.pool_content
    Cards -> config.cards_content
    Capabilities -> config.capabilities_content
    People -> config.people_content
    Milestones -> config.milestones_content
  }

  let testid = case config.view_mode {
    Pool -> "pool-canvas"
    Cards -> "kanban-board"
    Capabilities -> "capabilities-view"
    People -> "people-view"
    Milestones -> "milestones-view"
  }

  // Add drag handlers for Pool view (Story 4.7 fix)
  let attrs = case config.view_mode {
    Pool -> [
      attribute.class("center-content pool-drag-area"),
      attribute.attribute("data-testid", testid),
      event.on(
        "mousemove",
        event_decoders.mouse_client_position(config.on_drag_move),
      ),
      event.on("mouseup", event_decoders.message(config.on_drag_end)),
      event.on("mouseleave", event_decoders.message(config.on_drag_end)),
    ]
    _ -> [
      attribute.class("center-content"),
      attribute.attribute("data-testid", testid),
    ]
  }

  div(attrs, [content])
}

// =============================================================================
// Helpers
// =============================================================================

import gleam/int
import gleam/list

fn int_to_string(i: Int) -> String {
  int.to_string(i)
}

fn option_int_to_string(opt: Option(Int)) -> String {
  case opt {
    Some(i) -> int.to_string(i)
    None -> ""
  }
}

fn list_map(items: List(a), f: fn(a) -> b) -> List(b) {
  list.map(items, f)
}

fn optional_testid(testid: Option(String)) -> List(attribute.Attribute(msg)) {
  case testid {
    Some(value) -> [attribute.attribute("data-testid", value)]
    None -> []
  }
}
