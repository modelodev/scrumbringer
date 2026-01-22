//// Tests for date formatting utilities.

import gleeunit/should

import scrumbringer_client/utils/format_date.{
  full_date, relative_date_from_ms, short_date,
}

// =============================================================================
// Constants for testing
// =============================================================================

const ms_per_minute = 60_000

const ms_per_hour = 3_600_000

const ms_per_day = 86_400_000

// Base timestamp: 2026-01-22T12:00:00Z in milliseconds
// (approximately 1769083200000)
const base_now = 1_769_083_200_000

// =============================================================================
// relative_date_from_ms tests
// =============================================================================

pub fn relative_date_now_test() {
  let timestamp = base_now
  relative_date_from_ms(timestamp, base_now)
  |> should.equal("ahora")
}

pub fn relative_date_30_seconds_ago_test() {
  let timestamp = base_now - 30_000
  relative_date_from_ms(timestamp, base_now)
  |> should.equal("ahora")
}

pub fn relative_date_1_minute_ago_test() {
  let timestamp = base_now - ms_per_minute
  relative_date_from_ms(timestamp, base_now)
  |> should.equal("hace 1 min")
}

pub fn relative_date_5_minutes_ago_test() {
  let timestamp = base_now - { 5 * ms_per_minute }
  relative_date_from_ms(timestamp, base_now)
  |> should.equal("hace 5 min")
}

pub fn relative_date_59_minutes_ago_test() {
  let timestamp = base_now - { 59 * ms_per_minute }
  relative_date_from_ms(timestamp, base_now)
  |> should.equal("hace 59 min")
}

pub fn relative_date_1_hour_ago_test() {
  let timestamp = base_now - ms_per_hour
  relative_date_from_ms(timestamp, base_now)
  |> should.equal("hace 1h")
}

pub fn relative_date_3_hours_ago_test() {
  let timestamp = base_now - { 3 * ms_per_hour }
  relative_date_from_ms(timestamp, base_now)
  |> should.equal("hace 3h")
}

pub fn relative_date_23_hours_ago_test() {
  let timestamp = base_now - { 23 * ms_per_hour }
  relative_date_from_ms(timestamp, base_now)
  |> should.equal("hace 23h")
}

pub fn relative_date_yesterday_test() {
  let timestamp = base_now - { 30 * ms_per_hour }
  relative_date_from_ms(timestamp, base_now)
  |> should.equal("ayer")
}

pub fn relative_date_2_days_ago_test() {
  let timestamp = base_now - { 2 * ms_per_day }
  relative_date_from_ms(timestamp, base_now)
  |> should.equal("hace 2 días")
}

pub fn relative_date_5_days_ago_test() {
  let timestamp = base_now - { 5 * ms_per_day }
  relative_date_from_ms(timestamp, base_now)
  |> should.equal("hace 5 días")
}

pub fn relative_date_6_days_ago_test() {
  let timestamp = base_now - { 6 * ms_per_day }
  relative_date_from_ms(timestamp, base_now)
  |> should.equal("hace 6 días")
}

pub fn relative_date_future_test() {
  let timestamp = base_now + ms_per_hour
  relative_date_from_ms(timestamp, base_now)
  |> should.equal("en el futuro")
}

// =============================================================================
// short_date tests
// =============================================================================

pub fn short_date_january_test() {
  short_date("2026-01-21T00:00:00Z")
  |> should.equal("21 ene 2026")
}

pub fn short_date_december_test() {
  short_date("2025-12-25T10:30:00Z")
  |> should.equal("25 dic 2025")
}

pub fn short_date_single_digit_day_test() {
  short_date("2026-03-05T08:15:00Z")
  |> should.equal("5 mar 2026")
}

pub fn short_date_february_test() {
  short_date("2026-02-14T12:00:00Z")
  |> should.equal("14 feb 2026")
}

// =============================================================================
// full_date tests
// =============================================================================

pub fn full_date_with_time_test() {
  full_date("2026-01-21T21:01:00Z")
  |> should.equal("21 de enero de 2026, 21:01")
}

pub fn full_date_morning_test() {
  full_date("2026-03-15T08:30:00Z")
  |> should.equal("15 de marzo de 2026, 08:30")
}

pub fn full_date_midnight_test() {
  full_date("2026-12-31T00:00:00Z")
  |> should.equal("31 de diciembre de 2026, 00:00")
}

pub fn full_date_with_milliseconds_test() {
  full_date("2026-06-20T14:45:30.123Z")
  |> should.equal("20 de junio de 2026, 14:45")
}
