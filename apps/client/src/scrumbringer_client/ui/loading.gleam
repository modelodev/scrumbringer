//// Shared loading state UI components.
////
//// ## Mission
////
//// Provides reusable loading indicator components for Remote data states.
////
//// ## Responsibilities
////
//// - Loading spinner/indicator views
//// - Panel wrapper with loading state
////
//// ## Non-responsibilities
////
//// - State management (see client_state.gleam)
//// - i18n text definitions (see i18n/text.gleam)

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, text}

pub type SpinnerSize {
  Small
  Medium
  Large
}

pub fn spinner(size: SpinnerSize) -> Element(msg) {
  let size_class = case size {
    Small -> "spinner-sm"
    Medium -> "spinner-md"
    Large -> "spinner-lg"
  }

  div([attribute.class("spinner " <> size_class)], [])
}

/// Render a simple loading indicator with custom message.
///
/// ## Example
///
/// ```gleam
/// loading("Loading tasks...")
/// // <div class="loading">Loading tasks...</div>
/// ```
pub fn loading(message: String) -> Element(msg) {
  div([attribute.class("loading")], [text(message)])
}

/// Render a loading indicator inside a panel with title.
///
/// ## Example
///
/// ```gleam
/// loading_panel("Metrics", "Loading metrics...")
/// // <div class="panel"><h2>Metrics</h2><div class="loading">...</div></div>
/// ```
pub fn loading_panel(title: String, message: String) -> Element(msg) {
  div([attribute.class("panel")], [
    html.h2([], [text(title)]),
    loading(message),
  ])
}
