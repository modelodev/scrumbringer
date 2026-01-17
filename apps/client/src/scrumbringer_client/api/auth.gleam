//// Authentication API functions for Scrumbringer client.
////
//// ## Mission
////
//// Provides all authentication-related API operations including login, logout,
//// user fetching, invite links, and password resets.
////
//// ## Responsibilities
////
//// - User authentication (`login`, `logout`, `fetch_me`)
//// - Invite link handling (`validate_invite_link_token`, `register_with_invite_link`)
//// - Password reset flow (`request_password_reset`, `validate_password_reset_token`,
////   `consume_password_reset_token`)
////
//// ## Usage
////
//// ```gleam
//// import scrumbringer_client/api/auth
////
//// auth.login("user@example.com", "password", LoginResult)
//// auth.fetch_me(MeFetched)
//// ```

import gleam/dynamic/decode
import gleam/json
import gleam/option
import gleam/string

import lustre/effect.{type Effect}

import scrumbringer_client/api/core.{type ApiResult}
import scrumbringer_client/client_ffi
import scrumbringer_domain/org_role
import scrumbringer_domain/user.{type User, User}

// =============================================================================
// Decoders
// =============================================================================

fn user_decoder() -> decode.Decoder(User) {
  use id <- decode.field("id", decode.int)
  use email <- decode.field("email", decode.string)
  use org_id <- decode.field("org_id", decode.int)
  use org_role_str <- decode.field("org_role", decode.string)
  use created_at <- decode.field("created_at", decode.string)

  case org_role.parse(org_role_str) {
    Ok(role) ->
      decode.success(User(
        id: id,
        email: email,
        org_id: org_id,
        org_role: role,
        created_at: created_at,
      ))
    Error(_) ->
      decode.failure(
        User(
          id: 0,
          email: "",
          org_id: 0,
          org_role: org_role.Member,
          created_at: "",
        ),
        expected: "OrgRole",
      )
  }
}

/// Decoder for user wrapped in { "user": ... } envelope.
pub fn user_payload_decoder() -> decode.Decoder(User) {
  decode.field("user", user_decoder(), decode.success)
}

// =============================================================================
// Types
// =============================================================================

/// Password reset token response.
pub type PasswordReset {
  PasswordReset(token: String, url_path: String)
}

// =============================================================================
// API Functions
// =============================================================================

/// Fetch the current authenticated user.
///
/// ## Example
///
/// ```gleam
/// fetch_me(MeFetched)
/// ```
pub fn fetch_me(to_msg: fn(ApiResult(User)) -> msg) -> Effect(msg) {
  core.request(
    "GET",
    "/api/v1/auth/me",
    option.None,
    user_payload_decoder(),
    to_msg,
  )
}

/// Login with email and password.
///
/// ## Example
///
/// ```gleam
/// login("user@example.com", "secret123", LoginResult)
/// ```
pub fn login(
  email: String,
  password: String,
  to_msg: fn(ApiResult(User)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("email", json.string(email)),
      #("password", json.string(password)),
    ])
  core.request(
    "POST",
    "/api/v1/auth/login",
    option.Some(body),
    user_payload_decoder(),
    to_msg,
  )
}

/// Logout the current user.
///
/// ## Example
///
/// ```gleam
/// logout(LogoutResult)
/// ```
pub fn logout(to_msg: fn(ApiResult(Nil)) -> msg) -> Effect(msg) {
  core.request_nil("POST", "/api/v1/auth/logout", option.None, to_msg)
}

/// Validate an invite link token and get the associated email.
///
/// ## Example
///
/// ```gleam
/// validate_invite_link_token("token123", TokenValidated)
/// ```
pub fn validate_invite_link_token(
  token: String,
  to_msg: fn(ApiResult(String)) -> msg,
) -> Effect(msg) {
  let decoder = decode.field("email", decode.string, decode.success)

  core.request(
    "GET",
    "/api/v1/auth/invite-links/" <> client_ffi.encode_uri_component(token),
    option.None,
    decoder,
    to_msg,
  )
}

/// Register a new user using an invite link token.
///
/// ## Example
///
/// ```gleam
/// register_with_invite_link("token123", "password456", Registered)
/// ```
pub fn register_with_invite_link(
  invite_token: String,
  password: String,
  to_msg: fn(ApiResult(User)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("password", json.string(password)),
      #("invite_token", json.string(invite_token)),
    ])

  core.request(
    "POST",
    "/api/v1/auth/register",
    option.Some(body),
    user_payload_decoder(),
    to_msg,
  )
}

/// Request a password reset for an email address.
///
/// ## Example
///
/// ```gleam
/// request_password_reset("user@example.com", ResetRequested)
/// ```
pub fn request_password_reset(
  email: String,
  to_msg: fn(ApiResult(PasswordReset)) -> msg,
) -> Effect(msg) {
  let body = json.object([#("email", json.string(string.trim(email)))])

  let decoder = {
    use token <- decode.field("token", decode.string)
    use url_path <- decode.field("url_path", decode.string)
    decode.success(PasswordReset(token: token, url_path: url_path))
  }

  let envelope_decoder = decode.field("reset", decoder, decode.success)

  core.request(
    "POST",
    "/api/v1/auth/password-resets",
    option.Some(body),
    envelope_decoder,
    to_msg,
  )
}

/// Validate a password reset token and get the associated email.
///
/// ## Example
///
/// ```gleam
/// validate_password_reset_token("token123", TokenValidated)
/// ```
pub fn validate_password_reset_token(
  token: String,
  to_msg: fn(ApiResult(String)) -> msg,
) -> Effect(msg) {
  let decoder = decode.field("email", decode.string, decode.success)

  core.request(
    "GET",
    "/api/v1/auth/password-resets/" <> client_ffi.encode_uri_component(token),
    option.None,
    decoder,
    to_msg,
  )
}

/// Consume a password reset token to set a new password.
///
/// ## Example
///
/// ```gleam
/// consume_password_reset_token("token123", "newpass456", ResetConsumed)
/// ```
pub fn consume_password_reset_token(
  token: String,
  password: String,
  to_msg: fn(ApiResult(Nil)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("token", json.string(token)),
      #("password", json.string(password)),
    ])

  core.request_nil(
    "POST",
    "/api/v1/auth/password-resets/consume",
    option.Some(body),
    to_msg,
  )
}
