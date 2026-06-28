//// Empty state component for consistent "no data" displays.
////
//// Provides a reusable component for empty states across the application
//// with optional icon, title, description, and action button.
//// Uses SVG icons from the icon catalog for theme-aware rendering.

import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, h2, p, text}

import scrumbringer_client/ui/button
import scrumbringer_client/ui/css_class as css
import scrumbringer_client/ui/icon_catalog

/// Product meaning represented by an empty or transient state.
pub type Meaning {
  HealthyEmpty
  NoResults
  NeedsSetup
  Onboarding
  Loading
  Error
}

/// Configuration for an empty state display.
pub type EmptyStateConfig(msg) {
  EmptyStateConfig(
    icon_id: String,
    title: String,
    description: String,
    action: opt.Option(EmptyStateAction(msg)),
    secondary_action: opt.Option(EmptyStateAction(msg)),
    meaning: Meaning,
    extra_class: opt.Option(String),
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
  EmptyStateConfig(
    icon_id:,
    title:,
    description:,
    action: opt.None,
    secondary_action: opt.None,
    meaning: HealthyEmpty,
    extra_class: opt.None,
  )
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

/// Adds a secondary action button to the empty state.
pub fn with_secondary_action(
  state: EmptyStateConfig(msg),
  label: String,
  on_click: msg,
) -> EmptyStateConfig(msg) {
  EmptyStateConfig(
    ..state,
    secondary_action: opt.Some(EmptyStateAction(label:, on_click:)),
  )
}

/// Sets the product meaning for styling and assistive technology.
pub fn with_meaning(
  state: EmptyStateConfig(msg),
  meaning: Meaning,
) -> EmptyStateConfig(msg) {
  EmptyStateConfig(..state, meaning:)
}

/// Adds a feature-specific class while keeping the shared empty-state classes.
pub fn with_class(
  state: EmptyStateConfig(msg),
  extra_class: String,
) -> EmptyStateConfig(msg) {
  EmptyStateConfig(..state, extra_class: opt.Some(extra_class))
}

/// Renders the empty state component.
pub fn view(state: EmptyStateConfig(msg)) -> Element(msg) {
  let EmptyStateConfig(
    icon_id:,
    title:,
    description:,
    action:,
    secondary_action:,
    meaning:,
    extra_class:,
  ) = state

  div(root_attrs(meaning, extra_class), [
    div([attribute.class(css.to_string(css.empty_state_icon()))], [
      icon_catalog.render(icon_id, 40),
    ]),
    h2([attribute.class("empty-state-title")], [text(title)]),
    p([attribute.class("empty-state-description")], [
      text(description),
    ]),
    view_actions(action, secondary_action),
  ])
}

fn view_actions(
  action: opt.Option(EmptyStateAction(msg)),
  secondary_action: opt.Option(EmptyStateAction(msg)),
) -> Element(msg) {
  case action, secondary_action {
    opt.None, opt.None -> element.none()
    _, _ ->
      div([attribute.class("empty-state-actions")], [
        case action {
          opt.Some(EmptyStateAction(label:, on_click:)) ->
            button.text(label, on_click, button.Primary, button.EntityAction)
            |> button.view
          opt.None -> element.none()
        },
        case secondary_action {
          opt.Some(EmptyStateAction(label:, on_click:)) ->
            button.text(label, on_click, button.Secondary, button.EntityAction)
            |> button.view
          opt.None -> element.none()
        },
      ])
  }
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

/// Compact one-line state for loading/error/no-results messages.
pub fn notice(
  icon_id: String,
  description: String,
  meaning: Meaning,
) -> Element(msg) {
  div(root_attrs(meaning, opt.None), [
    div([attribute.class(css.to_string(css.empty_state_icon()))], [
      icon_catalog.render(icon_id, 40),
    ]),
    p([attribute.class(css.to_string(css.empty_state_text()))], [
      text(description),
    ]),
  ])
}

/// Compact one-line state with a feature-specific extra class.
pub fn notice_with_class(
  icon_id: String,
  description: String,
  meaning: Meaning,
  extra_class: String,
) -> Element(msg) {
  div(root_attrs(meaning, opt.Some(extra_class)), [
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
  |> with_meaning(HealthyEmpty)
}

/// Empty state for no projects.
pub fn no_projects(title: String, description: String) -> EmptyStateConfig(msg) {
  new("folder", title, description)
  |> with_meaning(NeedsSetup)
}

/// Empty state for no team members.
pub fn no_members(title: String, description: String) -> EmptyStateConfig(msg) {
  new("user-group", title, description)
  |> with_meaning(NeedsSetup)
}

fn root_attrs(meaning: Meaning, extra_class: opt.Option(String)) {
  [attribute.class(root_class(meaning, extra_class)), ..meaning_attrs(meaning)]
}

fn root_class(meaning: Meaning, extra_class: opt.Option(String)) -> String {
  case extra_class {
    opt.Some(class_name) ->
      css.to_string(css.empty_state())
      <> " "
      <> class_name
      <> " "
      <> meaning_class(meaning)
    opt.None ->
      css.to_string(css.empty_state()) <> " " <> meaning_class(meaning)
  }
}

fn meaning_class(meaning: Meaning) -> String {
  case meaning {
    HealthyEmpty -> "empty-state-healthy"
    NoResults -> "empty-state-no-results"
    NeedsSetup -> "empty-state-needs-setup"
    Onboarding -> "empty-state-onboarding"
    Loading -> "empty-state-loading"
    Error -> "empty-state-error"
  }
}

fn meaning_attrs(meaning: Meaning) {
  case meaning {
    Loading -> [
      attribute.attribute("role", "status"),
      attribute.attribute("aria-live", "polite"),
    ]
    Error -> [attribute.attribute("role", "alert")]
    _ -> []
  }
}
