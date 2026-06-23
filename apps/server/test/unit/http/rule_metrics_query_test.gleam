import gleam/time/timestamp
import scrumbringer_server/http/rule_metrics

pub fn parse_pagination_query_uses_defaults_test() {
  let assert Ok(#(50, 0)) = rule_metrics.parse_pagination_query([])
}

pub fn parse_pagination_query_accepts_valid_values_test() {
  let assert Ok(#(25, 10)) =
    rule_metrics.parse_pagination_query([#("limit", "25"), #("offset", "10")])
}

pub fn parse_pagination_query_rejects_invalid_limit_test() {
  let assert Error(_) = rule_metrics.parse_pagination_query([#("limit", "101")])
  let assert Error(_) =
    rule_metrics.parse_pagination_query([#("limit", "nope")])
}

pub fn parse_pagination_query_rejects_invalid_offset_test() {
  let assert Error(_) = rule_metrics.parse_pagination_query([#("offset", "-1")])
  let assert Error(_) =
    rule_metrics.parse_pagination_query([#("offset", "nope")])
}

pub fn parse_pagination_query_rejects_duplicate_values_test() {
  let assert Error(_) =
    rule_metrics.parse_pagination_query([#("limit", "10"), #("limit", "20")])
  let assert Error(_) =
    rule_metrics.parse_pagination_query([#("offset", "0"), #("offset", "1")])
}

pub fn parse_date_range_query_uses_defaults_test() {
  let from = timestamp("2026-01-01T00:00:00Z")
  let to = timestamp("2026-01-31T00:00:00Z")

  let assert Ok(#(parsed_from, parsed_to)) =
    rule_metrics.parse_date_range_query([], from, to)
  let assert True = parsed_from == from
  let assert True = parsed_to == to
}

pub fn parse_date_range_query_accepts_calendar_dates_test() {
  let default_from = timestamp("2026-01-01T00:00:00Z")
  let default_to = timestamp("2026-01-31T00:00:00Z")
  let from = timestamp("2026-01-10T00:00:00Z")
  let to = timestamp("2026-01-20T23:59:59Z")

  let assert Ok(#(parsed_from, parsed_to)) =
    rule_metrics.parse_date_range_query(
      [#("from", "2026-01-10"), #("to", "2026-01-20")],
      default_from,
      default_to,
    )
  let assert True = parsed_from == from
  let assert True = parsed_to == to
}

pub fn parse_date_range_query_converts_to_inclusive_utc_day_test() {
  let default_from = timestamp("2026-01-01T00:00:00Z")
  let default_to = timestamp("2026-01-31T00:00:00Z")
  let from = timestamp("2026-02-03T00:00:00Z")
  let to = timestamp("2026-02-03T23:59:59Z")

  let assert Ok(#(parsed_from, parsed_to)) =
    rule_metrics.parse_date_range_query(
      [#("from", "2026-02-03"), #("to", "2026-02-03")],
      default_from,
      default_to,
    )
  let assert True = parsed_from == from
  let assert True = parsed_to == to
}

pub fn parse_date_range_query_rejects_rfc3339_timestamps_test() {
  let default_from = timestamp("2026-01-01T00:00:00Z")
  let default_to = timestamp("2026-01-31T00:00:00Z")

  let assert Error(_) =
    rule_metrics.parse_date_range_query(
      [#("from", "2026-01-10T08:15:30Z"), #("to", "2026-01-20T16:45:00Z")],
      default_from,
      default_to,
    )
}

pub fn parse_date_range_query_allows_ninety_calendar_days_test() {
  let default_from = timestamp("2026-01-01T00:00:00Z")
  let default_to = timestamp("2026-01-31T00:00:00Z")

  let assert Ok(_) =
    rule_metrics.parse_date_range_query(
      [#("from", "2026-01-01"), #("to", "2026-03-31")],
      default_from,
      default_to,
    )
}

pub fn parse_date_range_query_rejects_over_ninety_calendar_days_test() {
  let default_from = timestamp("2026-01-01T00:00:00Z")
  let default_to = timestamp("2026-01-31T00:00:00Z")

  let assert Error(_) =
    rule_metrics.parse_date_range_query(
      [#("from", "2026-01-01"), #("to", "2026-04-01")],
      default_from,
      default_to,
    )
}

pub fn parse_date_range_query_rejects_invalid_dates_test() {
  let default_from = timestamp("2026-01-01T00:00:00Z")
  let default_to = timestamp("2026-01-31T00:00:00Z")

  let assert Error(_) =
    rule_metrics.parse_date_range_query(
      [#("from", "not-a-date")],
      default_from,
      default_to,
    )
  let assert Error(_) =
    rule_metrics.parse_date_range_query(
      [#("to", "not-a-date")],
      default_from,
      default_to,
    )
}

pub fn parse_date_range_query_rejects_duplicate_dates_test() {
  let default_from = timestamp("2026-01-01T00:00:00Z")
  let default_to = timestamp("2026-01-31T00:00:00Z")

  let assert Error(_) =
    rule_metrics.parse_date_range_query(
      [
        #("from", "2026-01-10"),
        #("from", "2026-01-11"),
      ],
      default_from,
      default_to,
    )
}

fn timestamp(value: String) -> timestamp.Timestamp {
  let assert Ok(ts) = timestamp.parse_rfc3339(value)
  ts
}
