import gleam/option as opt
import gleam/string
import lustre/element

import domain/org_role
import domain/user.{User}
import scrumbringer_client/client_state.{
  type Model, Admin, CoreModel, default_model, update_core, update_ui,
}
import scrumbringer_client/client_state/ui as ui_state
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

  let assert True = string.contains(html, "login-email")
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

  let assert True = string.contains(html, "not-permitted")
}

pub fn mobile_admin_team_uses_team_title_test() {
  let model =
    base_model()
    |> update_core(fn(core) {
      CoreModel(
        ..core,
        page: Admin,
        active_section: permissions.Team,
        user: opt.Some(User(
          id: 1,
          email: "admin@example.com",
          org_id: 1,
          org_role: org_role.Admin,
          created_at: "2026-01-01T00:00:00Z",
        )),
      )
    })
    |> update_ui(fn(ui) { ui_state.UiModel(..ui, is_mobile: True) })

  let html = client_view.view(model) |> element.to_document_string

  let assert True = string.contains(html, "topbar-title-mobile")
  let assert True = string.contains(html, "Team")
}
