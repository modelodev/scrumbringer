import domain/api_error.{ApiError}
import domain/org_role
import domain/user.{User}
import gleam/option.{None, Some}
import gleeunit/should
import scrumbringer_client/client_state
import scrumbringer_client/features/auth/helpers

pub fn reset_to_login_clears_user_and_drag_state_test() {
  let model =
    client_state.default_model()
    |> client_state.update_core(fn(core) {
      client_state.CoreModel(
        ..core,
        page: client_state.Admin,
        user: Some(User(
          id: 1,
          email: "admin@example.com",
          org_id: 1,
          org_role: org_role.Admin,
          created_at: "2026-01-01T00:00:00Z",
        )),
      )
    })
    |> client_state.update_member(fn(member) {
      client_state.MemberModel(
        ..member,
        member_drag: Some(client_state.MemberDrag(
          task_id: 1,
          offset_x: 5,
          offset_y: 5,
        )),
        member_pool_drag: client_state.PoolDragDragging(
          over_my_tasks: True,
          rect: client_state.Rect(left: 0, top: 0, width: 10, height: 10),
        ),
      )
    })

  let #(next_model, _effect) = helpers.reset_to_login(model)

  let client_state.Model(core: core, member: member, ..) = next_model
  let client_state.CoreModel(page: page, user: user, ..) = core
  let client_state.MemberModel(
    member_drag: member_drag,
    member_pool_drag: member_pool_drag,
    ..,
  ) = member

  page |> should.equal(client_state.Login)
  user |> should.equal(None)
  member_drag |> should.equal(None)
  member_pool_drag |> should.equal(client_state.PoolDragIdle)
}

pub fn handle_auth_error_returns_login_for_401_test() {
  let model = client_state.default_model()
  let err = ApiError(status: 401, code: "AUTH_REQUIRED", message: "Auth")

  case helpers.handle_auth_error(model, err) {
    Some(#(next_model, _)) -> {
      let client_state.Model(core: core, ..) = next_model
      let client_state.CoreModel(page: page, ..) = core
      page |> should.equal(client_state.Login)
    }
    None -> should.fail()
  }
}

pub fn handle_auth_error_returns_toast_for_403_test() {
  let model = client_state.default_model()
  let err = ApiError(status: 403, code: "FORBIDDEN", message: "No")

  case helpers.handle_auth_error(model, err) {
    Some(_) -> should.be_true(True)
    None -> should.fail()
  }
}

pub fn handle_auth_error_ignores_non_auth_errors_test() {
  let model = client_state.default_model()
  let err = ApiError(status: 500, code: "SERVER", message: "Oops")

  helpers.handle_auth_error(model, err)
  |> should.equal(None)
}
