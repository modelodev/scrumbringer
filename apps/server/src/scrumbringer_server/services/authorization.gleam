//// Shared authorization helpers for project-scoped resources.
////
//// Provides a single source of truth for membership and manager checks.

import domain/org_role.{Admin}
import pog
import scrumbringer_server/http/api
import scrumbringer_server/services/projects_db
import scrumbringer_server/services/store_state.{type StoredUser}
import scrumbringer_server/sql
import wisp

/// Check if user is a member of the given project.
pub fn is_project_member(
  db: pog.Connection,
  user_id: Int,
  project_id: Int,
) -> Bool {
  case sql.project_members_is_member(db, project_id, user_id) {
    Ok(pog.Returned(rows: [row, ..], ..)) -> row.is_member
    _ -> False
  }
}

/// Check if user is a manager of the given project.
pub fn is_project_manager(
  db: pog.Connection,
  user_id: Int,
  project_id: Int,
) -> Bool {
  case sql.project_members_is_manager(db, project_id, user_id) {
    Ok(pog.Returned(rows: [row, ..], ..)) -> row.is_manager
    _ -> False
  }
}

/// Require user is manager for a project-scoped resource.
/// Returns Ok(#(org_id, project_id)) on success for use in subsequent operations.
pub fn require_project_manager(
  db: pog.Connection,
  user: StoredUser,
  org_id: Int,
  project_id: Int,
) -> Result(#(Int, Int), wisp.Response) {
  case projects_db.is_project_manager(db, project_id, user.id) {
    Ok(True) -> Ok(#(org_id, project_id))
    Ok(False) -> Error(api.error(403, "FORBIDDEN", "Forbidden"))
    Error(_) -> Error(api.error(500, "INTERNAL", "Database error"))
  }
}

/// Require user is manager for a project-scoped resource.
/// Returns Ok(Nil) on success.
pub fn require_project_manager_simple(
  db: pog.Connection,
  user: StoredUser,
  org_id: Int,
  project_id: Int,
) -> Result(Nil, wisp.Response) {
  case require_project_manager(db, user, org_id, project_id) {
    Ok(_) -> Ok(Nil)
    Error(e) -> Error(e)
  }
}

/// Require user is manager for a project-scoped resource.
/// Org admins always have access regardless of project assignment.
pub fn require_project_manager_with_org_bypass(
  db: pog.Connection,
  user: StoredUser,
  project_id: Int,
) -> Result(Nil, wisp.Response) {
  case user.org_role {
    Admin -> Ok(Nil)
    _ ->
      case projects_db.is_project_manager(db, project_id, user.id) {
        Ok(True) -> Ok(Nil)
        _ -> Error(api.error(403, "FORBIDDEN", "Manager role required"))
      }
  }
}
