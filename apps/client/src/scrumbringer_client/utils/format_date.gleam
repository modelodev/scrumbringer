//// Date formatting utilities for Scrumbringer UI.
////
//// Provides functions for formatting dates in user-friendly formats:
//// - Relative dates ("hace 2 horas", "ayer", "hace 3 días")
//// - Short dates ("21 ene 2026")
//// - Full dates for tooltips ("21 de enero de 2026, 21:01")
////
//// ## Usage
////
//// ```gleam
//// let formatted = relative_date("2026-01-20T10:30:00Z")
//// // "hace 2 días"
//// ```

import gleam/int
import gleam/string

import scrumbringer_client/client_ffi

// =============================================================================
// Constants
// =============================================================================

const ms_per_minute = 60_000

const ms_per_hour = 3_600_000

const ms_per_day = 86_400_000

const ms_per_week = 604_800_000

// =============================================================================
// Public API
// =============================================================================

/// Format a timestamp as a relative date string.
///
/// For timestamps < 7 days old, returns relative format:
/// - "ahora" (< 1 minute)
/// - "hace X min" (1-59 minutes)
/// - "hace Xh" (1-23 hours)
/// - "ayer" (24-47 hours)
/// - "hace X días" (2-6 days)
///
/// For timestamps >= 7 days old, returns short date format.
///
/// ## Example
///
/// ```gleam
/// relative_date("2026-01-22T10:30:00Z")  // "hace 2 horas"
/// ```
pub fn relative_date(iso_timestamp: String) -> String {
  let now = client_ffi.now_ms()
  let timestamp = client_ffi.parse_iso_ms(iso_timestamp)

  case timestamp {
    0 -> iso_timestamp
    _ -> relative_date_from_ms(timestamp, now)
  }
}

/// Format a timestamp as a relative date, using provided "now" for testing.
pub fn relative_date_from_ms(timestamp_ms: Int, now_ms: Int) -> String {
  let diff = now_ms - timestamp_ms

  case diff {
    d if d < 0 -> "en el futuro"
    d if d < ms_per_minute -> "ahora"
    d if d < ms_per_hour -> {
      let minutes = d / ms_per_minute
      "hace " <> int.to_string(minutes) <> " min"
    }
    d if d < ms_per_day -> {
      let hours = d / ms_per_hour
      "hace " <> int.to_string(hours) <> "h"
    }
    d if d < { 2 * ms_per_day } -> "ayer"
    d if d < ms_per_week -> {
      let days = d / ms_per_day
      "hace " <> int.to_string(days) <> " días"
    }
    _ -> short_date_from_ms(timestamp_ms)
  }
}

/// Extract just the date portion from an ISO timestamp.
///
/// Format: "YYYY-MM-DD"
///
/// ## Example
///
/// ```gleam
/// date_only("2026-01-21T08:16:58Z")  // "2026-01-21"
/// ```
pub fn date_only(iso_timestamp: String) -> String {
  case string.split(iso_timestamp, "T") {
    [date_part, ..] -> date_part
    _ -> iso_timestamp
  }
}

/// Format a timestamp as a short date string.
///
/// Format: "21 ene 2026"
///
/// ## Example
///
/// ```gleam
/// short_date("2026-01-21T00:00:00Z")  // "21 ene 2026"
/// ```
pub fn short_date(iso_timestamp: String) -> String {
  // Extract date parts from ISO string (YYYY-MM-DDTHH:MM:SS)
  case string.split(iso_timestamp, "T") {
    [date_part, ..] -> format_date_part(date_part)
    _ -> iso_timestamp
  }
}

/// Format a timestamp as a full date string for tooltips.
///
/// Format: "21 de enero de 2026, 21:01"
///
/// ## Example
///
/// ```gleam
/// full_date("2026-01-21T21:01:00Z")  // "21 de enero de 2026, 21:01"
/// ```
pub fn full_date(iso_timestamp: String) -> String {
  case string.split(iso_timestamp, "T") {
    [date_part, time_part, ..] -> {
      let formatted_date = format_date_part_full(date_part)
      let formatted_time = format_time_part(time_part)
      formatted_date <> ", " <> formatted_time
    }
    [date_part] -> format_date_part_full(date_part)
    _ -> iso_timestamp
  }
}

// =============================================================================
// Internal Helpers
// =============================================================================

fn short_date_from_ms(timestamp_ms: Int) -> String {
  // Use JavaScript to format the date since we need locale-aware month names
  // For now, use a simple approximation based on the ISO string
  // In production, we'd add an FFI function for proper formatting
  let iso = ms_to_iso_date(timestamp_ms)
  format_date_part(iso)
}

fn ms_to_iso_date(ms: Int) -> String {
  // Simple approximation: return YYYY-MM-DD
  // This is a placeholder - in real implementation we'd use FFI
  let days_since_epoch = ms / ms_per_day
  let year = 1970 + days_since_epoch / 365
  let remaining_days = days_since_epoch - { { year - 1970 } * 365 }
  let month = { remaining_days / 30 } + 1
  let day = { remaining_days % 30 } + 1

  int.to_string(year) <> "-" <> pad_zero(month) <> "-" <> pad_zero(day)
}

fn pad_zero(n: Int) -> String {
  case n < 10 {
    True -> "0" <> int.to_string(n)
    False -> int.to_string(n)
  }
}

fn format_date_part(date_part: String) -> String {
  case string.split(date_part, "-") {
    [year, month, day] -> {
      let day_str = trim_leading_zero(day)
      let month_short = month_to_short_name(month)
      day_str <> " " <> month_short <> " " <> year
    }
    _ -> date_part
  }
}

fn format_date_part_full(date_part: String) -> String {
  case string.split(date_part, "-") {
    [year, month, day] -> {
      let day_str = trim_leading_zero(day)
      let month_full = month_to_full_name(month)
      day_str <> " de " <> month_full <> " de " <> year
    }
    _ -> date_part
  }
}

fn trim_leading_zero(s: String) -> String {
  case string.starts_with(s, "0") {
    True -> string.drop_start(s, 1)
    False -> s
  }
}

fn format_time_part(time_part: String) -> String {
  // Extract HH:MM from HH:MM:SS or HH:MM:SS.sssZ
  case string.split(time_part, ":") {
    [hour, minute, ..] -> hour <> ":" <> minute
    _ -> time_part
  }
}

fn month_to_short_name(month: String) -> String {
  case month {
    "01" -> "ene"
    "02" -> "feb"
    "03" -> "mar"
    "04" -> "abr"
    "05" -> "may"
    "06" -> "jun"
    "07" -> "jul"
    "08" -> "ago"
    "09" -> "sep"
    "10" -> "oct"
    "11" -> "nov"
    "12" -> "dic"
    _ -> month
  }
}

fn month_to_full_name(month: String) -> String {
  case month {
    "01" -> "enero"
    "02" -> "febrero"
    "03" -> "marzo"
    "04" -> "abril"
    "05" -> "mayo"
    "06" -> "junio"
    "07" -> "julio"
    "08" -> "agosto"
    "09" -> "septiembre"
    "10" -> "octubre"
    "11" -> "noviembre"
    "12" -> "diciembre"
    _ -> month
  }
}
