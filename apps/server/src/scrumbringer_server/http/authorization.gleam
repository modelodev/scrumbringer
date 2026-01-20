//// HTTP authorization helpers for scoped resources.
////
//// Provides authorization checks for resources scoped to org or project level.

import gleam/option.{type Option, None, Some}
import pog
import wisp
import domain/org_role.{Admin}
import scrumbringer_server/http/api
import scrumbringer_server/services/store_state.{type StoredUser}
import scrumbringer_server/services/projects_db

// =============================================================================
// Authorization Helpers
// =============================================================================

/// Require user is admin for an org-scoped or project-scoped resource.
/// Returns Ok(#(org_id, project_id)) on success for use in subsequent operations.
pub fn require_scoped_admin(
  db: pog.Connection,
  user: StoredUser,
  org_id: Int,
  project_id: Option(Int),
) -> Result(#(Int, Option(Int)), wisp.Response) {
  case project_id {
    None ->
      case user.org_role {
        Admin -> Ok(#(org_id, project_id))
        _ -> Error(api.error(403, "FORBIDDEN", "Forbidden"))
      }

    Some(pid) ->
      case projects_db.is_project_admin(db, pid, user.id) {
        Ok(True) -> Ok(#(org_id, project_id))
        Ok(False) -> Error(api.error(403, "FORBIDDEN", "Forbidden"))
        Error(_) -> Error(api.error(500, "INTERNAL", "Database error"))
      }
  }
}

/// Require user is admin for an org-scoped or project-scoped resource.
/// Returns Ok(Nil) on success.
pub fn require_scoped_admin_simple(
  db: pog.Connection,
  user: StoredUser,
  org_id: Int,
  project_id: Option(Int),
) -> Result(Nil, wisp.Response) {
  case require_scoped_admin(db, user, org_id, project_id) {
    Ok(_) -> Ok(Nil)
    Error(e) -> Error(e)
  }
}

/// Require user is admin for an org-scoped or project-scoped resource.
/// Org admins always have access regardless of project assignment.
pub fn require_scoped_admin_with_org_bypass(
  db: pog.Connection,
  user: StoredUser,
  project_id: Option(Int),
) -> Result(Nil, wisp.Response) {
  case project_id {
    None ->
      case user.org_role {
        Admin -> Ok(Nil)
        _ -> Error(api.error(403, "FORBIDDEN", "Admin role required"))
      }

    Some(pid) ->
      case user.org_role {
        Admin -> Ok(Nil)
        _ ->
          case projects_db.is_project_admin(db, user.id, pid) {
            Ok(True) -> Ok(Nil)
            _ -> Error(api.error(403, "FORBIDDEN", "Admin role required"))
          }
      }
  }
}
