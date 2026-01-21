//// Task validation functions for Scrumbringer server.
////
//// ## Mission
////
//// Provides validation functions for task-related inputs including titles,
//// priorities, task types, and capabilities.
////
//// ## Usage
////
//// ```gleam
//// import scrumbringer_server/http/tasks/validators
////
//// case validators.validate_task_title(raw_title) {
////   Ok(title) -> // use validated title
////   Error(response) -> response
//// }
//// ```

import gleam/option.{type Option, None, Some}
import gleam/string
import pog
import scrumbringer_server/http/api
import scrumbringer_server/services/capabilities_db
import scrumbringer_server/services/projects_db
import scrumbringer_server/services/task_types_db
import wisp

// =============================================================================
// Constants
// =============================================================================

/// Maximum allowed characters for task title.
pub const max_task_title_chars = 56

/// Sentinel value indicating an optional field was not provided.
pub const unset_string = "__unset__"

// =============================================================================
// Title Validation
// =============================================================================

/// Validate task title: required, non-empty, max 56 characters.
///
/// ## Example
///
/// ```gleam
/// case validate_task_title("  My Task  ") {
///   Ok("My Task") -> // trimmed and valid
///   Error(response) -> response
/// }
/// ```
pub fn validate_task_title(title: String) -> Result(String, wisp.Response) {
  let title = string.trim(title)

  case title == "" {
    True -> Error(api.error(422, "VALIDATION_ERROR", "Title is required"))
    False ->
      case string.length(title) <= max_task_title_chars {
        True -> Ok(title)
        False ->
          Error(api.error(
            422,
            "VALIDATION_ERROR",
            "Title too long (max 56 characters)",
          ))
      }
  }
}

// =============================================================================
// Priority Validation
// =============================================================================

/// Validate priority: must be 1-5.
///
/// ## Example
///
/// ```gleam
/// case validate_priority(3) {
///   Ok(Nil) -> // priority is valid
///   Error(response) -> response
/// }
/// ```
pub fn validate_priority(priority: Int) -> Result(Nil, wisp.Response) {
  case priority >= 1 && priority <= 5 {
    True -> Ok(Nil)
    False -> Error(api.error(422, "VALIDATION_ERROR", "Invalid priority"))
  }
}

/// Validate optional priority: -1 means not provided, otherwise 1-5.
///
/// ## Example
///
/// ```gleam
/// validate_optional_priority(-1)  // Ok(Nil) - not provided
/// validate_optional_priority(3)   // Ok(Nil) - valid
/// validate_optional_priority(10)  // Error - invalid
/// ```
pub fn validate_optional_priority(priority: Int) -> Result(Nil, wisp.Response) {
  case priority {
    -1 -> Ok(Nil)
    _ -> validate_priority(priority)
  }
}

// =============================================================================
// Type Validation
// =============================================================================

/// Validate task type update: -1 means no update, otherwise check project.
///
/// ## Example
///
/// ```gleam
/// case validate_type_update(db, type_id, project_id) {
///   Ok(Nil) -> // type is valid or not being updated
///   Error(response) -> response
/// }
/// ```
pub fn validate_type_update(
  db: pog.Connection,
  type_id: Int,
  project_id: Int,
) -> Result(Nil, wisp.Response) {
  case type_id {
    -1 -> Ok(Nil)
    id ->
      case task_types_db.is_task_type_in_project(db, id, project_id) {
        Ok(True) -> Ok(Nil)
        Ok(False) ->
          Error(api.error(422, "VALIDATION_ERROR", "Invalid type_id"))
        Error(_) -> Error(api.error(500, "INTERNAL", "Database error"))
      }
  }
}

// =============================================================================
// Capability Validation
// =============================================================================

/// Validate capability belongs to project.
///
/// ## Example
///
/// ```gleam
/// case validate_capability_in_project(db, Some(5), project_id) {
///   Ok(Nil) -> // capability is valid
///   Error(response) -> response
/// }
/// ```
pub fn validate_capability_in_project(
  db: pog.Connection,
  capability_id: Option(Int),
  project_id: Int,
) -> Result(Nil, wisp.Response) {
  case capability_id {
    None -> Ok(Nil)

    Some(id) ->
      case capabilities_db.capability_is_in_project(db, id, project_id) {
        Ok(True) -> Ok(Nil)
        Ok(False) ->
          Error(api.error(422, "VALIDATION_ERROR", "Invalid capability_id"))
        Error(_) -> Error(api.error(500, "INTERNAL", "Database error"))
      }
  }
}

// =============================================================================
// Authorization Helpers
// =============================================================================

/// Require user is a member of the project.
///
/// ## Example
///
/// ```gleam
/// case require_project_member(db, project_id, user_id) {
///   Ok(Nil) -> // user is member
///   Error(response) -> response
/// }
/// ```
pub fn require_project_member(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
) -> Result(Nil, wisp.Response) {
  case projects_db.is_project_member(db, project_id, user_id) {
    Ok(True) -> Ok(Nil)
    Ok(False) -> Error(api.error(403, "FORBIDDEN", "Forbidden"))
    Error(_) -> Error(api.error(500, "INTERNAL", "Database error"))
  }
}

/// Require user is an admin of the project.
///
/// ## Example
///
/// ```gleam
/// case require_project_admin(db, project_id, user_id) {
///   Ok(Nil) -> // user is admin
///   Error(response) -> response
/// }
/// ```
pub fn require_project_admin(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
) -> Result(Nil, wisp.Response) {
  case projects_db.is_project_manager(db, project_id, user_id) {
    Ok(True) -> Ok(Nil)
    Ok(False) -> Error(api.error(403, "FORBIDDEN", "Forbidden"))
    Error(_) -> Error(api.error(500, "INTERNAL", "Database error"))
  }
}
