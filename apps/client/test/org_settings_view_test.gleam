import gleam/int
import gleam/option as opt
import gleam/string
import lustre/element

import domain/org.{OrgUser}
import domain/org_role
import domain/remote.{Loaded}
import scrumbringer_client/client_state/admin/members as admin_members
import scrumbringer_client/features/admin/org_settings_view
import scrumbringer_client/i18n/locale

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn user(id: Int, email: String, role: org_role.OrgRole) {
  OrgUser(
    id: id,
    email: email,
    org_role: role,
    created_at: "2026-02-06T00:00:00Z",
  )
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

  assert_contains(html, "Users")
  assert_contains(html, "Manage org roles")
  assert_contains(html, "admin@example.com")
  assert_contains(html, "member@example.com")
  assert_contains(html, "data-testid=\"org-user-delete-btn\"")
  assert_contains(html, "btn-danger-icon")
  assert_contains(html, "btn-entity-action")
  assert_contains(html, "disabled")
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

  assert_contains(html, "Delete user")
  assert_contains(html, "member@example.com")
  assert_contains(html, "Deleting")
  assert_contains(html, "btn-danger")
  assert_contains(html, "btn-entity-action")
}
