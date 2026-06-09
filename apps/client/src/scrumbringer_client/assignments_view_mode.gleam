////
//// Assignments view mode helpers.
////

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

pub fn parse(raw: String) -> Result(AssignmentsViewMode, Nil) {
  case raw {
    "projects" -> Ok(ByProject)
    "users" -> Ok(ByUser)
    _ -> Error(Nil)
  }
}
