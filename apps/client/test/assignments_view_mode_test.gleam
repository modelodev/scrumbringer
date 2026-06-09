import scrumbringer_client/assignments_view_mode

pub fn parse_projects_test() {
  let assert Ok(assignments_view_mode.ByProject) =
    assignments_view_mode.parse("projects")
}

pub fn parse_users_test() {
  let assert Ok(assignments_view_mode.ByUser) =
    assignments_view_mode.parse("users")
}

pub fn parse_rejects_unknown_test() {
  let assert Error(Nil) = assignments_view_mode.parse("unknown")
}
