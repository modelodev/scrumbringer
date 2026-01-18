//// Time utilities for the ScrumBringer server.
////
//// Provides functions to get the current time in various formats,
//// using Erlang's system_time for Unix timestamps and birl for ISO8601.

import birl
import gleam/erlang/atom

/// Returns the current Unix timestamp in seconds.
///
/// ## Example
/// ```gleam
/// let timestamp = time.now_unix_seconds()
/// // => 1705507200
/// ```
pub fn now_unix_seconds() -> Int {
  system_time(atom.create("second"))
}

@external(erlang, "erlang", "system_time")
fn system_time(unit: atom.Atom) -> Int

/// Returns the current UTC time as an ISO8601 formatted string.
///
/// ## Example
/// ```gleam
/// let iso = time.now_iso8601()
/// // => "2024-01-17T15:30:00.000Z"
/// ```
pub fn now_iso8601() -> String {
  birl.utc_now()
  |> birl.to_iso8601
}
