//// Task workflow authorization helpers.
////
//// ## Mission
////
//// Provides authorization checks for task workflow operations including
//// project membership and admin role verification.
////
//// ## Responsibilities
////
//// - Check project membership
//// - Check project admin role
////
//// ## Relations
////
//// - **types.gleam**: Uses Error and Response types
//// - **handlers.gleam**: Calls these checks before operations

import pog
import scrumbringer_server/services/projects_db
import scrumbringer_server/services/workflows/types.{
  type Error, type Response, DbError, NotAuthorized,
}

// =============================================================================
// Authorization Helpers
// =============================================================================

/// Require user is a project member.
pub fn require_project_member(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
  next: fn(Nil) -> Result(Response, Error),
) -> Result(Response, Error) {
  case projects_db.is_project_member(db, project_id, user_id) {
    Ok(True) -> next(Nil)
    Ok(False) -> Error(NotAuthorized)
    Error(e) -> Error(DbError(e))
  }
}

/// Require user is a project admin.
pub fn require_project_admin(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
  next: fn(Nil) -> Result(Response, Error),
) -> Result(Response, Error) {
  case projects_db.is_project_admin(db, project_id, user_id) {
    Ok(True) -> next(Nil)
    Ok(False) -> Error(NotAuthorized)
    Error(e) -> Error(DbError(e))
  }
}
