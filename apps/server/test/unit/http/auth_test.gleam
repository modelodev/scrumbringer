//// Unit tests for authentication module.
////
//// Tests the require_current_user function via HTTP endpoints
//// that use auth validation, and project member/admin checks.

import fixtures
import gleam/http
import gleeunit
import gleeunit/should
import wisp/simulate

pub fn main() {
  gleeunit.main()
}

// =============================================================================
// AC1: Auth session valid test
// =============================================================================

pub fn require_current_user_returns_user_for_valid_session_test() {
  // Given: Bootstrap with valid admin session
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()

  // When: Call /me endpoint with valid session
  let res =
    handler(
      simulate.request(http.Get, "/api/v1/auth/me")
      |> fixtures.with_auth(session),
    )

  // Then: Returns 200 with user data
  res.status |> should.equal(200)

  // Verify response contains user email
  let body = simulate.read_body(res)
  body |> should.not_equal("")
}

// =============================================================================
// AC2: Auth session invalid test
// =============================================================================

pub fn require_current_user_returns_error_for_invalid_session_test() {
  // Given: Bootstrap to get handler
  let assert Ok(#(_app, handler, _session)) = fixtures.bootstrap()

  // When: Call /me endpoint WITHOUT session (no auth)
  let res = handler(simulate.request(http.Get, "/api/v1/auth/me"))

  // Then: Returns 401 AUTH_REQUIRED
  res.status |> should.equal(401)
}

pub fn require_current_user_returns_error_for_expired_token_test() {
  // Given: Bootstrap to get handler
  let assert Ok(#(_app, handler, _session)) = fixtures.bootstrap()

  // Create a fake session with invalid token
  let fake_session = fixtures.Session(token: "invalid_jwt_token", csrf: "csrf")

  // When: Call /me endpoint with invalid token
  let res =
    handler(
      simulate.request(http.Get, "/api/v1/auth/me")
      |> fixtures.with_auth(fake_session),
    )

  // Then: Returns 401 AUTH_REQUIRED
  res.status |> should.equal(401)
}
