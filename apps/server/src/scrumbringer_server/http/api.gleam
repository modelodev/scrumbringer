//// Shared HTTP API utilities for ScrumBringer server.
////
//// Provides response helpers, cookie management, and common constants
//// used across all API endpoints.

import envoy
import gleam/http/cookie
import gleam/http/response
import gleam/int
import gleam/json
import gleam/option
import scrumbringer_server/http/csrf
import wisp

/// Cookie name for session JWT.
pub const cookie_session_name = "sb_session"

/// Returns a 200 OK response with data wrapped in an envelope.
pub fn ok(data: json.Json) -> wisp.Response {
  envelope(data)
  |> wisp.json_response(200)
}

/// Returns a 200 OK health check response.
pub fn health_ok() -> wisp.Response {
  ok(json.object([#("ok", json.bool(True))]))
}

/// Returns a 204 No Content response.
pub fn no_content() -> wisp.Response {
  wisp.no_content()
}

/// Returns an error response with the given status and error details.
pub fn error(status: Int, code: String, message: String) -> wisp.Response {
  let body =
    json.object([
      #(
        "error",
        json.object([
          #("code", json.string(code)),
          #("message", json.string(message)),
          #("details", json.object([])),
        ]),
      ),
    ])
    |> json.to_string

  wisp.json_response(body, status)
}

/// Wraps data in a standard API envelope.
pub fn envelope(data: json.Json) -> String {
  json.object([#("data", data)])
  |> json.to_string
}

/// Sets session and CSRF cookies on a response.
pub fn set_auth_cookies(
  response: wisp.Response,
  jwt: String,
  csrf: String,
) -> wisp.Response {
  response
  |> response.set_cookie(cookie_session_name, jwt, session_cookie_attributes())
  |> response.set_cookie(csrf.cookie_csrf_name, csrf, csrf_cookie_attributes())
}

/// Clears session and CSRF cookies (for logout).
pub fn clear_auth_cookies(response: wisp.Response) -> wisp.Response {
  response
  |> response.expire_cookie(cookie_session_name, session_cookie_attributes())
  |> response.expire_cookie(csrf.cookie_csrf_name, csrf_cookie_attributes())
}

/// Check if we should use secure cookies (default: True).
/// Set SB_COOKIE_SECURE=false to disable for HTTP development.
fn is_cookie_secure() -> Bool {
  case envoy.get("SB_COOKIE_SECURE") {
    Ok(value) -> parse_cookie_secure_value(value)
    Error(_) -> True
  }
}

pub fn parse_cookie_secure_value(value: String) -> Bool {
  case value {
    "false" | "0" -> False
    _ -> True
  }
}

/// Cookie attributes for the session cookie (HttpOnly, Secure, Strict).
fn session_cookie_attributes() -> cookie.Attributes {
  cookie.Attributes(
    max_age: option.None,
    domain: option.None,
    path: option.Some("/"),
    secure: is_cookie_secure(),
    http_only: True,
    same_site: option.Some(cookie.Lax),
  )
}

/// Cookie attributes for CSRF token (readable by JS, Secure, Strict).
fn csrf_cookie_attributes() -> cookie.Attributes {
  cookie.Attributes(
    max_age: option.None,
    domain: option.None,
    path: option.Some("/"),
    secure: is_cookie_secure(),
    http_only: False,
    same_site: option.Some(cookie.Lax),
  )
}

// =============================================================================
// Request Validation Helpers
// =============================================================================

/// Parses a string ID into an integer.
///
/// Returns `Ok(id)` on success, or a 404 error response if parsing fails.
/// Useful for parsing URL path parameters.
///
/// ## Example
/// ```gleam
/// use id <- result.try(api.parse_id(id_str))
/// // Continue with the parsed id...
/// ```
pub fn parse_id(value: String) -> Result(Int, wisp.Response) {
  case int.parse(value) {
    Ok(id) -> Ok(id)
    Error(_) -> Error(error(404, "NOT_FOUND", "Not found"))
  }
}
