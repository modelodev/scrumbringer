////
//// Assignments view mode helpers.
////

import gleam/option

pub type AssignmentsViewMode {
  ByProject
  ByUser
}

pub fn to_param(mode: AssignmentsViewMode) -> String {
  case mode {
    ByProject -> "projects"
    ByUser -> "users"
  }
}

pub fn from_param(raw: String) -> option.Option(AssignmentsViewMode) {
  case raw {
    "projects" -> option.Some(ByProject)
    "users" -> option.Some(ByUser)
    _ -> option.None
  }
}
