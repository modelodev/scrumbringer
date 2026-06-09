import birl

pub fn parse_iso8601_basic_value_test() {
  let assert Ok(value) = birl.parse("2019-03-26T14:30:00Z")

  let assert "2019-03-26T14:30:00.000Z" = birl.to_iso8601(value)
}
