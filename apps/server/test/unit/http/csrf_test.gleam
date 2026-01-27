import gleam/http
import gleam/http/request
import gleeunit/should
import scrumbringer_server/http/csrf
import wisp/simulate

fn base_req() {
  simulate.request(http.Post, "/")
}

pub fn require_double_submit_missing_cookie_test() {
  let req =
    base_req()
    |> request.set_header("x-csrf", "token")

  case csrf.require_double_submit(req) {
    Ok(_) -> should.fail()
    Error(_) -> Nil
  }
}

pub fn require_double_submit_missing_header_test() {
  let req =
    base_req()
    |> request.set_cookie("sb_csrf", "token")

  case csrf.require_double_submit(req) {
    Ok(_) -> should.fail()
    Error(_) -> Nil
  }
}

pub fn require_double_submit_mismatch_test() {
  let req =
    base_req()
    |> request.set_cookie("sb_csrf", "token-a")
    |> request.set_header("x-csrf", "token-b")

  case csrf.require_double_submit(req) {
    Ok(_) -> should.fail()
    Error(_) -> Nil
  }
}
