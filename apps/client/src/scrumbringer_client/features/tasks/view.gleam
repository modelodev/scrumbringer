//// Task View Module for Scrumbringer client.
////
//// ## Mission
////
//// Provides shared task view utilities and documents the distributed task view
//// architecture across feature modules.
////
//// ## Architecture Note
////
//// Task views are intentionally distributed across feature modules rather than
//// centralized here, following feature-based organization:
////
//// - **features/pool/view.gleam**: Pool canvas with task cards and drag-drop
//// - **features/pool/dialogs.gleam**: Task create dialog, task details modal
//// - **features/my_bar/view.gleam**: Claimed tasks list (my_bar section)
//// - **features/now_working/view.gleam**: Active task panel
////
//// This design keeps task views co-located with their feature context and
//// state management, following Lustre best practices.
////
//// ## Responsibilities
////
//// - Shared task status label helpers
//// - Task decay styling utilities (re-exported from member_visuals)
//// - Documentation of task view locations
////
//// ## Non-responsibilities
////
//// - Pool canvas rendering (see features/pool/view.gleam)
//// - Task dialogs (see features/pool/dialogs.gleam)
//// - Claimed tasks (see features/my_bar/view.gleam)
//// - Task update handlers (see features/tasks/update.gleam)
////
//// ## Relations
////
//// - **features/pool/view.gleam**: Task cards in pool canvas
//// - **features/pool/dialogs.gleam**: Task creation and details dialogs
//// - **features/my_bar/view.gleam**: Claimed tasks display
//// - **features/tasks/update.gleam**: Task mutation handlers

import gleam/float
import gleam/int

import domain/task_status.{type TaskStatus}

import scrumbringer_client/client_ffi
import scrumbringer_client/member_visuals

// =============================================================================
// Task Status Helpers
// =============================================================================

/// Get a CSS class suffix for a task status.
///
/// Used for styling task cards based on their current status.
///
/// ## Example
///
/// ```gleam
/// status_class(Available) // "available"
/// status_class(Claimed) // "claimed"
/// ```
pub fn status_class(status: TaskStatus) -> String {
  task_status.task_status_to_string(status)
}

// =============================================================================
// Task Decay Helpers
// =============================================================================

/// Calculate the number of days since a task was created.
///
/// Uses the ISO date string from the task's created_at field.
pub fn age_in_days(created_at: String) -> Int {
  client_ffi.days_since_iso(created_at)
}

/// Calculate visual decay parameters for a task based on its age.
///
/// Returns a tuple of (opacity_factor, saturation_factor) for CSS styling.
/// Older tasks appear more faded to indicate staleness.
///
/// ## Example
///
/// ```gleam
/// decay_to_visuals(0)  // #(1.0, 1.0) - new task, full opacity
/// decay_to_visuals(20) // #(0.85, 0.65) - aging task, somewhat faded
/// decay_to_visuals(30) // #(0.8, 0.55) - old task, noticeably faded
/// ```
pub fn decay_to_visuals(age_days: Int) -> #(Float, Float) {
  case age_days {
    d if d < 9 -> #(1.0, 1.0)
    d if d < 18 -> #(0.95, 0.85)
    d if d < 27 -> #(0.85, 0.65)
    _ -> #(0.8, 0.55)
  }
}

/// Calculate priority-based visual size in pixels for task cards.
///
/// Higher priority tasks appear larger in the pool canvas.
/// Re-exported from member_visuals for convenience.
pub fn priority_to_px(priority: Int) -> Int {
  member_visuals.priority_to_px(priority)
}

/// Generate CSS style string for task decay visualization.
///
/// Returns an inline style with opacity and saturation adjustments.
pub fn decay_style(created_at: String) -> String {
  let days = age_in_days(created_at)
  let #(opacity, saturation) = decay_to_visuals(days)
  "opacity:" <> float_to_string(opacity) <> ";filter:saturate(" <> float_to_string(saturation) <> ");"
}

// =============================================================================
// Helpers
// =============================================================================

fn float_to_string(f: Float) -> String {
  // Round to 2 decimal places for CSS values
  let scaled = f *. 100.0
  let i = float.truncate(scaled)
  let whole = i / 100
  let frac = case i % 100 {
    n if n < 0 -> 0 - n
    n -> n
  }
  let frac_str = case frac < 10 {
    True -> "0" <> int.to_string(frac)
    False -> int.to_string(frac)
  }
  int.to_string(whole) <> "." <> frac_str
}
