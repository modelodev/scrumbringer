import gleam/http/request
import gleam/list
import gleam/result
import gleam/string
import scrumbringer_server/http/api
import wisp

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
