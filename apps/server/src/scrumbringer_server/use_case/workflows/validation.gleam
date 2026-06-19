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

import domain/field_update.{type FieldUpdate, Set, Unchanged}
import gleam/option.{type Option}
import pog
import scrumbringer_server/use_case/workflows/types.{
  type Error, type Response, DbError, ValidationError,
}
import scrumbringer_server/use_case/workflows/validation_core

// =============================================================================
// Validation Helpers
// =============================================================================

fn validation_issue_to_error(issue: validation_core.ValidationIssue) -> Error {
  case issue {
    validation_core.ValidationError(msg) -> ValidationError(msg)
    validation_core.DbError(e) -> DbError(e)
  }
}

/// Validate task title: required and max 56 characters.
pub fn validate_task_title(
  title: String,
  next: fn(String) -> Result(Response, Error),
) -> Result(Response, Error) {
  case validation_core.validate_task_title_value(title) {
    Ok(value) -> next(value)
    Error(issue) -> Error(validation_issue_to_error(issue))
  }
}

/// Validate priority is in 1-5 range.
pub fn validate_priority(
  priority: Int,
  next: fn(Nil) -> Result(Response, Error),
) -> Result(Response, Error) {
  case validation_core.validate_priority_value(priority) {
    Ok(Nil) -> next(Nil)
    Error(issue) -> Error(validation_issue_to_error(issue))
  }
}

/// Validate optional priority (Unchanged means no update).
pub fn validate_optional_priority(
  priority: FieldUpdate(Int),
  next: fn(Nil) -> Result(Response, Error),
) -> Result(Response, Error) {
  case priority {
    Unchanged -> next(Nil)
    Set(value) ->
      case validation_core.validate_priority_value(value) {
        Ok(Nil) -> next(Nil)
        Error(issue) -> Error(validation_issue_to_error(issue))
      }
  }
}

/// Validate optional title (Unchanged means no update).
pub fn validate_optional_title(
  title: FieldUpdate(String),
  next: fn(Nil) -> Result(Response, Error),
) -> Result(Response, Error) {
  case title {
    Unchanged -> next(Nil)
    Set(value) ->
      case validation_core.validate_task_title_value(value) {
        Ok(_) -> next(Nil)
        Error(issue) -> Error(validation_issue_to_error(issue))
      }
  }
}

/// Validate task type belongs to project.
pub fn validate_task_type_in_project(
  db: pog.Connection,
  type_id: Int,
  project_id: Int,
  next: fn(Nil) -> Result(Response, Error),
) -> Result(Response, Error) {
  case validation_core.validate_task_type_in_project(db, type_id, project_id) {
    Ok(Nil) -> next(Nil)
    Error(issue) -> Error(validation_issue_to_error(issue))
  }
}

/// Validate type update (Unchanged means no update).
pub fn validate_type_update(
  db: pog.Connection,
  type_id: FieldUpdate(Int),
  project_id: Int,
  next: fn(Nil) -> Result(Response, Error),
) -> Result(Response, Error) {
  case type_id {
    Unchanged -> next(Nil)
    Set(value) ->
      case
        validation_core.validate_task_type_in_project(db, value, project_id)
      {
        Ok(Nil) -> next(Nil)
        Error(issue) -> Error(validation_issue_to_error(issue))
      }
  }
}

/// Validate capability belongs to project.
pub fn validate_capability_in_project(
  db: pog.Connection,
  capability_id: Option(Int),
  project_id: Int,
  next: fn(Nil) -> Result(Response, Error),
) -> Result(Response, Error) {
  case
    validation_core.validate_capability_in_project(
      db,
      capability_id,
      project_id,
    )
  {
    Ok(Nil) -> next(Nil)
    Error(validation_core.ValidationError(msg)) -> Error(ValidationError(msg))
    Error(validation_core.DbError(_)) ->
      Error(ValidationError("Invalid capability_id"))
  }
}
