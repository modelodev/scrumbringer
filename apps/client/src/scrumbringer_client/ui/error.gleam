//// Shared error state UI components.
////
//// ## Mission
////
//// Provides reusable error display components for Remote data failures.
////
//// ## Responsibilities
////
//// - Error message views
//// - Panel wrapper with error state
////
//// ## Non-responsibilities
////
//// - State management (see client_state.gleam)
//// - Error types (see domain/api_error.gleam)

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, text}

import domain/api_error.{type ApiError}

/// Render an error message from a string.
///
/// ## Example
///
/// ```gleam
/// error_text("Something went wrong")
/// // <div class="error">Something went wrong</div>
/// ```
pub fn error_text(message: String) -> Element(msg) {
  div(
    [
      attribute.class("error"),
      attribute.attribute("role", "alert"),
      attribute.attribute("aria-live", "assertive"),
    ],
    [text(message)],
  )
}

/// Render an error message from an ApiError.
///
/// ## Example
///
/// ```gleam
/// error(ApiError(status: 500, message: "Server error"))
/// // <div class="error">Server error</div>
/// ```
pub fn error(err: ApiError) -> Element(msg) {
  error_text(err.message)
}

/// Render an error inside a panel with title.
///
/// ## Example
///
/// ```gleam
/// error_panel("Metrics", ApiError(status: 500, message: "Failed"))
/// // <div class="panel"><h2>Metrics</h2><div class="error">Failed</div></div>
/// ```
pub fn error_panel(title: String, err: ApiError) -> Element(msg) {
  div([attribute.class("panel")], [
    html.h2([], [text(title)]),
    error(err),
  ])
}
