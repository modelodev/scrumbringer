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

import domain/task_status.{type TaskStatus}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import scrumbringer_server/http/api
import scrumbringer_server/services/workflows/types as workflow_types
import wisp

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
///   Ok(TaskFilters(status: Some(Available), type_id: 5, ..)) -> // parsed
///   Error(response) -> response
/// }
/// ```
pub fn parse_task_filters(
  query: List(#(String, String)),
) -> Result(workflow_types.TaskFilters, wisp.Response) {
  use status <- result.try(parse_status_filter(query))
  use type_id <- result.try(parse_int_filter(query, "type_id"))
  use capability_id <- result.try(parse_capability_filter(query))
  use q <- result.try(parse_string_filter(query, "q"))
  Ok(workflow_types.TaskFilters(
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
///
/// Returns None for empty/missing, Some(TaskStatus) for valid values,
/// Error for invalid values.
fn parse_status_filter(
  query: List(#(String, String)),
) -> Result(Option(TaskStatus), wisp.Response) {
  case single_query_value(query, "status") {
    Ok(None) -> Ok(None)

    Ok(Some(value)) ->
      case task_status.parse_filter(value) {
        Ok(status) -> Ok(Some(status))
        Error(_) -> Error(api.error(422, "VALIDATION_ERROR", "Invalid status"))
      }

    Error(_) -> Error(api.error(422, "VALIDATION_ERROR", "Invalid status"))
  }
}

/// Parse capability_id filter: no commas allowed (single value only).
fn parse_capability_filter(
  query: List(#(String, String)),
) -> Result(Option(Int), wisp.Response) {
  case single_query_value(query, "capability_id") {
    Ok(None) -> Ok(None)

    Ok(Some(value)) ->
      case string.contains(value, ",") {
        True ->
          Error(api.error(422, "VALIDATION_ERROR", "Invalid capability_id"))
        False ->
          case int.parse(value) {
            Ok(id) -> Ok(Some(id))
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
/// parse_int_filter([#("type_id", "5")], "type_id")  // Ok(Some(5))
/// parse_int_filter([], "type_id")                   // Ok(None)
/// ```
pub fn parse_int_filter(
  query: List(#(String, String)),
  key: String,
) -> Result(Option(Int), wisp.Response) {
  case single_query_value(query, key) {
    Ok(None) -> Ok(None)

    Ok(Some(value)) ->
      case int.parse(value) {
        Ok(id) -> Ok(Some(id))
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
/// parse_string_filter([#("q", "search")], "q")  // Ok(Some("search"))
/// parse_string_filter([], "q")                   // Ok(None)
/// ```
pub fn parse_string_filter(
  query: List(#(String, String)),
  key: String,
) -> Result(Option(String), wisp.Response) {
  case single_query_value(query, key) {
    Ok(None) -> Ok(None)
    Ok(Some(value)) -> Ok(normalize_optional_string(value))
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

fn normalize_optional_string(value: String) -> Option(String) {
  case value == "" {
    True -> None
    False -> Some(value)
  }
}
