import gleam/http
import gleam/http/request
import gleeunit/should
import scrumbringer_server/http/csrf
import wisp
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

// =============================================================================
// require_csrf Tests (HTTP Response variant)
// =============================================================================

pub fn require_csrf_valid_token_returns_ok_test() {
  let req =
    base_req()
    |> request.set_cookie("sb_csrf", "valid-token")
    |> request.set_header("x-csrf", "valid-token")

  case csrf.require_csrf(req) {
    Ok(Nil) -> Nil
    Error(_) -> should.fail()
  }
}

pub fn require_csrf_missing_token_returns_403_test() {
  let req = base_req()

  case csrf.require_csrf(req) {
    Ok(_) -> should.fail()
    Error(response) -> {
      response.status |> should.equal(403)
    }
  }
}

pub fn require_csrf_invalid_token_returns_403_with_error_body_test() {
  let req =
    base_req()
    |> request.set_cookie("sb_csrf", "token-a")
    |> request.set_header("x-csrf", "token-b")

  case csrf.require_csrf(req) {
    Ok(_) -> should.fail()
    Error(response) -> {
      response.status |> should.equal(403)
      // Verify it's a JSON response with error body
      case response.body {
        wisp.Text(body) -> {
          // Body should contain error details
          body
          |> should.equal(
            "{\"error\":{\"code\":\"FORBIDDEN\",\"message\":\"CSRF token missing or invalid\",\"details\":{}}}",
          )
        }
        _ -> should.fail()
      }
    }
  }
}
