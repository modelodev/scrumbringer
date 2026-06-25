import gleam/option

import domain/card/entity as card_entity
import domain/card/id as card_id
import domain/card/state as card_state
import domain/card/structure as card_structure
import domain/org_role
import domain/project/id as project_id
import domain/project/permissions
import domain/project_role
import domain/task/creation as task_creation
import domain/task/id as task_id
import domain/task/placement
import domain/user/id as user_id

pub fn project_manager_gets_manage_flow_test() {
  let actor = manager_actor()

  let assert Ok(auth) =
    permissions.require_manage_flow(actor, project_id.new(1))
  let assert True = permissions.user_id(auth) == user_id.new(7)
  let assert True = permissions.project_id(auth) == project_id.new(1)
}

pub fn project_member_does_not_get_manage_flow_test() {
  let actor = member_actor()

  let assert Error(permissions.InsufficientProjectPrivilege) =
    permissions.require_manage_flow(actor, project_id.new(1))
}

pub fn project_member_gets_execute_work_test() {
  let actor = member_actor()

  let assert Ok(auth) =
    permissions.require_execute_work(actor, project_id.new(1))
  let assert True = permissions.user_id(auth) == user_id.new(7)
}

pub fn activate_card_requires_manage_flow_test() {
  let actor = manager_actor()
  let assert Ok(auth) =
    permissions.require_manage_flow(actor, project_id.new(1))

  let assert True = permissions.project_id(auth) == project_id.new(1)
}

pub fn create_root_pool_task_requires_manage_flow_test() {
  let assert Ok(auth) =
    permissions.require_manage_flow(manager_actor(), project_id.new(1))

  let task = task_creation.create_root_pool_task(task_id.new(1), auth)

  let assert placement.RootPool = task.placement
}

pub fn create_task_in_draft_card_requires_manage_flow_test() {
  let card = draft_card()
  let assert Ok(auth) =
    permissions.require_manage_flow(manager_actor(), project_id.new(1))

  let assert Ok(task) =
    task_creation.create_task_in_draft_card(task_id.new(1), card, auth)
  let assert True = task.placement == placement.UnderCard(card_id.new(1))
}

pub fn create_task_in_active_task_group_requires_execute_work_test() {
  let card =
    card_entity.Card(
      ..draft_card(),
      execution_state: card_state.Active(
        activated_at: "2026-06-19T10:00:00Z",
        activated_by: user_id.new(7),
        source: card_state.DirectActivation,
      ),
    )
  let assert Ok(auth) =
    permissions.require_execute_work(member_actor(), project_id.new(1))

  let assert Ok(task) =
    task_creation.create_task_in_active_task_group(task_id.new(1), card, auth)
  let assert True = task.placement == placement.UnderCard(card_id.new(1))
}

pub fn move_card_requires_manage_structure_test() {
  let root = draft_card()
  let child =
    card_entity.Card(..draft_card(), id: card_id.new(2), parent: option.None)
  let hierarchy = card_entity.CardHierarchy([root, child])
  let assert Ok(auth) =
    permissions.require_manage_structure(manager_actor(), project_id.new(1))

  let assert Ok(moved) =
    card_entity.move_card_to_parent(
      child,
      auth,
      option.Some(card_id.new(1)),
      hierarchy,
    )
  let assert True = moved.parent == option.Some(card_id.new(1))
}

pub fn user_outside_project_gets_no_project_privileges_test() {
  let actor = outside_actor()

  let assert Error(permissions.NotProjectMember) =
    permissions.require_manage_flow(actor, project_id.new(1))
  let assert Error(permissions.NotProjectMember) =
    permissions.require_manage_structure(actor, project_id.new(1))
  let assert Error(permissions.NotProjectMember) =
    permissions.require_execute_work(actor, project_id.new(1))
}

pub fn cross_project_authorization_returns_not_project_member_test() {
  let actor = outside_actor()

  let assert Error(permissions.NotProjectMember) =
    permissions.require_manage_flow(actor, project_id.new(1))
}

fn manager_actor() -> permissions.ProjectActor {
  permissions.project_actor(
    user_id.new(7),
    project_id.new(1),
    org_role.Member,
    option.Some(project_role.Manager),
  )
}

fn member_actor() -> permissions.ProjectActor {
  permissions.project_actor(
    user_id.new(7),
    project_id.new(1),
    org_role.Member,
    option.Some(project_role.Member),
  )
}

fn outside_actor() -> permissions.ProjectActor {
  permissions.project_actor(
    user_id.new(7),
    project_id.new(2),
    org_role.Member,
    option.None,
  )
}

fn draft_card() -> card_entity.Card {
  card_entity.Card(
    id: card_id.new(1),
    project_id: project_id.new(1),
    parent: option.None,
    structure: card_structure.Empty,
    execution_state: card_state.Draft,
  )
}
