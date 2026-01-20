//// Empty state component for consistent "no data" displays.
////
//// Provides a reusable component for empty states across the application
//// with optional icon, title, description, and action button.

import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, h2, p, text}
import lustre/event

import scrumbringer_client/ui/css_class as css
import scrumbringer_client/ui/icons

/// Configuration for an empty state display.
pub type EmptyStateConfig(msg) {
  EmptyStateConfig(
    icon: icons.EmojiIcon,
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
  icon: icons.EmojiIcon,
  title: String,
  description: String,
) -> EmptyStateConfig(msg) {
  EmptyStateConfig(icon:, title:, description:, action: opt.None)
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
  let EmptyStateConfig(icon:, title:, description:, action:) = state

  div([attribute.class(css.to_string(css.empty_state()))], [
    div([attribute.class(css.to_string(css.empty_state_icon()))], [
      text(icons.emoji_to_string(icon)),
    ]),
    h2([], [text(title)]),
    p([attribute.class(css.to_string(css.empty_state_text()))], [
      text(description),
    ]),
    case action {
      opt.Some(EmptyStateAction(label:, on_click:)) ->
        button(
          [attribute.type_("submit"), event.on_click(on_click)],
          [text(label)],
        )
      opt.None -> element.none()
    },
  ])
}

/// Simple empty state without title (just icon and text).
pub fn simple(icon: icons.EmojiIcon, description: String) -> Element(msg) {
  div([attribute.class(css.to_string(css.empty_state()))], [
    div([attribute.class(css.to_string(css.empty_state_icon()))], [
      text(icons.emoji_to_string(icon)),
    ]),
    p([attribute.class(css.to_string(css.empty_state_text()))], [
      text(description),
    ]),
  ])
}
