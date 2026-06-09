import birl

pub fn parse_iso8601_basic_value_test() {
  let assert Ok(value) = birl.parse("2019-03-26T14:30:00Z")

  let assert "2019-03-26T14:30:00.000Z" = birl.to_iso8601(value)
}

pub fn parse_relative_accepts_from_now_phrase_test() {
  let assert Ok(origin) = birl.parse("2019-03-26T14:30:00Z")

  let assert Ok(value) = birl.parse_relative(origin, "8 minutes from now")

  let assert "2019-03-26T14:38:00.000Z" = birl.to_iso8601(value)
}

pub fn parse_relative_accepts_in_the_future_phrase_test() {
  let assert Ok(origin) = birl.parse("2019-03-26T14:30:00Z")

  let assert Ok(value) = birl.parse_relative(origin, "2 hours in the future")

  let assert "2019-03-26T16:30:00.000Z" = birl.to_iso8601(value)
}

pub fn parse_relative_accepts_in_the_past_phrase_test() {
  let assert Ok(origin) = birl.parse("2019-03-26T14:30:00Z")

  let assert Ok(value) = birl.parse_relative(origin, "3 days in the past")

  let assert "2019-03-23T14:30:00.000Z" = birl.to_iso8601(value)
}
