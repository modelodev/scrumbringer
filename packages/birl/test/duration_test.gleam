import birl/duration
import gleam/order

pub fn parse_accurate_prefix_without_assert_test() {
  let assert Ok(parsed) = duration.parse("accurate: 1 day")
  let expected = duration.accurate_new([#(1, duration.Day)])

  let assert order.Eq = duration.compare(expected, parsed)
}
