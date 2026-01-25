//// Shared validation helpers for task workflows and HTTP handlers.
////
//// Provides common validation logic with a minimal error model that
//// can be mapped to HTTP responses or workflow domain errors.

import gleam/option.{type Option, None, Some}
import gleam/string
import pog
import scrumbringer_server/services/capabilities_db
import scrumbringer_server/services/task_types_db

pub type ValidationIssue {
  ValidationError(String)
  DbError(pog.QueryError)
}

const max_task_title_chars = 56

pub fn validate_task_title_value(
  title: String,
) -> Result(String, ValidationIssue) {
  let title = string.trim(title)

  case title == "" {
    True -> Error(ValidationError("Title is required"))
    False ->
      case string.length(title) <= max_task_title_chars {
        True -> Ok(title)
        False -> Error(ValidationError("Title too long (max 56 characters)"))
      }
  }
}

pub fn validate_priority_value(priority: Int) -> Result(Nil, ValidationIssue) {
  case priority >= 1 && priority <= 5 {
    True -> Ok(Nil)
    False -> Error(ValidationError("Invalid priority"))
  }
}

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

pub fn validate_capability_in_project(
  db: pog.Connection,
  capability_id: Option(Int),
  project_id: Int,
) -> Result(Nil, ValidationIssue) {
  case capability_id {
    None -> Ok(Nil)
    Some(id) ->
      case capabilities_db.capability_is_in_project(db, id, project_id) {
        Ok(True) -> Ok(Nil)
        Ok(False) -> Error(ValidationError("Invalid capability_id"))
        Error(e) -> Error(DbError(e))
      }
  }
}
