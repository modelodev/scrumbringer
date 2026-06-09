import gleeunit

import domain/metrics.{
  AboveMax, Alert, Attention, BelowMin, HealthMetric, OkHealth, Sampled,
  window_days_from_int, window_days_value,
}

pub fn main() {
  gleeunit.main()
}

pub fn window_days_from_int_accepts_valid_range_test() {
  let assert Ok(window) = window_days_from_int(30)
  let assert 30 = window_days_value(window)
}

pub fn window_days_from_int_rejects_below_min_test() {
  let assert Error(BelowMin) = window_days_from_int(0)
}

pub fn window_days_from_int_rejects_above_max_test() {
  let assert Error(AboveMax) = window_days_from_int(91)
}

pub fn health_metric_round_trips_fields_test() {
  let HealthMetric(value: value, status: status, label: label) =
    HealthMetric(value: 42, status: OkHealth, label: "Flow")

  let assert 42 = value
  let assert OkHealth = status
  let assert "Flow" = label
}

pub fn health_metric_accepts_other_statuses_test() {
  let HealthMetric(status: status_attention, ..) =
    HealthMetric(value: 1, status: Attention, label: "Release")
  let HealthMetric(status: status_alert, ..) =
    HealthMetric(value: 1, status: Alert, label: "Time")

  let assert Attention = status_attention
  let assert Alert = status_alert
}

pub fn sampled_metric_constructs_test() {
  let Sampled(value_ms: value_ms, sample_size: sample_size) =
    Sampled(value_ms: 120_000, sample_size: 3)

  let assert 120_000 = value_ms
  let assert 3 = sample_size
}
