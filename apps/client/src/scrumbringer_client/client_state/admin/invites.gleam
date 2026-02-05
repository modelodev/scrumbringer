//// Invite link state for admin flows.

import gleam/option.{type Option}

import domain/org.{type InviteLink}
import domain/remote.{type Remote, NotAsked}
import scrumbringer_client/client_state/types as state_types

/// Represents invite link admin state.
pub type Model {
  Model(
    invite_links: Remote(List(InviteLink)),
    invite_link_dialog: state_types.DialogState(state_types.InviteLinkForm),
    invite_link_last: Option(InviteLink),
    invite_link_copy_status: Option(String),
  )
}

/// Provides default invite state.
pub fn default_model() -> Model {
  Model(
    invite_links: NotAsked,
    invite_link_dialog: state_types.DialogClosed(operation: state_types.Idle),
    invite_link_last: option.None,
    invite_link_copy_status: option.None,
  )
}
