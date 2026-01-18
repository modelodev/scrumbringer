//// Shared HTTP API utilities for ScrumBringer server.
////
//// Provides response helpers, cookie management, and common constants
//// used across all API endpoints.

import gleam/http
import gleam/http/cookie
import gleam/http/response
import gleam/json
import gleam/option
import wisp

/// Cookie name for session JWT.
pub const cookie_session_name = "sb_session"

/// Cookie name for CSRF token.
pub const cookie_csrf_name = "sb_csrf"

/// Header name for CSRF token in requests.
pub const csrf_header_name = "x-csrf"

/// Returns a 200 OK response with data wrapped in an envelope.
pub fn ok(data: json.Json) -> wisp.Response {
  envelope(data)
  |> wisp.json_response(200)
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
  |> response.set_cookie(cookie_csrf_name, csrf, csrf_cookie_attributes())
}

/// Clears session and CSRF cookies (for logout).
pub fn clear_auth_cookies(response: wisp.Response) -> wisp.Response {
  response
  |> response.expire_cookie(cookie_session_name, session_cookie_attributes())
  |> response.expire_cookie(cookie_csrf_name, csrf_cookie_attributes())
}

/// Returns True for HTTP methods that modify state.
pub fn is_mutating_method(method: http.Method) -> Bool {
  case method {
    http.Post | http.Put | http.Patch | http.Delete -> True
    _ -> False
  }
}

/// Cookie attributes for the session cookie (HttpOnly, Secure, Strict).
pub fn session_cookie_attributes() -> cookie.Attributes {
  cookie.Attributes(
    max_age: option.None,
    domain: option.None,
    path: option.Some("/"),
    secure: True,
    http_only: True,
    same_site: option.Some(cookie.Strict),
  )
}

/// Cookie attributes for CSRF token (readable by JS, Secure, Strict).
pub fn csrf_cookie_attributes() -> cookie.Attributes {
  cookie.Attributes(
    max_age: option.None,
    domain: option.None,
    path: option.Some("/"),
    secure: True,
    http_only: False,
    same_site: option.Some(cookie.Strict),
  )
}
