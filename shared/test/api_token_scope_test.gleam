import domain/api_token_scope

pub fn parse_accepts_supported_scope_test() {
  let assert Ok(api_token_scope.TasksWrite) =
    api_token_scope.parse("tasks:write")
}

pub fn parse_rejects_unsupported_project_write_test() {
  let assert Error(api_token_scope.InvalidScope("projects:write")) =
    api_token_scope.parse("projects:write")
}

pub fn parse_rejects_unknown_resource_test() {
  let assert Error(api_token_scope.InvalidScope("workflows:read")) =
    api_token_scope.parse("workflows:read")
}

pub fn to_string_roundtrips_supported_scope_test() {
  let assert Ok(scope) = api_token_scope.parse("milestones:read")
  let assert "milestones:read" = api_token_scope.to_string(scope)
}

pub fn from_parts_rejects_unsupported_project_write_test() {
  let assert Error(api_token_scope.InvalidScope("projects:write")) =
    api_token_scope.from_parts(api_token_scope.Projects, api_token_scope.Write)
}
