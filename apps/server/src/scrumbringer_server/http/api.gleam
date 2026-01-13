import gleam/http
import gleam/http/cookie
import gleam/http/response
import gleam/json
import gleam/option
import wisp

pub const cookie_session_name = "sb_session"

pub const cookie_csrf_name = "sb_csrf"

pub const csrf_header_name = "x-csrf"

pub fn ok(data: json.Json) -> wisp.Response {
  envelope(data)
  |> wisp.json_response(200)
}

pub fn no_content() -> wisp.Response {
  wisp.no_content()
}

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

pub fn envelope(data: json.Json) -> String {
  json.object([#("data", data)])
  |> json.to_string
}

pub fn set_auth_cookies(
  response: wisp.Response,
  jwt: String,
  csrf: String,
) -> wisp.Response {
  response
  |> response.set_cookie(cookie_session_name, jwt, session_cookie_attributes())
  |> response.set_cookie(cookie_csrf_name, csrf, csrf_cookie_attributes())
}

pub fn clear_auth_cookies(response: wisp.Response) -> wisp.Response {
  response
  |> response.expire_cookie(cookie_session_name, session_cookie_attributes())
  |> response.expire_cookie(cookie_csrf_name, csrf_cookie_attributes())
}

pub fn is_mutating_method(method: http.Method) -> Bool {
  case method {
    http.Post | http.Put | http.Patch | http.Delete -> True
    _ -> False
  }
}

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
