import domain/org_role
import domain/user
import gleam/option.{None, Some}
import gleeunit/should
import lustre/effect
import scrumbringer_client/client_state
import scrumbringer_client/client_state/auth as auth_state
import scrumbringer_client/features/auth/update as auth_update

pub fn handle_login_submitted_ignores_when_in_flight_test() {
  let model =
    client_state.default_model()
    |> client_state.update_auth(fn(auth) {
      auth_state.AuthModel(
        ..auth,
        login_in_flight: True,
        login_error: Some("err"),
      )
    })

  let #(next_model, _effect) = auth_update.handle_login_submitted(model)
  let client_state.Model(auth: auth, ..) = next_model
  let auth_state.AuthModel(
    login_in_flight: login_in_flight,
    login_error: login_error,
    ..,
  ) = auth

  login_in_flight |> should.equal(True)
  login_error |> should.equal(Some("err"))
}

pub fn handle_login_submitted_sets_in_flight_and_clears_error_test() {
  let model =
    client_state.default_model()
    |> client_state.update_auth(fn(auth) {
      auth_state.AuthModel(
        ..auth,
        login_in_flight: False,
        login_error: Some("err"),
      )
    })

  let #(next_model, _effect) = auth_update.handle_login_submitted(model)
  let client_state.Model(auth: auth, ..) = next_model
  let auth_state.AuthModel(
    login_in_flight: login_in_flight,
    login_error: login_error,
    ..,
  ) = auth

  login_in_flight |> should.equal(True)
  login_error |> should.equal(None)
}

pub fn handle_login_finished_ok_admin_lands_on_member_page_test() {
  let model = client_state.default_model()
  let admin_user =
    user.User(
      id: 1,
      email: "admin@example.com",
      org_id: 1,
      org_role: org_role.Admin,
      created_at: "2026-01-01T00:00:00Z",
    )

  let #(next_model, _) =
    auth_update.handle_login_finished_ok(
      model,
      admin_user,
      fn(m) { #(m, effect.none()) },
      fn(m) { #(m, effect.none()) },
      fn(_) { effect.none() },
    )

  next_model.core.page |> should.equal(client_state.Member)
}
