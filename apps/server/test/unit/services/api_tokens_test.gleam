import domain/api_token_scope
import gleam/string
import scrumbringer_server/use_case/api_tokens
import support/assertions as expect

pub fn parse_scope_accepts_known_resources_and_access_test() {
  let assert Ok(scope) = api_tokens.parse_scope("tasks:write")

  scope
  |> expect.equal(api_token_scope.TasksWrite)
}

pub fn parse_scope_rejects_unsupported_project_write_test() {
  api_tokens.parse_scope("projects:write")
  |> expect.equal(Error(api_tokens.InvalidScope("projects:write")))
}

pub fn supported_scope_strings_match_public_contract_test() {
  api_tokens.supported_scope_strings()
  |> expect.equal([
    "projects:read",
    "tasks:read",
    "tasks:write",
    "cards:read",
    "cards:write",
    "card_trees:read",
    "notes:read",
    "notes:write",
  ])
}

pub fn parse_scope_rejects_unknown_resource_test() {
  api_tokens.parse_scope("workflows:read")
  |> expect.equal(Error(api_tokens.InvalidScope("workflows:read")))
}

pub fn parse_scope_rejects_unknown_access_test() {
  api_tokens.parse_scope("tasks:admin")
  |> expect.equal(Error(api_tokens.InvalidScope("tasks:admin")))
}

pub fn scope_to_string_returns_wire_value_test() {
  api_token_scope.CardsRead
  |> api_tokens.scope_to_string
  |> expect.equal("cards:read")
}

pub fn public_id_from_bearer_extracts_public_id_test() {
  api_tokens.public_id_from_bearer("sbt_public_secret")
  |> expect.equal(Ok("public"))
}

pub fn public_id_from_bearer_rejects_invalid_prefix_test() {
  api_tokens.public_id_from_bearer("bad_public_secret")
  |> expect.equal(Error(api_tokens.InvalidBearer))
}

pub fn hash_token_does_not_contain_secret_test() {
  let hash = api_tokens.hash_token("sbt_public_supersecret")

  let assert False = hash == "sbt_public_supersecret"
  let assert False = string.contains(hash, "supersecret")
}
