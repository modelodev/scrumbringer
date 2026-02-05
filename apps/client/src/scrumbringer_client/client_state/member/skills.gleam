//// Member skills state.

import gleam/dict.{type Dict}
import gleam/option.{type Option}

import domain/capability.{type Capability}
import domain/remote.{type Remote, NotAsked}

/// Represents member skills state.
pub type Model {
  Model(
    member_capabilities: Remote(List(Capability)),
    member_my_capability_ids: Remote(List(Int)),
    member_my_capability_ids_edit: Dict(Int, Bool),
    member_my_capabilities_in_flight: Bool,
    member_my_capabilities_error: Option(String),
  )
}

/// Provides default member skills state.
pub fn default_model() -> Model {
  Model(
    member_capabilities: NotAsked,
    member_my_capability_ids: NotAsked,
    member_my_capability_ids_edit: dict.new(),
    member_my_capabilities_in_flight: False,
    member_my_capabilities_error: option.None,
  )
}
