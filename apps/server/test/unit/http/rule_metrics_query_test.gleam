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

pub fn parse_date_range_query_accepts_valid_dates_test() {
  let default_from = timestamp("2026-01-01T00:00:00Z")
  let default_to = timestamp("2026-01-31T00:00:00Z")
  let from = timestamp("2026-01-10T00:00:00Z")
  let to = timestamp("2026-01-20T00:00:00Z")

  let assert Ok(#(parsed_from, parsed_to)) =
    rule_metrics.parse_date_range_query(
      [#("from", "2026-01-10T00:00:00Z"), #("to", "2026-01-20T00:00:00Z")],
      default_from,
      default_to,
    )
  let assert True = parsed_from == from
  let assert True = parsed_to == to
}

pub fn parse_date_range_query_accepts_calendar_dates_test() {
  let default_from = timestamp("2026-01-01T00:00:00Z")
  let default_to = timestamp("2026-01-31T00:00:00Z")
  let from = timestamp("2026-01-10T00:00:00Z")
  let to = timestamp("2026-01-20T00:00:00Z")

  let assert Ok(#(parsed_from, parsed_to)) =
    rule_metrics.parse_date_range_query(
      [#("from", "2026-01-10"), #("to", "2026-01-20")],
      default_from,
      default_to,
    )
  let assert True = parsed_from == from
  let assert True = parsed_to == to
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
        #("from", "2026-01-10T00:00:00Z"),
        #("from", "2026-01-11T00:00:00Z"),
      ],
      default_from,
      default_to,
    )
}

fn timestamp(value: String) -> timestamp.Timestamp {
  let assert Ok(ts) = timestamp.parse_rfc3339(value)
  ts
}
