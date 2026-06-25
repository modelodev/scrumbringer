//// Typed project privileges for sensitive domain mutations.

import domain/org_role
import domain/project/id as project_id
import domain/project_role
import domain/user/id as user_id
import gleam/option.{type Option, Some}
import gleam/result

/// ManageFlow allows changing what work is available to the team:
/// activating cards, closing branches, and releasing tasks to the Pool.
pub type ManageFlow {
  ManageFlow
}

/// ManageStructure allows changing the work tree:
/// creating cards, moving cards, configuring levels, and editing hierarchy.
pub type ManageStructure {
  ManageStructure
}

/// ManageCatalog allows changing project taxonomies such as task types,
/// capabilities, workflow templates, and card level profiles.
pub type ManageCatalog {
  ManageCatalog
}

/// ExecuteWork allows participating in pull execution:
/// seeing the Pool, claiming, releasing, completing tasks, and creating
/// operational tasks inside active task groups.
pub type ExecuteWork {
  ExecuteWork
}

/// ReadHistory allows reading audit trails, execution history, and rollups.
pub type ReadHistory {
  ReadHistory
}

pub opaque type Authorized(privilege) {
  Authorized(user_id: user_id.UserId, project_id: project_id.ProjectId)
}

pub type ProjectActor {
  ProjectActor(
    user_id: user_id.UserId,
    project_id: project_id.ProjectId,
    org_role: org_role.OrgRole,
    project_role: Option(project_role.ProjectRole),
  )
}

pub type AuthorizationError {
  NotProjectMember
  InsufficientProjectPrivilege
}

pub fn project_actor(
  user_id: user_id.UserId,
  project_id: project_id.ProjectId,
  org_role: org_role.OrgRole,
  project_role: Option(project_role.ProjectRole),
) -> ProjectActor {
  ProjectActor(
    user_id: user_id,
    project_id: project_id,
    org_role: org_role,
    project_role: project_role,
  )
}

pub fn require_manage_flow(
  actor: ProjectActor,
  project_id: project_id.ProjectId,
) -> Result(Authorized(ManageFlow), AuthorizationError) {
  require_manager_privilege(actor, project_id)
}

pub fn require_manage_structure(
  actor: ProjectActor,
  project_id: project_id.ProjectId,
) -> Result(Authorized(ManageStructure), AuthorizationError) {
  require_manager_privilege(actor, project_id)
}

pub fn require_manage_catalog(
  actor: ProjectActor,
  project_id: project_id.ProjectId,
) -> Result(Authorized(ManageCatalog), AuthorizationError) {
  require_manager_privilege(actor, project_id)
}

pub fn require_execute_work(
  actor: ProjectActor,
  project_id: project_id.ProjectId,
) -> Result(Authorized(ExecuteWork), AuthorizationError) {
  require_member_privilege(actor, project_id)
}

pub fn require_read_history(
  actor: ProjectActor,
  project_id: project_id.ProjectId,
) -> Result(Authorized(ReadHistory), AuthorizationError) {
  require_member_privilege(actor, project_id)
}

pub fn user_id(auth: Authorized(privilege)) -> user_id.UserId {
  let Authorized(user_id: user_id, ..) = auth
  user_id
}

pub fn project_id(auth: Authorized(privilege)) -> project_id.ProjectId {
  let Authorized(project_id: project_id, ..) = auth
  project_id
}

fn require_manager_privilege(
  actor: ProjectActor,
  target_project_id: project_id.ProjectId,
) -> Result(Authorized(privilege), AuthorizationError) {
  use Nil <- result.try(require_project_member(actor, target_project_id))

  case actor_allows_management(actor) {
    True -> Ok(actor_authorized(actor))
    False -> Error(InsufficientProjectPrivilege)
  }
}

fn require_member_privilege(
  actor: ProjectActor,
  target_project_id: project_id.ProjectId,
) -> Result(Authorized(privilege), AuthorizationError) {
  use Nil <- result.try(require_project_member(actor, target_project_id))
  Ok(actor_authorized(actor))
}

fn require_project_member(
  actor: ProjectActor,
  target_project_id: project_id.ProjectId,
) -> Result(Nil, AuthorizationError) {
  let ProjectActor(project_id: actor_project_id, project_role: role, ..) = actor
  case actor_project_id == target_project_id, role {
    True, Some(_) -> Ok(Nil)
    _, _ -> Error(NotProjectMember)
  }
}

fn actor_allows_management(actor: ProjectActor) -> Bool {
  let ProjectActor(org_role: org, project_role: role, ..) = actor
  case org, role {
    org_role.Admin, Some(_) -> True
    _, Some(project_role.Manager) -> True
    _, _ -> False
  }
}

fn actor_authorized(actor: ProjectActor) -> Authorized(privilege) {
  let ProjectActor(user_id: user_id, project_id: project_id, ..) = actor
  Authorized(user_id: user_id, project_id: project_id)
}
