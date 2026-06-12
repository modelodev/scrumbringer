//// API token admin API functions.

import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/option.{type Option}
import gleam/string

import lustre/effect.{type Effect}

import domain/api_error.{type ApiResult}
import domain/api_token_scope
import domain/org_role/codec as org_role_codec
import scrumbringer_client/api/core
import scrumbringer_client/client_state/types as state_types

pub fn list_integration_users(
  to_msg: fn(ApiResult(List(state_types.IntegrationUser))) -> msg,
) -> Effect(msg) {
  core.request(
    core.Get,
    "/api/v1/integration-users",
    option.None,
    integration_users_payload_decoder(),
    to_msg,
  )
}

pub fn list_tokens(
  to_msg: fn(ApiResult(List(state_types.ApiToken))) -> msg,
) -> Effect(msg) {
  core.request(
    core.Get,
    "/api/v1/api-tokens",
    option.None,
    tokens_payload_decoder(),
    to_msg,
  )
}

pub fn create_token(
  form: state_types.ApiTokenForm,
  to_msg: fn(ApiResult(state_types.CreatedApiToken)) -> msg,
) -> Effect(msg) {
  core.request(
    core.Post,
    "/api/v1/api-tokens",
    option.Some(token_body(form)),
    created_token_payload_decoder(),
    to_msg,
  )
}

pub fn revoke_token(id: Int, to_msg: fn(ApiResult(Nil)) -> msg) -> Effect(msg) {
  core.request_nil(
    core.Delete,
    "/api/v1/api-tokens/" <> int.to_string(id),
    option.None,
    to_msg,
  )
}

pub fn integration_user_payload_decoder() -> decode.Decoder(
  state_types.IntegrationUser,
) {
  decode.field("integration_user", integration_user_decoder(), decode.success)
}

pub fn integration_users_payload_decoder() -> decode.Decoder(
  List(state_types.IntegrationUser),
) {
  decode.field(
    "integration_users",
    decode.list(integration_user_decoder()),
    decode.success,
  )
}

pub fn tokens_payload_decoder() -> decode.Decoder(List(state_types.ApiToken)) {
  decode.field("api_tokens", decode.list(token_decoder()), decode.success)
}

pub fn created_token_payload_decoder() -> decode.Decoder(
  state_types.CreatedApiToken,
) {
  use api_token <- decode.field("api_token", token_decoder())
  use token <- decode.field("token", decode.string)
  decode.success(state_types.CreatedApiToken(api_token: api_token, token: token))
}

pub fn integration_user_decoder() -> decode.Decoder(state_types.IntegrationUser) {
  use id <- decode.field("id", decode.int)
  use email <- decode.field("email", decode.string)
  use org_role <- decode.field("org_role", org_role_codec.org_role_decoder())
  use created_at <- decode.field("created_at", decode.string)
  decode.success(state_types.IntegrationUser(
    id: id,
    email: email,
    org_role: org_role,
    created_at: created_at,
  ))
}

pub fn token_decoder() -> decode.Decoder(state_types.ApiToken) {
  use id <- decode.field("id", decode.int)
  use org_id <- decode.field("org_id", decode.int)
  use integration_user_id <- decode.field("integration_user_id", decode.int)
  use project_id <- decode.field("project_id", core.nullable_int())
  use name <- decode.field("name", decode.string)
  use public_id <- decode.field("public_id", decode.string)
  use scopes <- decode.field("scopes", decode.list(api_token_scope.decoder()))
  use created_at <- decode.field("created_at", decode.string)
  use last_used_at <- decode.field("last_used_at", core.nullable_string())
  use expires_at <- decode.field("expires_at", core.nullable_string())
  use revoked_at <- decode.field("revoked_at", core.nullable_string())
  use expired <- decode.field("expired", decode.bool)
  decode.success(state_types.ApiToken(
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
  ))
}

fn token_body(form: state_types.ApiTokenForm) -> json.Json {
  json.object([
    #("name", json.string(string.trim(form.name))),
    #("integration", json.string(string.trim(form.integration))),
    #("project_id", option_int_json(form.project_id)),
    #("scopes", json.array(form.scopes, of: scope_json)),
    #("expires_at", optional_string_json(form.expires_at)),
  ])
}

fn scope_json(scope: api_token_scope.Scope) -> json.Json {
  api_token_scope.to_string(scope)
  |> json.string
}

fn option_int_json(value: Option(Int)) -> json.Json {
  case value {
    option.Some(id) -> json.int(id)
    option.None -> json.null()
  }
}

fn optional_string_json(value: String) -> json.Json {
  case string.trim(value) {
    "" -> json.null()
    other -> json.string(other)
  }
}
