import gleam/option as opt
import gleam/string
import gleeunit/should
import lustre/element

import domain/org_role
import domain/user.{User}
import scrumbringer_client/client_state.{
  type Model, Admin, CoreModel, default_model, update_core,
}
import scrumbringer_client/client_view
import scrumbringer_client/permissions

fn base_model() -> Model {
  default_model()
}

pub fn admin_page_without_user_shows_login_test() {
  let model =
    update_core(base_model(), fn(core) {
      CoreModel(..core, page: Admin, user: opt.None)
    })

  let html = client_view.view(model) |> element.to_document_string

  string.contains(html, "login-email") |> should.be_true
}

pub fn admin_section_without_permission_shows_not_permitted_test() {
  let model =
    update_core(base_model(), fn(core) {
      CoreModel(
        ..core,
        page: Admin,
        active_section: permissions.Invites,
        user: opt.Some(User(
          id: 1,
          email: "member@example.com",
          org_id: 1,
          org_role: org_role.Member,
          created_at: "2026-01-01T00:00:00Z",
        )),
      )
    })

  let html = client_view.view(model) |> element.to_document_string

  string.contains(html, "not-permitted") |> should.be_true
}
