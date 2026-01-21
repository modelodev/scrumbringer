//// Task workflow validation helpers.
////
//// ## Mission
////
//// Provides validation functions for task workflow operations including
//// title validation, priority validation, and type validation.
////
//// ## Responsibilities
////
//// - Validate task titles (required, max length)
//// - Validate priority values (1-5 range)
//// - Validate task types belong to project
//// - Validate capabilities belong to project
////
//// ## Relations
////
//// - **types.gleam**: Uses Error and Response types
//// - **handlers.gleam**: Calls these validators before operations

import gleam/option.{type Option, None, Some}
import gleam/string
import pog
import scrumbringer_server/services/capabilities_db
import scrumbringer_server/services/task_types_db
import scrumbringer_server/services/workflows/types.{
  type Error, type Response, DbError, ValidationError,
}

// =============================================================================
// Constants
// =============================================================================

/// Maximum allowed characters for task title.
const max_task_title_chars = 56

// =============================================================================
// Validation Helpers
// =============================================================================

/// Validate task title: required and max 56 characters.
pub fn validate_task_title(
  title: String,
  next: fn(String) -> Result(Response, Error),
) -> Result(Response, Error) {
  let title = string.trim(title)

  case title == "" {
    True -> Error(ValidationError("Title is required"))
    False ->
      case string.length(title) <= max_task_title_chars {
        True -> next(title)
        False -> Error(ValidationError("Title too long (max 56 characters)"))
      }
  }
}

/// Validate priority is in 1-5 range.
pub fn validate_priority(
  priority: Int,
  next: fn(Nil) -> Result(Response, Error),
) -> Result(Response, Error) {
  case priority >= 1 && priority <= 5 {
    True -> next(Nil)
    False -> Error(ValidationError("Invalid priority"))
  }
}

/// Validate optional priority (-1 means unset, otherwise 1-5).
pub fn validate_optional_priority(
  priority: Int,
  next: fn(Nil) -> Result(Response, Error),
) -> Result(Response, Error) {
  case priority {
    -1 -> next(Nil)
    _ -> validate_priority(priority, next)
  }
}

/// Validate task type belongs to project.
pub fn validate_task_type_in_project(
  db: pog.Connection,
  type_id: Int,
  project_id: Int,
  next: fn(Nil) -> Result(Response, Error),
) -> Result(Response, Error) {
  case task_types_db.is_task_type_in_project(db, type_id, project_id) {
    Ok(True) -> next(Nil)
    Ok(False) -> Error(ValidationError("Invalid type_id"))
    Error(e) -> Error(DbError(e))
  }
}

/// Validate type update (-1 means unset, otherwise validate).
pub fn validate_type_update(
  db: pog.Connection,
  type_id: Int,
  project_id: Int,
  next: fn(Nil) -> Result(Response, Error),
) -> Result(Response, Error) {
  case type_id {
    -1 -> next(Nil)
    id -> validate_task_type_in_project(db, id, project_id, next)
  }
}

/// Validate capability belongs to project.
pub fn validate_capability_in_project(
  db: pog.Connection,
  capability_id: Option(Int),
  project_id: Int,
  next: fn(Nil) -> Result(Response, Error),
) -> Result(Response, Error) {
  case capability_id {
    None -> next(Nil)

    Some(id) ->
      case capabilities_db.capability_is_in_project(db, id, project_id) {
        Ok(True) -> next(Nil)
        Ok(False) -> Error(ValidationError("Invalid capability_id"))
        Error(_) -> Error(ValidationError("Invalid capability_id"))
      }
  }
}
