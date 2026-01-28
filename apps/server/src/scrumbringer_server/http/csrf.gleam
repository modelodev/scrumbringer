//// CSRF protection using the double-submit cookie pattern.
////
//// Validates that a CSRF token in the request header matches the token
//// in the cookie, preventing cross-site request forgery attacks.

import gleam/http/request
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import wisp

// =============================================================================
// CSRF Constants
// =============================================================================

/// Cookie name for CSRF token.
pub const cookie_csrf_name = "sb_csrf"

/// Header name for CSRF token in requests.
pub const csrf_header_name = "x-csrf"

// =============================================================================
// CSRF Validation
// =============================================================================

/// Validates CSRF protection using double-submit cookie pattern.
///
/// Returns `Ok(Nil)` if the CSRF header matches the CSRF cookie,
/// `Error(Nil)` otherwise.
///
/// ## Example
/// ```gleam
/// case csrf.require_double_submit(req) {
///   Ok(Nil) -> handle_request(req)
///   Error(Nil) -> wisp.forbidden()
/// }
/// ```
pub fn require_double_submit(req: wisp.Request) -> Result(Nil, Nil) {
  use cookie_value <- result.try(get_cookie(req, cookie_csrf_name))
  use header_value <- result.try(get_header(req, csrf_header_name))

  case cookie_value == header_value {
    True -> Ok(Nil)
    False -> Error(Nil)
  }
}

/// Validates CSRF token for mutating requests.
///
/// Returns `Ok(Nil)` if CSRF validation passes, or an error response
/// with 403 Forbidden status if the token is missing or invalid.
///
/// ## Example
/// ```gleam
/// use <- result.try(csrf.require_csrf(req))
/// // Continue with request handling...
/// ```
pub fn require_csrf(req: wisp.Request) -> Result(Nil, wisp.Response) {
  case require_double_submit(req) {
    Ok(Nil) -> Ok(Nil)
    Error(_) -> Error(forbidden_response())
  }
}

// =============================================================================
// Private Helpers
// =============================================================================

fn get_cookie(req: wisp.Request, name: String) -> Result(String, Nil) {
  req
  |> request.get_cookies
  |> list.key_find(name)
}

fn get_header(req: wisp.Request, name: String) -> Result(String, Nil) {
  request.get_header(req, string.lowercase(name))
}

fn forbidden_response() -> wisp.Response {
  let body =
    json.object([
      #(
        "error",
        json.object([
          #("code", json.string("FORBIDDEN")),
          #("message", json.string("CSRF token missing or invalid")),
          #("details", json.object([])),
        ]),
      ),
    ])
    |> json.to_string

  wisp.json_response(body, 403)
}
