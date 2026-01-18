//// Visual utilities for member view rendering.
////
//// Provides helper functions for task card sizing and decay
//// calculations based on priority and age.

import gleam/int

/// Converts a task priority (1-5) to pixel dimensions for card rendering.
///
/// Higher priority tasks get larger cards.
///
/// ## Example
///
/// ```gleam
/// priority_to_px(3)
/// // -> 96
/// ```
pub fn priority_to_px(priority: Int) -> Int {
  case priority {
    1 -> 64
    2 -> 80
    3 -> 96
    4 -> 112
    5 -> 128
    _ -> 96
  }
}

/// Calculates a decay factor (0.0 to 1.0) based on task age.
///
/// Used to fade out older tasks in the UI. Clamps age to 0-30 days.
///
/// ## Example
///
/// ```gleam
/// decay_factor_from_age_days(15)
/// // -> 0.5
/// ```
pub fn decay_factor_from_age_days(age_days: Int) -> Float {
  let clamped = int.min(int.max(age_days, 0), 30)
  clamped |> int.to_float |> fn(v) { v /. 30.0 }
}
