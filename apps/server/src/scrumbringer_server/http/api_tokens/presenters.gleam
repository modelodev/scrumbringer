import domain/api_token as api_token_domain
import gleam/json
import helpers/json as json_helpers
import scrumbringer_server/use_case/api_tokens as token_service

pub fn tokens_response(tokens: List(token_service.ApiTokenRecord)) -> json.Json {
  json.object([#("api_tokens", json.array(tokens, of: token))])
}

pub fn created_token_response(created: token_service.CreatedToken) -> json.Json {
  let token_service.CreatedToken(token: api_token, bearer: bearer) = created

  json.object([
    #("api_token", token(api_token)),
    #("token", json.string(bearer)),
  ])
}

pub fn token_response(api_token: token_service.ApiTokenRecord) -> json.Json {
  json.object([#("api_token", token(api_token))])
}

pub fn token(api_token: token_service.ApiTokenRecord) -> json.Json {
  let token_service.ApiTokenRecord(
    id: id,
    org_id: org_id,
    integration_user_id: integration_user_id,
    integration_user_email: integration_user_email,
    project_grant: project_grant,
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
    #("integration_user_email", json.string(integration_user_email)),
    #(
      "project_id",
      json_helpers.option_int_json(api_token_domain.project_grant_to_option(
        project_grant,
      )),
    ),
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
