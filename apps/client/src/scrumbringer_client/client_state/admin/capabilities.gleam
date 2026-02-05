//// Capability admin state.

import gleam/dict.{type Dict}
import gleam/option.{type Option}

import domain/capability.{type Capability}
import domain/remote.{type Remote, NotAsked}
import scrumbringer_client/client_state/dialog_mode

/// Represents capabilities admin state.
pub type Model {
  Model(
    capabilities: Remote(List(Capability)),
    capabilities_dialog_mode: dialog_mode.DialogMode,
    capabilities_create_name: String,
    capabilities_create_in_flight: Bool,
    capabilities_create_error: Option(String),
    capability_delete_dialog_id: Option(Int),
    capability_delete_in_flight: Bool,
    capability_delete_error: Option(String),
    member_capabilities_dialog_user_id: Option(Int),
    member_capabilities_loading: Bool,
    member_capabilities_saving: Bool,
    member_capabilities_cache: Dict(Int, List(Int)),
    member_capabilities_selected: List(Int),
    member_capabilities_error: Option(String),
    capability_members_dialog_capability_id: Option(Int),
    capability_members_loading: Bool,
    capability_members_saving: Bool,
    capability_members_cache: Dict(Int, List(Int)),
    capability_members_selected: List(Int),
    capability_members_error: Option(String),
  )
}

/// Provides default capabilities admin state.
pub fn default_model() -> Model {
  Model(
    capabilities: NotAsked,
    capabilities_dialog_mode: dialog_mode.DialogClosed,
    capabilities_create_name: "",
    capabilities_create_in_flight: False,
    capabilities_create_error: option.None,
    capability_delete_dialog_id: option.None,
    capability_delete_in_flight: False,
    capability_delete_error: option.None,
    member_capabilities_dialog_user_id: option.None,
    member_capabilities_loading: False,
    member_capabilities_saving: False,
    member_capabilities_cache: dict.new(),
    member_capabilities_selected: [],
    member_capabilities_error: option.None,
    capability_members_dialog_capability_id: option.None,
    capability_members_loading: False,
    capability_members_saving: False,
    capability_members_cache: dict.new(),
    capability_members_selected: [],
    capability_members_error: option.None,
  )
}
