import gleeunit
import gleeunit/should

import domain/metrics.{
  AboveMax, Alert, Attention, BelowMin, HealthMetric, OkHealth, Sampled,
  window_days_from_int, window_days_value,
}

pub fn main() {
  gleeunit.main()
}

pub fn window_days_from_int_accepts_valid_range_test() {
  let assert Ok(window) = window_days_from_int(30)
  window_days_value(window) |> should.equal(30)
}

pub fn window_days_from_int_rejects_below_min_test() {
  window_days_from_int(0) |> should.equal(Error(BelowMin))
}

pub fn window_days_from_int_rejects_above_max_test() {
  window_days_from_int(91) |> should.equal(Error(AboveMax))
}

pub fn health_metric_round_trips_fields_test() {
  let HealthMetric(value: value, status: status, label: label) =
    HealthMetric(value: 42, status: OkHealth, label: "Flow")

  value |> should.equal(42)
  status |> should.equal(OkHealth)
  label |> should.equal("Flow")
}

pub fn health_metric_accepts_other_statuses_test() {
  let HealthMetric(status: status_attention, ..) =
    HealthMetric(value: 1, status: Attention, label: "Release")
  let HealthMetric(status: status_alert, ..) =
    HealthMetric(value: 1, status: Alert, label: "Time")

  status_attention |> should.equal(Attention)
  status_alert |> should.equal(Alert)
}

pub fn sampled_metric_constructs_test() {
  let Sampled(value_ms: value_ms, sample_size: sample_size) =
    Sampled(value_ms: 120_000, sample_size: 3)

  value_ms |> should.equal(120_000)
  sample_size |> should.equal(3)
}
