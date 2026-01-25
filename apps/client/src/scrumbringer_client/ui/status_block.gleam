//// Shared status blocks for empty and error messages.

import lustre/element.{type Element}
import lustre/element/html.{div, text}
import scrumbringer_client/ui/attrs

/// Render a standard empty state message.
pub fn empty_text(message: String) -> Element(msg) {
  div([attrs.empty()], [text(message)])
}

/// Render a standard error message.
pub fn error_text(message: String) -> Element(msg) {
  div([attrs.error()], [text(message)])
}
