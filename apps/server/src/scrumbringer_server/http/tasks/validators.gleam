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

import gleam/option.{type Option}
import pog
import scrumbringer_server/http/api
import scrumbringer_server/services/projects_db
import scrumbringer_server/services/workflows/types.{
  type FieldUpdate, Set, Unset,
}
import scrumbringer_server/services/workflows/validation_core
import wisp

// =============================================================================
// Constants
// =============================================================================

/// Maximum allowed characters for task title.
pub const max_task_title_chars = 56

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
  case validation_core.validate_task_title_value(title) {
    Ok(value) -> Ok(value)
    Error(validation_core.ValidationError(msg)) ->
      Error(api.error(422, "VALIDATION_ERROR", msg))
    Error(validation_core.DbError(_)) ->
      Error(api.error(500, "INTERNAL", "Database error"))
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
  case validation_core.validate_priority_value(priority) {
    Ok(Nil) -> Ok(Nil)
    Error(validation_core.ValidationError(msg)) ->
      Error(api.error(422, "VALIDATION_ERROR", msg))
    Error(validation_core.DbError(_)) ->
      Error(api.error(500, "INTERNAL", "Database error"))
  }
}

/// Validate optional priority: Unset means not provided, otherwise 1-5.
///
/// ## Example
///
/// ```gleam
/// validate_optional_priority(Unset)    // Ok(Nil) - not provided
/// validate_optional_priority(Set(3))   // Ok(Nil) - valid
/// validate_optional_priority(Set(10))  // Error - invalid
/// ```
pub fn validate_optional_priority(
  priority: FieldUpdate(Int),
) -> Result(Nil, wisp.Response) {
  case priority {
    Unset -> Ok(Nil)
    Set(value) ->
      case validation_core.validate_priority_value(value) {
        Ok(Nil) -> Ok(Nil)
        Error(validation_core.ValidationError(msg)) ->
          Error(api.error(422, "VALIDATION_ERROR", msg))
        Error(validation_core.DbError(_)) ->
          Error(api.error(500, "INTERNAL", "Database error"))
      }
  }
}

// =============================================================================
// Type Validation
// =============================================================================

/// Validate task type update: Unset means no update, otherwise check project.
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
  type_id: FieldUpdate(Int),
  project_id: Int,
) -> Result(Nil, wisp.Response) {
  case type_id {
    Unset -> Ok(Nil)
    Set(value) ->
      case
        validation_core.validate_task_type_in_project(db, value, project_id)
      {
        Ok(Nil) -> Ok(Nil)
        Error(validation_core.ValidationError(msg)) ->
          Error(api.error(422, "VALIDATION_ERROR", msg))
        Error(validation_core.DbError(_)) ->
          Error(api.error(500, "INTERNAL", "Database error"))
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
  case
    validation_core.validate_capability_in_project(
      db,
      capability_id,
      project_id,
    )
  {
    Ok(Nil) -> Ok(Nil)
    Error(validation_core.ValidationError(msg)) ->
      Error(api.error(422, "VALIDATION_ERROR", msg))
    Error(validation_core.DbError(_)) ->
      Error(api.error(500, "INTERNAL", "Database error"))
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
