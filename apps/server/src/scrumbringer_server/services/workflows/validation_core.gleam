//// Shared validation helpers for task workflows and HTTP handlers.
////
//// ## Mission
////
//// Provide shared, domain-level validation primitives.
////
//// ## Responsibilities
////
//// - Validate task titles, priorities, and project-scoped ids
//// - Return minimal error info for mapping by callers
////
//// ## Non-responsibilities
////
//// - HTTP response building (see `http/tasks/validators.gleam`)
//// - Workflow orchestration (see `services/workflows/handlers.gleam`)
////
//// ## Relationships
////
//// - Used by workflow and HTTP validation layers

import gleam/option.{type Option, None, Some}
import gleam/string
import pog
import scrumbringer_server/services/capabilities_db
import scrumbringer_server/services/task_types_db

/// Minimal validation error model for shared helpers.
pub type ValidationIssue {
  ValidationError(String)
  DbError(pog.QueryError)
}

const max_task_title_chars = 56

// Justification: nested case improves clarity for branching logic.
/// Validates a task title value and returns the trimmed string.
///
/// Example:
///   validate_task_title_value("My task")
pub fn validate_task_title_value(
  title: String,
) -> Result(String, ValidationIssue) {
  let title = string.trim(title)

  case title == "" {
    True -> Error(ValidationError("Title is required"))
    False ->
      // Justification: nested case enforces max length only when non-empty.
      case string.length(title) <= max_task_title_chars {
        True -> Ok(title)
        False -> Error(ValidationError("Title too long (max 56 characters)"))
      }
  }
}

/// Validates a priority value is between 1 and 5.
///
/// Example:
///   validate_priority_value(3)
pub fn validate_priority_value(priority: Int) -> Result(Nil, ValidationIssue) {
  case priority >= 1 && priority <= 5 {
    True -> Ok(Nil)
    False -> Error(ValidationError("Invalid priority"))
  }
}

/// Validates that a task type id belongs to a project.
///
/// Example:
///   validate_task_type_in_project(db, type_id, project_id)
pub fn validate_task_type_in_project(
  db: pog.Connection,
  type_id: Int,
  project_id: Int,
) -> Result(Nil, ValidationIssue) {
  case task_types_db.is_task_type_in_project(db, type_id, project_id) {
    Ok(True) -> Ok(Nil)
    Ok(False) -> Error(ValidationError("Invalid type_id"))
    Error(e) -> Error(DbError(e))
  }
}

// Justification: nested case improves clarity for branching logic.
/// Validates that a capability id belongs to a project.
///
/// Example:
///   validate_capability_in_project(db, Some(capability_id), project_id)
pub fn validate_capability_in_project(
  db: pog.Connection,
  capability_id: Option(Int),
  project_id: Int,
) -> Result(Nil, ValidationIssue) {
  case capability_id {
    None -> Ok(Nil)
    Some(id) ->
      // Justification: nested case performs DB validation only when provided.
      case capabilities_db.capability_is_in_project(db, id, project_id) {
        Ok(True) -> Ok(Nil)
        Ok(False) -> Error(ValidationError("Invalid capability_id"))
        Error(e) -> Error(DbError(e))
      }
  }
}
