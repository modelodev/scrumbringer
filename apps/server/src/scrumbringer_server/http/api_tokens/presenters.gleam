import gleam/json
import helpers/json as json_helpers
import scrumbringer_server/services/api_tokens as token_service

pub fn tokens_response(tokens: List(token_service.ApiToken)) -> json.Json {
  json.object([#("api_tokens", json.array(tokens, of: token))])
}

pub fn created_token_response(created: token_service.CreatedToken) -> json.Json {
  let token_service.CreatedToken(token: api_token, bearer: bearer) = created

  json.object([
    #("api_token", token(api_token)),
    #("token", json.string(bearer)),
  ])
}

pub fn token_response(api_token: token_service.ApiToken) -> json.Json {
  json.object([#("api_token", token(api_token))])
}

pub fn token(api_token: token_service.ApiToken) -> json.Json {
  let token_service.ApiToken(
    id: id,
    org_id: org_id,
    integration_user_id: integration_user_id,
    project_id: project_id,
    name: name,
    public_id: public_id,
    scopes: scopes,
    created_at: created_at,
    last_used_at: last_used_at,
    expires_at: expires_at,
    revoked_at: revoked_at,
    expired: expired,
  ) = api_token

  json.object([
    #("id", json.int(id)),
    #("org_id", json.int(org_id)),
    #("integration_user_id", json.int(integration_user_id)),
    #("project_id", json_helpers.option_int_json(project_id)),
    #("name", json.string(name)),
    #("public_id", json.string(public_id)),
    #("scopes", json.array(scopes, of: scope)),
    #("created_at", json.string(created_at)),
    #("last_used_at", json_helpers.option_string_json(last_used_at)),
    #("expires_at", json_helpers.option_string_json(expires_at)),
    #("revoked_at", json_helpers.option_string_json(revoked_at)),
    #("expired", json.bool(expired)),
  ])
}

fn scope(scope) {
  json.string(token_service.scope_to_string(scope))
}
