//// Assignments admin state.

import gleam/dict.{type Dict}
import gleam/option.{type Option}
import gleam/set.{type Set}

import domain/project.{type Project, type ProjectMember}
import domain/project_role.{type ProjectRole, Member}
import domain/remote.{type Remote}
import scrumbringer_client/assignments_view_mode

/// Inline add context for assignments.
pub type AssignmentsAddContext {
  AddUserToProject(project_id: Int)
  AddProjectToUser(user_id: Int)
}

/// Assignments UI state.
pub type AssignmentsModel {
  AssignmentsModel(
    view_mode: assignments_view_mode.AssignmentsViewMode,
    search_input: String,
    search_query: String,
    project_members: Dict(Int, Remote(List(ProjectMember))),
    user_projects: Dict(Int, Remote(List(Project))),
    expanded_projects: Set(Int),
    expanded_users: Set(Int),
    inline_add_context: Option(AssignmentsAddContext),
    inline_add_selection: Option(Int),
    inline_add_search: String,
    inline_add_role: ProjectRole,
    inline_add_in_flight: Bool,
    inline_remove_confirm: Option(#(Int, Int)),
    role_change_in_flight: Option(#(Int, Int)),
    role_change_previous: Option(#(Int, Int, ProjectRole)),
  )
}

pub type Model =
  AssignmentsModel

/// Provides default assignments admin state.
pub fn default_model() -> Model {
  AssignmentsModel(
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
    inline_add_role: Member,
    inline_add_in_flight: False,
    inline_remove_confirm: option.None,
    role_change_in_flight: option.None,
    role_change_previous: option.None,
  )
}
