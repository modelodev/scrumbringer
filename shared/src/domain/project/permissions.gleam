//// Typed project privileges for sensitive domain mutations.

import domain/project/id as project_id
import domain/user/id as user_id

pub type ManageFlow {
  ManageFlow
}

pub opaque type Authorized(privilege) {
  Authorized(user_id: user_id.UserId, project_id: project_id.ProjectId)
}

pub fn authorize_manage_flow_unchecked(
  user_id: user_id.UserId,
  project_id: project_id.ProjectId,
) -> Authorized(ManageFlow) {
  Authorized(user_id: user_id, project_id: project_id)
}

pub fn user_id(auth: Authorized(privilege)) -> user_id.UserId {
  let Authorized(user_id: user_id, ..) = auth
  user_id
}

pub fn project_id(auth: Authorized(privilege)) -> project_id.ProjectId {
  let Authorized(project_id: project_id, ..) = auth
  project_id
}
