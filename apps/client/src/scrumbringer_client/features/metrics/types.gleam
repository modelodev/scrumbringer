////
//// Helpers for metrics view formatting and health status.
////

import domain/metrics.{
  type Health, type SampledMetric, Alert, Attention, NoSample, OkHealth, Sampled,
}
import gleam/int
import gleam/option.{type Option, None, Some}

pub fn health_for_flow(value: Option(Int)) -> Health {
  case value {
    Some(v) if v > 70 -> OkHealth
    Some(v) if v >= 40 -> Attention
    Some(_) -> Alert
    None -> Attention
  }
}

pub fn health_for_release(value: Option(Int)) -> Health {
  case value {
    Some(v) if v < 20 -> OkHealth
    Some(v) if v <= 40 -> Attention
    Some(_) -> Alert
    None -> Attention
  }
}

pub fn health_for_time(sampled: SampledMetric) -> Health {
  case sampled {
    NoSample -> Attention
    Sampled(value_ms: value_ms, ..) ->
      case value_ms {
        v if v < 4 * 60 * 60 * 1000 -> OkHealth
        v if v < 24 * 60 * 60 * 1000 -> Attention
        _ -> Alert
      }
  }
}

pub fn sampled_time_label(
  sampled: SampledMetric,
  no_sample_label: String,
) -> String {
  case sampled {
    NoSample -> no_sample_label <> " (n=0)"
    Sampled(value_ms: value_ms, sample_size: sample_size) ->
      format_ms_human(value_ms) <> " (n=" <> int.to_string(sample_size) <> ")"
  }
}

pub fn format_ms_human(value_ms: Int) -> String {
  let total_seconds = value_ms / 1000
  let total_minutes = total_seconds / 60
  let hours = total_minutes / 60
  let minutes = total_minutes % 60
  let days = hours / 24
  let hours_left = hours % 24

  case days > 0 {
    True -> int.to_string(days) <> "d " <> int.to_string(hours_left) <> "h"
    False ->
      case hours > 0 {
        True -> int.to_string(hours) <> "h " <> int.to_string(minutes) <> "m"
        False -> int.to_string(minutes) <> "m"
      }
  }
}
