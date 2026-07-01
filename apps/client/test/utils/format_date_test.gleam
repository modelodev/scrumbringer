//// Tests for date formatting utilities.

import scrumbringer_client/i18n/locale
import scrumbringer_client/utils/format_date.{
  full_date, full_date_for_locale, relative_date_from_ms, short_date,
  short_date_for_locale,
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
  let assert "ahora" = relative_date_from_ms(timestamp, base_now)
}

pub fn relative_date_30_seconds_ago_test() {
  let timestamp = base_now - 30_000
  let assert "ahora" = relative_date_from_ms(timestamp, base_now)
}

pub fn relative_date_1_minute_ago_test() {
  let timestamp = base_now - ms_per_minute
  let assert "hace 1 min" = relative_date_from_ms(timestamp, base_now)
}

pub fn relative_date_5_minutes_ago_test() {
  let timestamp = base_now - { 5 * ms_per_minute }
  let assert "hace 5 min" = relative_date_from_ms(timestamp, base_now)
}

pub fn relative_date_59_minutes_ago_test() {
  let timestamp = base_now - { 59 * ms_per_minute }
  let assert "hace 59 min" = relative_date_from_ms(timestamp, base_now)
}

pub fn relative_date_1_hour_ago_test() {
  let timestamp = base_now - ms_per_hour
  let assert "hace 1h" = relative_date_from_ms(timestamp, base_now)
}

pub fn relative_date_3_hours_ago_test() {
  let timestamp = base_now - { 3 * ms_per_hour }
  let assert "hace 3h" = relative_date_from_ms(timestamp, base_now)
}

pub fn relative_date_23_hours_ago_test() {
  let timestamp = base_now - { 23 * ms_per_hour }
  let assert "hace 23h" = relative_date_from_ms(timestamp, base_now)
}

pub fn relative_date_yesterday_test() {
  let timestamp = base_now - { 30 * ms_per_hour }
  let assert "ayer" = relative_date_from_ms(timestamp, base_now)
}

pub fn relative_date_2_days_ago_test() {
  let timestamp = base_now - { 2 * ms_per_day }
  let assert "hace 2 días" = relative_date_from_ms(timestamp, base_now)
}

pub fn relative_date_5_days_ago_test() {
  let timestamp = base_now - { 5 * ms_per_day }
  let assert "hace 5 días" = relative_date_from_ms(timestamp, base_now)
}

pub fn relative_date_6_days_ago_test() {
  let timestamp = base_now - { 6 * ms_per_day }
  let assert "hace 6 días" = relative_date_from_ms(timestamp, base_now)
}

pub fn relative_date_future_test() {
  let timestamp = base_now + ms_per_hour
  let assert "en el futuro" = relative_date_from_ms(timestamp, base_now)
}

pub fn relative_date_older_than_week_uses_calendar_date_test() {
  let timestamp = base_now - { 8 * ms_per_day }
  let assert "14 ene 2026" = relative_date_from_ms(timestamp, base_now)
}

pub fn relative_date_older_than_week_handles_leap_day_test() {
  let leap_day = 1_709_164_800_000
  let now = leap_day + { 8 * ms_per_day }
  let assert "29 feb 2024" = relative_date_from_ms(leap_day, now)
}

pub fn relative_date_older_than_week_handles_epoch_test() {
  let assert "1 ene 1970" = relative_date_from_ms(0, 8 * ms_per_day)
}

// =============================================================================
// short_date tests
// =============================================================================

pub fn short_date_january_test() {
  let assert "21 ene 2026" = short_date("2026-01-21T00:00:00Z")
}

pub fn short_date_december_test() {
  let assert "25 dic 2025" = short_date("2025-12-25T10:30:00Z")
}

pub fn short_date_single_digit_day_test() {
  let assert "5 mar 2026" = short_date("2026-03-05T08:15:00Z")
}

pub fn short_date_february_test() {
  let assert "14 feb 2026" = short_date("2026-02-14T12:00:00Z")
}

pub fn short_date_for_english_locale_test() {
  let assert "14 Feb 2026" =
    short_date_for_locale(locale.En, "2026-02-14T12:00:00Z")
}

pub fn short_date_for_spanish_locale_test() {
  let assert "14 feb 2026" =
    short_date_for_locale(locale.Es, "2026-02-14T12:00:00Z")
}

// =============================================================================
// full_date tests
// =============================================================================

pub fn full_date_with_time_test() {
  let assert "21 de enero de 2026, 21:01" = full_date("2026-01-21T21:01:00Z")
}

pub fn full_date_morning_test() {
  let assert "15 de marzo de 2026, 08:30" = full_date("2026-03-15T08:30:00Z")
}

pub fn full_date_midnight_test() {
  let assert "31 de diciembre de 2026, 00:00" =
    full_date("2026-12-31T00:00:00Z")
}

pub fn full_date_with_milliseconds_test() {
  let assert "20 de junio de 2026, 14:45" =
    full_date("2026-06-20T14:45:30.123Z")
}

pub fn full_date_for_english_locale_test() {
  let assert "June 20, 2026, 14:45" =
    full_date_for_locale(locale.En, "2026-06-20T14:45:30.123Z")
}
