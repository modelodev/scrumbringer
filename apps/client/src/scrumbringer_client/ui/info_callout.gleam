//// Info callout component for contextual help.
////
//// Displays informational messages with icon and optional title.
//// Used for onboarding hints, feature explanations, and contextual tips.

import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, text}

import scrumbringer_client/ui/icon_catalog

/// Simple info callout without title.
pub fn simple(content: String) -> Element(msg) {
  view_with_content(opt.None, text(content))
}

/// Info callout with custom content element.
pub fn view_with_content(
  title: opt.Option(String),
  content: Element(msg),
) -> Element(msg) {
  div([attribute.class("info-callout")], [
    div([attribute.class("info-callout-icon")], [
      icon_catalog.render("light-bulb", 24),
    ]),
    div([attribute.class("info-callout-content")], [
      case title {
        opt.Some(t) -> div([attribute.class("info-callout-title")], [text(t)])
        opt.None -> element.none()
      },
      div([attribute.class("info-callout-text")], [content]),
    ]),
  ])
}
