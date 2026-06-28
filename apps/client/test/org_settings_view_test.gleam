import gleam/int
import gleam/option as opt
import lustre/element
import support/domain_fixtures
import support/render_assertions

import domain/org.{OrgUser}
import domain/org_role
import domain/remote.{Loaded}
import scrumbringer_client/client_state/admin/members as admin_members
import scrumbringer_client/features/admin/org_settings_view
import scrumbringer_client/i18n/locale

fn user(id: Int, email: String, role: org_role.OrgRole) {
  OrgUser(..domain_fixtures.org_user(id, email), org_role: role)
}

fn config(model: admin_members.Model) -> org_settings_view.Config(String) {
  org_settings_view.Config(
    locale: locale.En,
    model: model,
    current_user_id: opt.Some(1),
    on_role_changed: fn(id, _) { "role:" <> int.to_string(id) },
    on_invalid_role: "invalid-role",
    on_delete_clicked: fn(id) { "delete:" <> int.to_string(id) },
    on_delete_cancelled: "cancel-delete",
    on_delete_confirmed: "confirm-delete",
  )
}

pub fn org_settings_view_renders_table_from_config_without_root_model_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      org_settings_users: Loaded([
        user(1, "admin@example.com", org_role.Admin),
        user(2, "member@example.com", org_role.Member),
      ]),
    )

  let html =
    org_settings_view.view(config(model))
    |> element.to_document_string

  render_assertions.contains(html, "Users")
  render_assertions.contains(html, "Manage org roles")
  render_assertions.contains(html, "admin@example.com")
  render_assertions.contains(html, "member@example.com")
  render_assertions.contains(html, "data-testid=\"org-user-delete-btn\"")
  render_assertions.contains(html, "btn-danger-icon")
  render_assertions.contains(html, "btn-entity-action")
  render_assertions.contains(html, "btn-delete-blocked")
  render_assertions.contains(
    html,
    "data-tooltip=\"Cannot delete your own user\"",
  )
  render_assertions.contains(html, "aria-disabled=\"true\"")
}

pub fn org_settings_view_renders_delete_dialog_from_config_without_root_model_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      org_settings_users: Loaded([
        user(2, "member@example.com", org_role.Member),
      ]),
      org_settings_delete_confirm: opt.Some(user(
        2,
        "member@example.com",
        org_role.Member,
      )),
      org_settings_delete_in_flight: True,
    )

  let html =
    org_settings_view.view(config(model))
    |> element.to_document_string

  render_assertions.contains(html, "Delete user")
  render_assertions.contains(html, "member@example.com")
  render_assertions.contains(html, "Deleting")
  render_assertions.contains(html, "btn-danger")
  render_assertions.contains(html, "btn-entity-action")
}
