//// Task filter parsing functions for Scrumbringer server.
////
//// ## Mission
////
//// Provides query parameter parsing for task list filtering including
//// status, type_id, capability_id, and search query.
////
//// ## Usage
////
//// ```gleam
//// import scrumbringer_server/http/tasks/filters
////
//// let query = wisp.get_query(req)
//// case filters.parse_task_filters(query) {
////   Ok(filters) -> // use filters
////   Error(response) -> response
//// }
//// ```

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import scrumbringer_server/http/api
import wisp

// =============================================================================
// Types
// =============================================================================

/// Parsed task list filters.
///
/// Empty string or 0 means "no filter applied".
pub type TaskFilters {
  TaskFilters(status: String, type_id: Int, capability_id: Int, q: String)
}

// =============================================================================
// Main Parser
// =============================================================================

/// Parse all task filters from query parameters.
///
/// ## Example
///
/// ```gleam
/// let query = [#("status", "available"), #("type_id", "5")]
/// case parse_task_filters(query) {
///   Ok(TaskFilters(status: "available", type_id: 5, ..)) -> // parsed
///   Error(response) -> response
/// }
/// ```
pub fn parse_task_filters(
  query: List(#(String, String)),
) -> Result(TaskFilters, wisp.Response) {
  use status <- result.try(parse_status_filter(query))
  use type_id <- result.try(parse_int_filter(query, "type_id"))
  use capability_id <- result.try(parse_capability_filter(query))
  use q <- result.try(parse_string_filter(query, "q"))
  Ok(TaskFilters(
    status: status,
    type_id: type_id,
    capability_id: capability_id,
    q: q,
  ))
}

// =============================================================================
// Individual Parsers
// =============================================================================

/// Parse status filter: must be available, claimed, or completed.
fn parse_status_filter(
  query: List(#(String, String)),
) -> Result(String, wisp.Response) {
  case single_query_value(query, "status") {
    Ok(None) -> Ok("")

    Ok(Some(value)) ->
      case value {
        "available" | "claimed" | "completed" -> Ok(value)
        _ -> Error(api.error(422, "VALIDATION_ERROR", "Invalid status"))
      }

    Error(_) -> Error(api.error(422, "VALIDATION_ERROR", "Invalid status"))
  }
}

/// Parse capability_id filter: no commas allowed (single value only).
fn parse_capability_filter(
  query: List(#(String, String)),
) -> Result(Int, wisp.Response) {
  case single_query_value(query, "capability_id") {
    Ok(None) -> Ok(0)

    Ok(Some(value)) ->
      case string.contains(value, ",") {
        True ->
          Error(api.error(422, "VALIDATION_ERROR", "Invalid capability_id"))
        False ->
          case int.parse(value) {
            Ok(id) -> Ok(id)
            Error(_) ->
              Error(api.error(422, "VALIDATION_ERROR", "Invalid capability_id"))
          }
      }

    Error(_) ->
      Error(api.error(422, "VALIDATION_ERROR", "Invalid capability_id"))
  }
}

/// Parse integer filter from query parameter.
///
/// ## Example
///
/// ```gleam
/// parse_int_filter([#("type_id", "5")], "type_id")  // Ok(5)
/// parse_int_filter([], "type_id")                   // Ok(0)
/// ```
pub fn parse_int_filter(
  query: List(#(String, String)),
  key: String,
) -> Result(Int, wisp.Response) {
  case single_query_value(query, key) {
    Ok(None) -> Ok(0)

    Ok(Some(value)) ->
      case int.parse(value) {
        Ok(id) -> Ok(id)
        Error(_) -> Error(api.error(422, "VALIDATION_ERROR", "Invalid " <> key))
      }

    Error(_) -> Error(api.error(422, "VALIDATION_ERROR", "Invalid " <> key))
  }
}

/// Parse string filter from query parameter.
///
/// ## Example
///
/// ```gleam
/// parse_string_filter([#("q", "search")], "q")  // Ok("search")
/// parse_string_filter([], "q")                   // Ok("")
/// ```
pub fn parse_string_filter(
  query: List(#(String, String)),
  key: String,
) -> Result(String, wisp.Response) {
  case single_query_value(query, key) {
    Ok(None) -> Ok("")
    Ok(Some(value)) -> Ok(value)
    Error(_) -> Error(api.error(422, "VALIDATION_ERROR", "Invalid " <> key))
  }
}

// =============================================================================
// Helper Functions
// =============================================================================

/// Extract single value from query parameters.
///
/// Returns Error if key appears multiple times.
///
/// ## Example
///
/// ```gleam
/// single_query_value([#("a", "1")], "a")        // Ok(Some("1"))
/// single_query_value([], "a")                   // Ok(None)
/// single_query_value([#("a", "1"), #("a", "2")], "a")  // Error(Nil)
/// ```
pub fn single_query_value(
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
