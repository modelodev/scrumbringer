import birl
import birl/interval
import gleam/order

pub fn try_scale_up_reports_empty_interval_test() {
  let assert Ok(value) =
    interval.from_start_and_end(
      birl.from_unix_micro(0),
      birl.from_unix_micro(10),
    )

  let assert Error(Nil) = interval.try_scale_up(value, 0)
}

pub fn scale_up_keeps_original_interval_when_scaling_to_empty_test() {
  let start = birl.from_unix_micro(0)
  let end = birl.from_unix_micro(10)
  let assert Ok(value) = interval.from_start_and_end(start, end)

  let scaled = interval.scale_up(value, 0)
  let #(scaled_start, scaled_end) = interval.get_bounds(scaled)

  let assert order.Eq = birl.compare(start, scaled_start)
  let assert order.Eq = birl.compare(end, scaled_end)
}
