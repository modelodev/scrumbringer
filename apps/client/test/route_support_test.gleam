import domain/api_error.{ApiError}
import domain/org_role
import domain/user.{User}
import gleam/option.{None, Some}
import lustre/effect
import scrumbringer_client/client_state
import scrumbringer_client/features/route_support

pub fn apply_auth_check_before_401_skips_local_update_test() {
  let model = authed_admin_model()
  let err = ApiError(status: 401, code: "AUTH_REQUIRED", message: "Auth")

  let #(next, _) =
    route_support.apply_auth_check_before(model, Some(err), fn() {
      #(mark_auth_checked(model), effect.none())
    })

  let client_state.Model(core: core, ..) = next
  let client_state.CoreModel(page: page, user: user, auth_checked: checked, ..) =
    core

  let assert client_state.Login = page
  let assert None = user
  let assert False = checked
}

pub fn apply_auth_check_after_401_keeps_local_update_before_reset_test() {
  let model = authed_admin_model()
  let err = ApiError(status: 401, code: "AUTH_REQUIRED", message: "Auth")

  let #(next, _) =
    route_support.apply_auth_check_after(Some(err), fn() {
      #(mark_auth_checked(model), effect.none())
    })

  let client_state.Model(core: core, ..) = next
  let client_state.CoreModel(page: page, user: user, auth_checked: checked, ..) =
    core

  let assert client_state.Login = page
  let assert None = user
  let assert True = checked
}

fn mark_auth_checked(model: client_state.Model) -> client_state.Model {
  client_state.update_core(model, fn(core) {
    client_state.CoreModel(..core, auth_checked: True)
  })
}

fn authed_admin_model() -> client_state.Model {
  client_state.default_model()
  |> client_state.update_core(fn(core) {
    client_state.CoreModel(
      ..core,
      page: client_state.Admin,
      auth_checked: False,
      user: Some(User(
        id: 1,
        email: "admin@example.com",
        org_id: 1,
        org_role: org_role.Admin,
        created_at: "2026-01-01T00:00:00Z",
      )),
    )
  })
}
