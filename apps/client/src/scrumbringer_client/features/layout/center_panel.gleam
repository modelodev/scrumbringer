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
import lustre/element/html.{div, input, label, option, select, text}
import lustre/event

import domain/capability.{type Capability}
import domain/task_type.{type TaskType}
import domain/view_mode.{type ViewMode, Cards, Milestones, People, Pool}
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
    type_filter: Option(Int),
    capability_filter: Option(Int),
    search_query: String,
    on_type_filter_change: fn(String) -> msg,
    on_capability_filter_change: fn(String) -> msg,
    on_search_change: fn(String) -> msg,
    // Content
    pool_content: Element(msg),
    milestones_content: Element(msg),
    cards_content: Element(msg),
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
    _ -> view_work_filters(config)
  }
}

fn view_work_filters(config: CenterPanelConfig(msg)) -> Element(msg) {
  div([attribute.class("center-filters")], [
    // Type filter
    div([attribute.class("filter-field")], [
      label([], [text(i18n.t(config.locale, i18n_text.TypeLabel))]),
      select(
        [
          attribute.attribute("data-testid", "filter-type"),
          attribute.value(option_int_to_string(config.type_filter)),
          event.on_input(config.on_type_filter_change),
        ],
        [
          option(
            [attribute.value("")],
            i18n.t(config.locale, i18n_text.AllOption),
          ),
          ..list_map(config.task_types, fn(tt) {
            option(
              [
                attribute.value(int_to_string(tt.id)),
                attribute.selected(Some(tt.id) == config.type_filter),
              ],
              tt.name,
            )
          })
        ],
      ),
    ]),
    // Capability filter
    div([attribute.class("filter-field")], [
      label([], [text(i18n.t(config.locale, i18n_text.CapabilityLabel))]),
      select(
        [
          attribute.attribute("data-testid", "filter-capability"),
          attribute.value(option_int_to_string(config.capability_filter)),
          event.on_input(config.on_capability_filter_change),
        ],
        [
          option(
            [attribute.value("")],
            i18n.t(config.locale, i18n_text.AllOption),
          ),
          ..list_map(config.capabilities, fn(cap) {
            option(
              [
                attribute.value(int_to_string(cap.id)),
                attribute.selected(Some(cap.id) == config.capability_filter),
              ],
              cap.name,
            )
          })
        ],
      ),
    ]),
    // Search
    div([attribute.class("filter-field filter-search")], [
      label([], [text(i18n.t(config.locale, i18n_text.SearchLabel))]),
      input([
        attribute.type_("search"),
        attribute.placeholder(i18n.t(config.locale, i18n_text.SearchPlaceholder)),
        attribute.value(config.search_query),
        event.on_input(config.on_search_change),
      ]),
    ]),
  ])
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
    People -> config.people_content
    Milestones -> config.milestones_content
  }

  let testid = case config.view_mode {
    Pool -> "pool-canvas"
    Cards -> "kanban-board"
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
