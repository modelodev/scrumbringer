import gleam/option
import scrumbringer_server/http/query

pub fn single_value_returns_none_when_key_is_absent_test() {
  let assert Ok(option.None) = query.single_value([#("other", "1")], "key")
}

pub fn single_value_returns_value_when_key_is_present_once_test() {
  let assert Ok(option.Some("30")) =
    query.single_value([#("window_days", "30"), #("other", "1")], "window_days")
}

pub fn single_value_rejects_duplicate_keys_test() {
  let assert Error(Nil) =
    query.single_value(
      [#("window_days", "30"), #("window_days", "60")],
      "window_days",
    )
}

pub fn has_value_returns_true_when_pair_exists_test() {
  let assert True =
    query.has_value(
      [#("include", "metrics"), #("other", "1")],
      "include",
      "metrics",
    )
}

pub fn has_value_returns_false_when_key_or_value_does_not_match_test() {
  let assert False =
    query.has_value([#("include", "tasks")], "include", "metrics")
  let assert False =
    query.has_value([#("other", "metrics")], "include", "metrics")
}

pub fn bounded_int_uses_default_when_key_is_absent_test() {
  let assert Ok(30) = query.bounded_int([], "window_days", 30, 1, 90)
}

pub fn bounded_int_accepts_value_inside_range_test() {
  let assert Ok(60) =
    query.bounded_int([#("window_days", "60")], "window_days", 30, 1, 90)
}

pub fn bounded_int_rejects_invalid_values_test() {
  let assert Error(Nil) =
    query.bounded_int([#("window_days", "0")], "window_days", 30, 1, 90)
  let assert Error(Nil) =
    query.bounded_int([#("window_days", "91")], "window_days", 30, 1, 90)
  let assert Error(Nil) =
    query.bounded_int([#("window_days", "many")], "window_days", 30, 1, 90)
}

pub fn bounded_int_rejects_duplicate_keys_test() {
  let assert Error(Nil) =
    query.bounded_int(
      [#("window_days", "30"), #("window_days", "60")],
      "window_days",
      30,
      1,
      90,
    )
}
