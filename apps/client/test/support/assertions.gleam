import gleam/option.{type Option, None}
import gleam/string

pub fn assert_equal(actual: a, expected: a) {
  let assert True = actual == expected
}

pub fn assert_not_equal(actual: a, unexpected: a) {
  let assert False = actual == unexpected
}

pub fn assert_none(value: Option(a)) {
  let assert None = value
}

pub fn assert_true(value: Bool) {
  let assert True = value
}

pub fn assert_non_empty(value: String) {
  let assert False = string.is_empty(value)
}

pub fn assert_non_blank(value: String) {
  let assert False = value |> string.trim |> string.is_empty
}

pub fn assert_error(result: Result(a, b)) {
  let assert Error(_) = result
}
