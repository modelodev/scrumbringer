import gleam/dict
import gleam/int
import gleam/option as opt
import lustre/element
import support/render_assertions

import domain/capability.{type Capability, Capability}
import domain/org.{type OrgUser, OrgUser}
import domain/org_role
import domain/project.{type ProjectMember, ProjectMember}
import domain/project_role
import domain/remote.{Loaded}
import scrumbringer_client/client_state/admin/capabilities as admin_capabilities
import scrumbringer_client/client_state/admin/members as admin_members
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/features/admin/capabilities_view
import scrumbringer_client/i18n/locale

fn capability(id: Int, name: String) -> Capability {
  Capability(id: id, name: name)
}

fn project_member(user_id: Int) -> ProjectMember {
  ProjectMember(
    user_id: user_id,
    role: project_role.Member,
    created_at: "2026-02-06T00:00:00Z",
    claimed_count: 0,
  )
}

fn org_user(id: Int, email: String) -> OrgUser {
  OrgUser(
    id: id,
    email: email,
    org_role: org_role.Member,
    created_at: "2026-02-06T00:00:00Z",
  )
}

fn config(
  capabilities: admin_capabilities.Model,
  members: admin_members.Model,
) -> capabilities_view.Config(String) {
  capabilities_view.Config(
    locale: locale.En,
    capabilities: capabilities,
    members: members,
    selected_project_name: "Roadmap",
    on_create_opened: "create-opened",
    on_create_closed: "create-closed",
    on_create_name_changed: fn(value) { "name:" <> value },
    on_create_submitted: "create-submitted",
    on_edit_opened: fn(id, name) { "edit:" <> int.to_string(id) <> ":" <> name },
    on_edit_closed: "edit-closed",
    on_edit_name_changed: fn(value) { "edit-name:" <> value },
    on_edit_submitted: "edit-submitted",
    on_delete_opened: fn(id) { "delete:" <> int.to_string(id) },
    on_delete_closed: "delete-closed",
    on_delete_submitted: "delete-submitted",
    on_members_opened: fn(id) { "members:" <> int.to_string(id) },
    on_members_closed: "members-closed",
    on_member_toggled: fn(id) { "toggle:" <> int.to_string(id) },
    on_members_save_clicked: "members-save",
  )
}

pub fn capabilities_view_renders_list_from_config_without_root_model_test() {
  let member_counts =
    dict.new()
    |> dict.insert(1, [10, 11])

  let capabilities =
    admin_capabilities.Model(
      ..admin_capabilities.default_model(),
      capabilities: Loaded([capability(1, "Backend")]),
      capability_members_cache: member_counts,
    )

  let html =
    capabilities_view.view(config(capabilities, admin_members.default_model()))
    |> element.to_document_string

  render_assertions.contains(html, "Capabilities")
  render_assertions.contains(html, "Create Capability")
  render_assertions.contains(html, "Backend")
  render_assertions.contains(html, "capability-members-btn")
  render_assertions.contains(html, "capability-delete-btn")
  render_assertions.contains(html, ">2<")
}

pub fn capabilities_view_renders_members_dialog_from_config_without_root_model_test() {
  let capabilities =
    admin_capabilities.Model(
      ..admin_capabilities.default_model(),
      capabilities: Loaded([capability(1, "Backend")]),
      capability_members_dialog_capability_id: opt.Some(1),
      capability_members_selected: [10],
    )

  let members =
    admin_members.Model(
      ..admin_members.default_model(),
      members: Loaded([project_member(10), project_member(11)]),
      org_users_cache: Loaded([
        org_user(10, "alice@example.com"),
        org_user(11, "bob@example.com"),
      ]),
    )

  let html =
    capabilities_view.view(config(capabilities, members))
    |> element.to_document_string

  render_assertions.contains(html, "Members with Backend in Roadmap")
  render_assertions.contains(html, "data-testid=\"members-checklist\"")
  render_assertions.contains(html, "alice@example.com")
  render_assertions.contains(html, "bob@example.com")
  render_assertions.contains(html, "btn-primary")
  render_assertions.contains(html, "btn-entity-action")
  render_assertions.not_contains(html, "class=\"btn-primary\"")
}

pub fn capabilities_view_delete_dialog_uses_shared_danger_button_test() {
  let capabilities =
    admin_capabilities.Model(
      ..admin_capabilities.default_model(),
      capabilities: Loaded([capability(1, "Backend")]),
      capability_delete_dialog_id: opt.Some(1),
      capability_delete_in_flight: True,
    )

  let html =
    capabilities_view.view(config(capabilities, admin_members.default_model()))
    |> element.to_document_string

  render_assertions.contains(html, "Delete Capability")
  render_assertions.contains(html, "Deleting")
  render_assertions.contains(html, "btn-danger")
  render_assertions.contains(html, "btn-entity-action")
}

pub fn capabilities_view_renders_create_dialog_from_config_without_root_model_test() {
  let capabilities =
    admin_capabilities.Model(
      ..admin_capabilities.default_model(),
      capabilities_dialog_mode: dialog_mode.DialogCreate,
      capabilities_create_name: "Frontend",
      capabilities_create_in_flight: True,
    )

  let html =
    capabilities_view.view(config(capabilities, admin_members.default_model()))
    |> element.to_document_string

  render_assertions.contains(html, "capability-create-form")
  render_assertions.contains(html, "Frontend")
  render_assertions.contains(html, "Creating")
}
