//// Center Panel - Main content area with view content
////
//// Mission: Render the center panel content based on current view mode,
//// delegating view-owned chrome to each feature.
////
//// Responsibilities:
//// - Content routing based on view mode
////
//// Non-responsibilities:
//// - View mode navigation (handled by sidebar - Story 4.8 UX)
//// - Individual view implementations (delegated to view modules)
//// - View-owned filter and control bars
//// - State management (handled by parent)

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div}
import lustre/event

import domain/view_mode.{type ViewMode, Capabilities, Cards, People, Pool}
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/ui/event_decoders

// =============================================================================
// Types
// =============================================================================

/// Configuration for the center panel
pub type CenterPanelConfig(msg) {
  CenterPanelConfig(
    locale: Locale,
    view_mode: ViewMode,
    // Content
    pool_content: Element(msg),
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
    // Content based on view mode
    view_content(config),
  ])
}

fn view_content(config: CenterPanelConfig(msg)) -> Element(msg) {
  let content = case config.view_mode {
    Pool -> config.pool_content
    Cards -> config.cards_content
    Capabilities -> config.capabilities_content
    People -> config.people_content
  }

  let testid = case config.view_mode {
    Pool -> "pool-canvas"
    Cards -> "plan-view"
    Capabilities -> "capabilities-view"
    People -> "people-view"
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
