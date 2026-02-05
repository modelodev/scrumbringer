//// Member admin state (org users, project members, settings).

import gleam/option.{type Option}

import domain/org.{type OrgUser}
import domain/project.{type ProjectMember}
import domain/project_role.{type ProjectRole, Member}
import domain/remote.{type Remote, NotAsked}
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/client_state/types as state_types

/// Represents members admin state.
pub type Model {
  Model(
    members: Remote(List(ProjectMember)),
    members_project_id: Option(Int),
    org_users_cache: Remote(List(OrgUser)),
    org_settings_users: Remote(List(OrgUser)),
    org_settings_save_in_flight: Bool,
    org_settings_error: Option(String),
    org_settings_error_user_id: Option(Int),
    org_settings_delete_confirm: Option(OrgUser),
    org_settings_delete_in_flight: Bool,
    org_settings_delete_error: Option(String),
    members_add_dialog_mode: dialog_mode.DialogMode,
    members_add_selected_user: Option(OrgUser),
    members_add_role: ProjectRole,
    members_add_in_flight: Bool,
    members_add_error: Option(String),
    members_remove_confirm: Option(OrgUser),
    members_remove_in_flight: Bool,
    members_remove_error: Option(String),
    members_release_confirm: Option(state_types.ReleaseAllTarget),
    members_release_in_flight: Option(Int),
    members_release_error: Option(String),
    org_users_search: state_types.OrgUsersSearchState,
  )
}

/// Provides default members admin state.
pub fn default_model() -> Model {
  Model(
    members: NotAsked,
    members_project_id: option.None,
    org_users_cache: NotAsked,
    org_settings_users: NotAsked,
    org_settings_save_in_flight: False,
    org_settings_error: option.None,
    org_settings_error_user_id: option.None,
    org_settings_delete_confirm: option.None,
    org_settings_delete_in_flight: False,
    org_settings_delete_error: option.None,
    members_add_dialog_mode: dialog_mode.DialogClosed,
    members_add_selected_user: option.None,
    members_add_role: Member,
    members_add_in_flight: False,
    members_add_error: option.None,
    members_remove_confirm: option.None,
    members_remove_in_flight: False,
    members_remove_error: option.None,
    members_release_confirm: option.None,
    members_release_in_flight: option.None,
    members_release_error: option.None,
    org_users_search: state_types.OrgUsersSearchIdle("", 0),
  )
}
