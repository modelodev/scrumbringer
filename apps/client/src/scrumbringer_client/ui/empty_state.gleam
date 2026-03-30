//// Empty state component for consistent "no data" displays.
////
//// Provides a reusable component for empty states across the application
//// with optional icon, title, description, and action button.
//// Uses SVG icons from the icon catalog for theme-aware rendering.

import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, h2, p, text}
import lustre/event

import scrumbringer_client/ui/css_class as css
import scrumbringer_client/ui/icon_catalog

/// Configuration for an empty state display.
pub type EmptyStateConfig(msg) {
  EmptyStateConfig(
    icon_id: String,
    title: String,
    description: String,
    action: opt.Option(EmptyStateAction(msg)),
  )
}

/// Action button configuration.
pub type EmptyStateAction(msg) {
  EmptyStateAction(label: String, on_click: msg)
}

/// Creates an empty state with required fields.
pub fn new(
  icon_id: String,
  title: String,
  description: String,
) -> EmptyStateConfig(msg) {
  EmptyStateConfig(icon_id:, title:, description:, action: opt.None)
}

/// Adds an action button to the empty state.
pub fn with_action(
  state: EmptyStateConfig(msg),
  label: String,
  on_click: msg,
) -> EmptyStateConfig(msg) {
  EmptyStateConfig(
    ..state,
    action: opt.Some(EmptyStateAction(label:, on_click:)),
  )
}

/// Renders the empty state component.
pub fn view(state: EmptyStateConfig(msg)) -> Element(msg) {
  let EmptyStateConfig(icon_id:, title:, description:, action:) = state

  div([attribute.class(css.to_string(css.empty_state()))], [
    div([attribute.class(css.to_string(css.empty_state_icon()))], [
      icon_catalog.render(icon_id, 40),
    ]),
    h2([attribute.class("empty-state-title")], [text(title)]),
    p([attribute.class("empty-state-description")], [
      text(description),
    ]),
    case action {
      opt.Some(EmptyStateAction(label:, on_click:)) ->
        button([attribute.type_("submit"), event.on_click(on_click)], [
          text(label),
        ])
      opt.None -> element.none()
    },
  ])
}

/// Simple empty state without title (just icon and text).
pub fn simple(icon_id: String, description: String) -> Element(msg) {
  div([attribute.class(css.to_string(css.empty_state()))], [
    div([attribute.class(css.to_string(css.empty_state_icon()))], [
      icon_catalog.render(icon_id, 40),
    ]),
    p([attribute.class(css.to_string(css.empty_state_text()))], [
      text(description),
    ]),
  ])
}

// =============================================================================
// Factory Functions for Common Empty States
// =============================================================================

/// Empty state for no active tasks (member view).
pub fn no_tasks(title: String, description: String) -> EmptyStateConfig(msg) {
  new("hand-raised", title, description)
}

/// Empty state for no cards/fichas.
pub fn no_cards(title: String, description: String) -> EmptyStateConfig(msg) {
  new("clipboard-document-list", title, description)
}

/// Empty state for no projects.
pub fn no_projects(title: String, description: String) -> EmptyStateConfig(msg) {
  new("folder", title, description)
}

/// Empty state for no team members.
pub fn no_members(title: String, description: String) -> EmptyStateConfig(msg) {
  new("user-group", title, description)
}

/// Empty state for no search results.
pub fn no_results(title: String, description: String) -> EmptyStateConfig(msg) {
  new("magnifying-glass", title, description)
}

/// Empty state for all tasks completed (celebration).
pub fn all_done(title: String, description: String) -> EmptyStateConfig(msg) {
  new("sparkles", title, description)
}

/// Empty state for inbox/notifications.
pub fn empty_inbox(title: String, description: String) -> EmptyStateConfig(msg) {
  new("inbox", title, description)
}
