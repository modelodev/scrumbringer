//// Small helpers for HTTP query parameter parsing.

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}

pub fn single_value(
  query: List(#(String, String)),
  key: String,
) -> Result(Option(String), Nil) {
  let values =
    query
    |> list.filter_map(fn(pair) {
      case pair.0 == key {
        True -> Ok(pair.1)
        False -> Error(Nil)
      }
    })

  case values {
    [] -> Ok(None)
    [value] -> Ok(Some(value))
    _ -> Error(Nil)
  }
}

pub fn has_value(
  query: List(#(String, String)),
  key: String,
  value: String,
) -> Bool {
  query
  |> list.any(fn(pair) { pair.0 == key && pair.1 == value })
}

pub fn bounded_int(
  query: List(#(String, String)),
  key: String,
  default: Int,
  min: Int,
  max: Int,
) -> Result(Int, Nil) {
  case single_value(query, key) {
    Ok(None) -> Ok(default)
    Ok(Some(value)) ->
      case int.parse(value) {
        Ok(parsed) if parsed >= min && parsed <= max -> Ok(parsed)
        _ -> Error(Nil)
      }
    Error(_) -> Error(Nil)
  }
}
