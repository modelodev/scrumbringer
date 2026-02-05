//// Assignments admin state.

import gleam/dict
import gleam/option
import gleam/set

import domain/project_role
import scrumbringer_client/assignments_view_mode
import scrumbringer_client/client_state/types as state_types

/// Represents assignments admin state.
pub type Model =
  state_types.AssignmentsModel

/// Provides default assignments admin state.
pub fn default_model() -> Model {
  state_types.AssignmentsModel(
    view_mode: assignments_view_mode.ByProject,
    search_input: "",
    search_query: "",
    project_members: dict.new(),
    user_projects: dict.new(),
    expanded_projects: set.new(),
    expanded_users: set.new(),
    inline_add_context: option.None,
    inline_add_selection: option.None,
    inline_add_search: "",
    inline_add_role: project_role.Member,
    inline_add_in_flight: False,
    inline_remove_confirm: option.None,
    role_change_in_flight: option.None,
    role_change_previous: option.None,
  )
}
