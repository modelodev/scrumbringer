//// Toast notification system with ADTs for type safety.
////
//// ## Mission
////
//// Provides a type-safe toast notification system with automatic dismissal,
//// using ADTs to prevent invalid states and ensure exhaustive handling.
////
//// ## Design Principles
////
//// - **Make Illegal States Unrepresentable**: Use ADTs for variants, not booleans
//// - **Opaque IDs**: Use ToastId to prevent mixing with other integers
//// - **Explicit Effects**: Auto-dismiss uses effects, not hidden timers
////
//// ## Responsibilities
////
//// - Define toast types (variant, state)
//// - Render toast notifications with dismiss functionality
//// - Provide update logic for showing/dismissing toasts
////
//// ## Non-responsibilities
////
//// - Global state management (integrate with main Model)
//// - Effect scheduling (caller provides effect primitives)
////
//// ## Relations
////
//// - **domain/ids.gleam**: Uses ToastId opaque type
//// - **client_view.gleam**: Renders toasts
//// - **client_update.gleam**: Integrates with main update

import gleam/list
import gleam/option.{type Option, None, Some}

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, span, text}
import lustre/event

import scrumbringer_client/domain/ids.{
  type ToastId, new_toast_id, toast_id_eq, toast_id_to_int,
}

// =============================================================================
// Types
// =============================================================================

/// Toast variant - determines visual styling.
///
/// Using an ADT ensures all variants are handled in pattern matching.
pub type ToastVariant {
  Success
  Error
  Info
  Warning
}

/// Typed toast actions for global interactive notifications.
pub type ToastActionKind {
  ViewTask(task_id: Int)
  ClearPoolFilters
}

/// Action metadata rendered in the toast UI.
pub type ToastAction {
  ToastAction(label: String, kind: ToastActionKind)
}

/// A toast notification with type-safe ID.
pub type Toast {
  Toast(
    id: ToastId,
    message: String,
    variant: ToastVariant,
    action: Option(ToastAction),
    created_at: Int,
  )
}

/// State for managing multiple toasts.
pub type ToastState {
  ToastState(toasts: List(Toast), next_id: Int)
}

/// Messages for the toast system.
pub type ToastMsg {
  Show(message: String, variant: ToastVariant)
  Dismiss(id: ToastId)
  Tick(now: Int)
}

// =============================================================================
// State Management
// =============================================================================

/// Create initial empty toast state.
pub fn init() -> ToastState {
  ToastState(toasts: [], next_id: 0)
}

/// Duration in milliseconds before auto-dismiss (3 seconds).
pub const auto_dismiss_ms = 3000

/// Check if there are any toasts to display.
pub fn has_toasts(state: ToastState) -> Bool {
  !list.is_empty(state.toasts)
}

// =============================================================================
// Generic State Update Helpers (Story 4.8)
// =============================================================================

/// Show a new toast, returning the updated state.
///
/// Call this from your main update handler, then schedule your own tick effect.
pub fn show(
  state: ToastState,
  message: String,
  variant: ToastVariant,
  now: Int,
) -> ToastState {
  show_with_action(state, message, variant, None, now)
}

/// Show a new toast with optional action.
pub fn show_with_action(
  state: ToastState,
  message: String,
  variant: ToastVariant,
  action: Option(ToastAction),
  now: Int,
) -> ToastState {
  let id = new_toast_id(state.next_id)
  let toast = Toast(id:, message:, variant:, action:, created_at: now)
  ToastState(toasts: [toast, ..state.toasts], next_id: state.next_id + 1)
}

/// Dismiss a toast by ID, returning the updated state.
pub fn dismiss(state: ToastState, id: ToastId) -> ToastState {
  let new_toasts = list.filter(state.toasts, fn(t) { !toast_id_eq(t.id, id) })
  ToastState(..state, toasts: new_toasts)
}

/// Process a tick, removing expired toasts.
///
/// Returns the updated state and whether to schedule another tick.
pub fn tick(state: ToastState, now: Int) -> #(ToastState, Bool) {
  let cutoff = now - auto_dismiss_ms
  let new_toasts = list.filter(state.toasts, fn(t) { t.created_at > cutoff })
  let should_schedule = !list.is_empty(new_toasts)
  #(ToastState(..state, toasts: new_toasts), should_schedule)
}

/// Get the current list of toasts.
pub fn get_toasts(state: ToastState) -> List(Toast) {
  state.toasts
}

// =============================================================================
// View Functions
// =============================================================================

/// Render all toasts in the container.
///
/// ## Parameters
///
/// - `state`: Current toast state
/// - `on_dismiss`: Function to create dismiss message for a toast ID
///
/// ## Example
///
/// ```gleam
/// toast.view_container(model.toasts, fn(id) { ToastDismissed(id) })
/// ```
pub fn view_container(
  state: ToastState,
  on_dismiss: fn(ToastId) -> msg,
  on_action: fn(ToastActionKind) -> msg,
) -> Element(msg) {
  case list.is_empty(state.toasts) {
    True -> element.none()
    False ->
      div(
        [attribute.class("toast-container")],
        list.map(state.toasts, fn(t) {
          view_toast(t, on_dismiss(t.id), on_action)
        }),
      )
  }
}

/// Render a single toast notification.
fn view_toast(
  toast: Toast,
  on_dismiss: msg,
  on_action: fn(ToastActionKind) -> msg,
) -> Element(msg) {
  let variant_class = variant_to_class(toast.variant)

  let action_button = case toast.action {
    Some(ToastAction(label:, kind: kind)) ->
      button(
        [
          attribute.class("toast-action btn-xs"),
          attribute.attribute("aria-label", label),
          event.on_click(on_action(kind)),
        ],
        [text(label)],
      )
    None -> element.none()
  }

  div(
    [
      attribute.class("toast " <> variant_class),
      attribute.attribute("role", "status"),
      attribute.attribute("aria-live", "polite"),
      attribute.attribute(
        "data-toast-id",
        toast_id_to_int(toast.id) |> int_to_string,
      ),
    ],
    [
      span([attribute.class("toast-icon")], [text(variant_icon(toast.variant))]),
      span([attribute.class("toast-message")], [text(toast.message)]),
      action_button,
      button(
        [
          attribute.class("toast-dismiss btn-xs"),
          attribute.attribute("aria-label", "Cerrar"),
          event.on_click(on_dismiss),
        ],
        [text("×")],
      ),
    ],
  )
}

/// Convert variant to CSS class.
fn variant_to_class(variant: ToastVariant) -> String {
  case variant {
    Success -> "toast-success"
    Error -> "toast-error"
    Info -> "toast-info"
    Warning -> "toast-warning"
  }
}

/// Get icon for variant.
fn variant_icon(variant: ToastVariant) -> String {
  case variant {
    Success -> "✓"
    Error -> "✕"
    Info -> "ℹ"
    Warning -> "⚠"
  }
}

// Helper for int to string (avoiding gleam/int import for simplicity)
fn int_to_string(n: Int) -> String {
  case n {
    0 -> "0"
    _ -> do_int_to_string(n, "")
  }
}

fn do_int_to_string(n: Int, acc: String) -> String {
  case n {
    0 -> acc
    _ -> {
      let digit = n % 10
      let char = case digit {
        0 -> "0"
        1 -> "1"
        2 -> "2"
        3 -> "3"
        4 -> "4"
        5 -> "5"
        6 -> "6"
        7 -> "7"
        8 -> "8"
        _ -> "9"
      }
      do_int_to_string(n / 10, char <> acc)
    }
  }
}
