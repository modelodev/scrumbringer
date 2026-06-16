//// API token admin API functions.

import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/option.{type Option}
import gleam/string

import lustre/effect.{type Effect}

import domain/api_error.{type ApiResult}
import domain/api_token
import domain/api_token_scope
import domain/org_role/codec as org_role_codec
import scrumbringer_client/api/core
import scrumbringer_client/client_state/admin/api_tokens as api_tokens_state

pub fn list_integration_users(
  to_msg: fn(ApiResult(List(api_token.IntegrationUser))) -> msg,
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
  to_msg: fn(ApiResult(List(api_token.ApiToken))) -> msg,
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
  form: api_tokens_state.Form,
  to_msg: fn(ApiResult(api_token.CreatedApiToken)) -> msg,
) -> Effect(msg) {
  core.request(
    core.Post,
    "/api/v1/api-tokens",
    option.Some(token_body(form)),
    created_token_payload_decoder(),
    to_msg,
  )
}

pub fn rename_token(
  id: Int,
  name: String,
  to_msg: fn(ApiResult(api_token.ApiToken)) -> msg,
) -> Effect(msg) {
  core.request(
    core.Patch,
    "/api/v1/api-tokens/" <> int.to_string(id),
    option.Some(json.object([#("name", json.string(string.trim(name)))])),
    token_payload_decoder(),
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

pub fn deactivate_integration_user(
  id: Int,
  to_msg: fn(ApiResult(Nil)) -> msg,
) -> Effect(msg) {
  core.request_nil(
    core.Delete,
    "/api/v1/integration-users/" <> int.to_string(id),
    option.None,
    to_msg,
  )
}

pub fn integration_user_payload_decoder() -> decode.Decoder(
  api_token.IntegrationUser,
) {
  decode.field("integration_user", integration_user_decoder(), decode.success)
}

pub fn integration_users_payload_decoder() -> decode.Decoder(
  List(api_token.IntegrationUser),
) {
  decode.field(
    "integration_users",
    decode.list(integration_user_decoder()),
    decode.success,
  )
}

pub fn tokens_payload_decoder() -> decode.Decoder(List(api_token.ApiToken)) {
  decode.field("api_tokens", decode.list(token_decoder()), decode.success)
}

pub fn token_payload_decoder() -> decode.Decoder(api_token.ApiToken) {
  decode.field("api_token", token_decoder(), decode.success)
}

pub fn created_token_payload_decoder() -> decode.Decoder(
  api_token.CreatedApiToken,
) {
  use api_token_value <- decode.field("api_token", token_decoder())
  use token <- decode.field("token", decode.string)
  decode.success(api_token.CreatedApiToken(
    api_token: api_token_value,
    token: token,
  ))
}

pub fn integration_user_decoder() -> decode.Decoder(api_token.IntegrationUser) {
  use id <- decode.field("id", decode.int)
  use email <- decode.field("email", decode.string)
  use org_role <- decode.field("org_role", org_role_codec.org_role_decoder())
  use created_at <- decode.field("created_at", decode.string)
  use active_token_count <- decode.field("active_token_count", decode.int)
  decode.success(api_token.IntegrationUser(
    id: id,
    email: email,
    org_role: org_role,
    created_at: created_at,
    active_token_count: active_token_count,
  ))
}

pub fn token_decoder() -> decode.Decoder(api_token.ApiToken) {
  use id <- decode.field("id", decode.int)
  use org_id <- decode.field("org_id", decode.int)
  use integration_user_id <- decode.field("integration_user_id", decode.int)
  use integration_user_email <- decode.field(
    "integration_user_email",
    decode.string,
  )
  use project_id <- decode.field("project_id", core.nullable_int())
  use name <- decode.field("name", decode.string)
  use public_id <- decode.field("public_id", decode.string)
  use scopes <- decode.field("scopes", decode.list(api_token_scope.decoder()))
  use created_at <- decode.field("created_at", decode.string)
  use last_used_at <- decode.field("last_used_at", core.nullable_string())
  use expires_at <- decode.field("expires_at", core.nullable_string())
  use revoked_at <- decode.field("revoked_at", core.nullable_string())
  use expired <- decode.field("expired", decode.bool)
  decode.success(api_token.ApiToken(
    id: id,
    org_id: org_id,
    integration_user_id: integration_user_id,
    integration_user_email: integration_user_email,
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

fn token_body(form: api_tokens_state.Form) -> json.Json {
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
