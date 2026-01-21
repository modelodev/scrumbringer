//// HTTP authorization helpers for scoped resources.
////
//// Provides authorization checks for project-scoped resources.
//// Note: All resources are now project-scoped (no org-scoped workflows/templates).

import pog
import wisp
import domain/org_role.{Admin}
import scrumbringer_server/http/api
import scrumbringer_server/services/store_state.{type StoredUser}
import scrumbringer_server/services/projects_db

// =============================================================================
// Authorization Helpers
// =============================================================================

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
