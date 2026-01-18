//// Toast notification UI component.
////
//// ## Mission
////
//// Provides a reusable toast notification component for displaying
//// temporary messages to users with dismiss functionality.
////
//// ## Responsibilities
////
//// - Render toast notifications with optional dismiss button
//// - Support customizable dismiss action
//// - Provide accessible UI with aria-labels
////
//// ## Non-responsibilities
////
//// - Toast state management (see client_state.gleam)
//// - Toast timing/auto-dismiss (handled by update logic)
////
//// ## Relations
////
//// - **client_view.gleam**: Uses this component for toast rendering
//// - **client_state.gleam**: Provides toast state and messages

import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, span, text}
import lustre/event

/// Renders a toast notification with message and dismiss button.
///
/// ## Parameters
///
/// - `toast`: Optional toast message to display
/// - `dismiss_label`: Accessible label for dismiss button
/// - `on_dismiss`: Message to emit when dismiss is clicked
///
/// ## Example
///
/// ```gleam
/// toast.view(
///   model.toast,
///   update_helpers.i18n_t(model, i18n_text.Dismiss),
///   ToastDismissed,
/// )
/// ```
pub fn view(
  toast: opt.Option(String),
  dismiss_label: String,
  on_dismiss: msg,
) -> Element(msg) {
  case toast {
    opt.None -> div([], [])
    opt.Some(message) ->
      div([attribute.class("toast")], [
        span([], [text(message)]),
        button(
          [
            attribute.class("toast-dismiss btn-xs"),
            attribute.attribute("aria-label", dismiss_label),
            event.on_click(on_dismiss),
          ],
          [text("×")],
        ),
      ])
  }
}
