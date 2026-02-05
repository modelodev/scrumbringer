//// Helpers for time formatting.

import gleam/int
import gleam/string

/// Format seconds as HH:MM:SS or MM:SS string.
pub fn format_seconds(value: Int) -> String {
  let hours = value / 3600
  let minutes_total = value / 60
  let minutes = minutes_total - minutes_total / 60 * 60
  let seconds = value - minutes_total * 60

  let mm = minutes |> int.to_string |> string.pad_start(2, "0")
  let ss = seconds |> int.to_string |> string.pad_start(2, "0")

  case hours {
    0 -> mm <> ":" <> ss
    _ -> int.to_string(hours) <> ":" <> mm <> ":" <> ss
  }
}

/// Calculate elapsed time string from accumulated seconds and timestamps.
pub fn now_working_elapsed_from_ms(
  accumulated_s: Int,
  started_ms: Int,
  server_now_ms: Int,
) -> String {
  let diff_ms = server_now_ms - started_ms
  let delta_s = case diff_ms < 0 {
    True -> 0
    False -> diff_ms / 1000
  }

  format_seconds(accumulated_s + delta_s)
}
