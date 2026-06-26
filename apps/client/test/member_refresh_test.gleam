import gleam/dict
import gleam/option as opt

import domain/capability.{Capability}
import domain/org_role
import domain/project.{type Project, Project}
import domain/project_role
import domain/remote.{Loaded, Loading}
import domain/user.{type User, User}

import scrumbringer_client/capability_scope
import scrumbringer_client/client_state
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/admin/capabilities as admin_capabilities
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/client_state/member/skills as member_skills
import scrumbringer_client/client_update

fn base_member_model() -> client_state.Model {
  client_state.default_model()
  |> client_state.update_core(fn(core) {
    client_state.CoreModel(..core, page: client_state.Member)
  })
}

pub fn member_refresh_pool_fetches_org_users_cache_for_people_labels_test() {
  let model =
    base_member_model()
    |> client_state.update_core(fn(core) {
      client_state.CoreModel(..core, selected_project_id: opt.None)
    })

  let #(next, _fx) =
    client_update.update(model, client_state.ProjectSelected("2"))

  let assert Loading = next.admin.members.org_users_cache
}

pub fn project_change_reloads_project_scoped_capability_resources_test() {
  let model = model_with_loaded_project_scoped_capability_resources(opt.Some(1))

  let #(next, _fx) =
    client_update.update(model, client_state.ProjectSelected("2"))

  let assert opt.Some(2) = next.core.selected_project_id
  let assert Loading = next.admin.capabilities.capabilities
  let assert Loading = next.member.skills.member_my_capability_ids
  let assert Error(_) =
    dict.get(next.member.skills.member_my_capability_ids_edit, 11)
}

pub fn project_change_clears_project_scoped_member_filters_test() {
  let model =
    model_with_loaded_project_scoped_capability_resources(opt.Some(1))
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_filters_type_id: opt.Some(11),
          member_filters_capability_id: opt.Some(12),
          member_capability_scope: capability_scope.MyCapabilities,
          member_card_depth_filter: opt.Some(2),
          member_plan_scope_card_id: opt.Some(99),
          member_plan_scope_card_query: "old card",
          member_create_card_id: opt.Some(88),
          member_create_card_query: "old create",
        ),
      )
    })

  let #(next, _fx) =
    client_update.update(model, client_state.ProjectSelected("2"))

  let pool = next.member.pool
  let assert opt.None = pool.member_filters_type_id
  let assert opt.None = pool.member_filters_capability_id
  let assert capability_scope.AllCapabilities = pool.member_capability_scope
  let assert opt.None = pool.member_card_depth_filter
  let assert opt.None = pool.member_plan_scope_card_id
  let assert "" = pool.member_plan_scope_card_query
  let assert opt.None = pool.member_create_card_id
  let assert "" = pool.member_create_card_query
}

pub fn same_project_selection_keeps_project_scoped_capability_resources_test() {
  let model = model_with_loaded_project_scoped_capability_resources(opt.Some(2))

  let #(next, _fx) =
    client_update.update(model, client_state.ProjectSelected("2"))

  let assert opt.Some(2) = next.core.selected_project_id
  let assert Loaded([Capability(id: 11, name: "Backend")]) =
    next.admin.capabilities.capabilities
  let assert Loaded([11]) = next.member.skills.member_my_capability_ids
  let assert Ok(True) =
    dict.get(next.member.skills.member_my_capability_ids_edit, 11)
}

fn model_with_loaded_project_scoped_capability_resources(
  selected_project_id,
) -> client_state.Model {
  base_member_model()
  |> client_state.update_core(fn(core) {
    client_state.CoreModel(
      ..core,
      user: opt.Some(user()),
      auth_checked: True,
      projects: Loaded([project(1), project(2)]),
      selected_project_id: selected_project_id,
    )
  })
  |> with_loaded_project_scoped_capability_resources
}

fn with_loaded_project_scoped_capability_resources(
  model: client_state.Model,
) -> client_state.Model {
  model
  |> client_state.update_admin(fn(admin) {
    let capabilities = admin.capabilities
    admin_state.AdminModel(
      ..admin,
      capabilities: admin_capabilities.Model(
        ..capabilities,
        capabilities: Loaded([Capability(id: 11, name: "Backend")]),
      ),
    )
  })
  |> client_state.update_member(fn(member) {
    let skills = member.skills
    member_state.MemberModel(
      ..member,
      skills: member_skills.Model(
        ..skills,
        member_my_capability_ids: Loaded([11]),
        member_my_capability_ids_edit: dict.from_list([#(11, True)]),
      ),
    )
  })
}

fn user() -> User {
  User(
    id: 1,
    email: "admin@example.com",
    org_id: 1,
    org_role: org_role.Admin,
    created_at: "2026-01-01T00:00:00Z",
  )
}

fn project(id: Int) -> Project {
  Project(
    id: id,
    name: "Project",
    my_role: project_role.Manager,
    created_at: "2026-01-01T00:00:00Z",
    members_count: 1,
    card_depth_names: [],
    healthy_pool_limit: 5,
  )
}
