//// Info callout component for contextual help.
////
//// Displays informational messages with icon and optional title.
//// Used for onboarding hints, feature explanations, and contextual tips.

import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, text}

import scrumbringer_client/ui/css_class as css
import scrumbringer_client/ui/icons

/// Info callout configuration.
pub type InfoCalloutConfig {
  InfoCalloutConfig(title: opt.Option(String), content: String)
}

/// Creates an info callout with content only.
pub fn new(content: String) -> InfoCalloutConfig {
  InfoCalloutConfig(title: opt.None, content:)
}

/// Creates an info callout with title and content.
pub fn with_title(title: String, content: String) -> InfoCalloutConfig {
  InfoCalloutConfig(title: opt.Some(title), content:)
}

/// Renders the info callout.
pub fn view(callout: InfoCalloutConfig) -> Element(msg) {
  let InfoCalloutConfig(title:, content:) = callout

  div([attribute.class(css.to_string(css.info_callout()))], [
    div([attribute.class(css.to_string(css.info_callout_icon()))], [
      text(icons.emoji_to_string(icons.Lightbulb)),
    ]),
    div([attribute.class(css.to_string(css.info_callout_content()))], [
      case title {
        opt.Some(t) ->
          div([attribute.class(css.to_string(css.info_callout_title()))], [
            text(t),
          ])
        opt.None -> element.none()
      },
      div([attribute.class(css.to_string(css.info_callout_text()))], [
        text(content),
      ]),
    ]),
  ])
}

/// Simple info callout without title.
pub fn simple(content: String) -> Element(msg) {
  new(content) |> view
}

/// Info callout with title.
pub fn titled(title: String, content: String) -> Element(msg) {
  with_title(title, content) |> view
}
