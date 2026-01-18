//// CSRF protection using the double-submit cookie pattern.
////
//// Validates that a CSRF token in the request header matches the token
//// in the cookie, preventing cross-site request forgery attacks.

import gleam/http/request
import gleam/list
import gleam/result
import gleam/string
import scrumbringer_server/http/api
import wisp

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
  use cookie_value <- result.try(get_cookie(req, api.cookie_csrf_name))
  use header_value <- result.try(get_header(req, api.csrf_header_name))

  case cookie_value == header_value {
    True -> Ok(Nil)
    False -> Error(Nil)
  }
}

fn get_cookie(req: wisp.Request, name: String) -> Result(String, Nil) {
  req
  |> request.get_cookies
  |> list.key_find(name)
}

fn get_header(req: wisp.Request, name: String) -> Result(String, Nil) {
  request.get_header(req, string.lowercase(name))
}
