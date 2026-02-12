import domain/org.{type OrgUser, OrgUser}
import domain/org_role
import domain/project.{type Project, Project}
import domain/project_role
import gleam/option as opt
import gleam/string
import gleeunit/should
import lustre/effect
import lustre/element

import scrumbringer_client/client_state
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/admin/members as admin_members
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/client_state/types as state_types
import scrumbringer_client/features/admin/member_add
import scrumbringer_client/features/admin/search
import scrumbringer_client/features/admin/views/members

fn sample_user(id: Int, email: String) -> OrgUser {
  OrgUser(
    id: id,
    email: email,
    org_role: org_role.Member,
    created_at: "2026-01-01T00:00:00Z",
  )
}

fn sample_project() -> Project {
  Project(
    id: 8,
    name: "Proyecto Alpha",
    my_role: project_role.Manager,
    created_at: "2026-01-01T00:00:00Z",
    members_count: 1,
  )
}

fn base_model() -> client_state.Model {
  client_state.default_model()
  |> client_state.update_core(fn(core) {
    client_state.CoreModel(..core, selected_project_id: opt.Some(8))
  })
}

fn with_members_state(
  model: client_state.Model,
  f: fn(admin_members.Model) -> admin_members.Model,
) -> client_state.Model {
  client_state.update_admin(model, fn(admin) {
    admin_state.AdminModel(..admin, members: f(admin.members))
  })
}

pub fn org_users_search_exact_email_auto_selects_user_test() {
  let model =
    base_model()
    |> with_members_state(fn(members_state) {
      admin_members.Model(
        ..members_state,
        org_users_search: state_types.OrgUsersSearchLoading("qa@example.com", 2),
      )
    })

  let users = [
    sample_user(3, "member@example.com"),
    sample_user(9, "qa@example.com"),
  ]

  let #(next, _fx) = search.handle_org_users_search_results_ok(model, 2, users)

  let is_selected = case next.admin.members.members_add_selected_user {
    opt.Some(user) -> user.id == 9 && user.email == "qa@example.com"
    opt.None -> False
  }

  is_selected |> should.be_true
}

pub fn org_users_search_without_exact_match_clears_selection_test() {
  let model =
    base_model()
    |> with_members_state(fn(members_state) {
      admin_members.Model(
        ..members_state,
        members_add_selected_user: opt.Some(sample_user(9, "qa@example.com")),
        org_users_search: state_types.OrgUsersSearchLoading("qa@example.com", 3),
      )
    })

  let users = [
    sample_user(3, "member@example.com"),
    sample_user(4, "pm@example.com"),
  ]

  let #(next, _fx) = search.handle_org_users_search_results_ok(model, 3, users)

  next.admin.members.members_add_selected_user |> should.equal(opt.None)
}

pub fn submit_without_selected_user_keeps_add_disabled_state_test() {
  let model =
    base_model()
    |> with_members_state(fn(members_state) {
      admin_members.Model(..members_state, members_add_selected_user: opt.None)
    })

  let #(next, fx) = member_add.handle_member_add_submitted(model)

  next.admin.members.members_add_in_flight |> should.equal(False)
  next.admin.members.members_add_error |> should.not_equal(opt.None)
  fx |> should.equal(effect.none())
}

pub fn members_dialog_shows_selected_user_feedback_test() {
  let model =
    base_model()
    |> with_members_state(fn(members_state) {
      admin_members.Model(
        ..members_state,
        members_add_dialog_mode: dialog_mode.DialogCreate,
        members_add_selected_user: opt.Some(sample_user(9, "qa@example.com")),
      )
    })

  let rendered = members.view_members(model, opt.Some(sample_project()))
  let html = element.to_document_string(rendered)

  string.contains(html, "member-add-selected-user") |> should.be_true
  string.contains(html, "qa@example.com") |> should.be_true
}

pub fn members_dialog_shows_no_results_feedback_for_full_email_test() {
  let model =
    base_model()
    |> with_members_state(fn(members_state) {
      admin_members.Model(
        ..members_state,
        members_add_dialog_mode: dialog_mode.DialogCreate,
        org_users_search: state_types.OrgUsersSearchLoaded(
          "qa@example.com",
          4,
          [],
        ),
      )
    })

  let rendered = members.view_members(model, opt.Some(sample_project()))
  let html = element.to_document_string(rendered)

  let has_no_results =
    string.contains(html, "Sin resultados")
    || string.contains(html, "No results")

  has_no_results |> should.be_true
}
