//// HTTP authorization helpers for scoped resources.
////
//// Provides authorization checks for project-scoped resources.
//// Note: All resources are now project-scoped (no org-scoped workflows/templates).

import pog
import scrumbringer_server/services/authorization
import scrumbringer_server/services/store_state.{type StoredUser}
import wisp

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
  authorization.require_project_manager(db, user, org_id, project_id)
}

/// Require user is manager for a project-scoped resource.
/// Returns Ok(Nil) on success.
pub fn require_project_manager_simple(
  db: pog.Connection,
  user: StoredUser,
  org_id: Int,
  project_id: Int,
) -> Result(Nil, wisp.Response) {
  authorization.require_project_manager_simple(db, user, org_id, project_id)
}

/// Require user is manager for a project-scoped resource.
/// Org admins always have access regardless of project assignment.
pub fn require_project_manager_with_org_bypass(
  db: pog.Connection,
  user: StoredUser,
  project_id: Int,
) -> Result(Nil, wisp.Response) {
  authorization.require_project_manager_with_org_bypass(db, user, project_id)
}
