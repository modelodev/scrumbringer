import birl

pub fn try_set_day_preserves_timezone_and_offset_test() {
  let assert Ok(value) = birl.parse("2019-03-26T14:30:00+03:30")

  let assert Ok(updated) = birl.try_set_day(value, birl.Day(2020, 4, 5))

  let assert "2020-04-05T14:30:00.000+03:30" = birl.to_iso8601(updated)
}

pub fn try_set_time_of_day_preserves_date_and_offset_test() {
  let assert Ok(value) = birl.parse("2019-03-26T14:30:00+03:30")

  let assert Ok(updated) =
    birl.try_set_time_of_day(value, birl.TimeOfDay(7, 8, 9, 10))

  let assert "2019-03-26T07:08:09.010+03:30" = birl.to_iso8601(updated)
}
