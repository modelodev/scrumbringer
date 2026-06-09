import domain/api_error.{ApiError}
import domain/org_role
import domain/user.{User}
import gleam/option.{None, Some}
import lustre/effect
import scrumbringer_client/client_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/client_state/types as state_types
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
      let pool = member.pool

      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_drag: state_types.DragActive(1, 5, 5),
          member_pool_drag: state_types.PoolDragDragging(
            over_my_tasks: True,
            rect: state_types.Rect(left: 0, top: 0, width: 10, height: 10),
          ),
        ),
      )
    })

  let #(next_model, _effect) = helpers.reset_to_login(model)

  let client_state.Model(core: core, member: member, ..) = next_model
  let client_state.CoreModel(page: page, user: user, ..) = core
  let member_state.MemberModel(pool: pool, ..) = member
  let member_pool.Model(
    member_drag: member_drag,
    member_pool_drag: member_pool_drag,
    ..,
  ) = pool

  let assert client_state.Login = page
  let assert None = user
  let assert state_types.DragIdle = member_drag
  let assert state_types.PoolDragIdle = member_pool_drag
}

pub fn handle_auth_error_returns_login_for_401_test() {
  let model = client_state.default_model()
  let err = ApiError(status: 401, code: "AUTH_REQUIRED", message: "Auth")

  let assert Some(#(next_model, _)) = helpers.handle_auth_error(model, err)
  let client_state.Model(core: core, ..) = next_model
  let client_state.CoreModel(page: page, ..) = core
  let assert client_state.Login = page
}

pub fn handle_auth_error_returns_toast_for_403_test() {
  let model = client_state.default_model()
  let err = ApiError(status: 403, code: "FORBIDDEN", message: "No")

  let assert Some(_) = helpers.handle_auth_error(model, err)
}

pub fn handle_auth_error_ignores_non_auth_errors_test() {
  let model = client_state.default_model()
  let err = ApiError(status: 500, code: "SERVER", message: "Oops")

  let assert None = helpers.handle_auth_error(model, err)
}

pub fn handle_401_or_resets_to_login_test() {
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
  let err = ApiError(status: 401, code: "AUTH_REQUIRED", message: "Auth")

  let #(next_model, _effect) =
    helpers.handle_401_or(model, err, fn() { #(model, effect.none()) })

  let client_state.Model(core: core, ..) = next_model
  let client_state.CoreModel(page: page, user: user, ..) = core
  let assert client_state.Login = page
  let assert None = user
}

pub fn handle_401_or_runs_fallback_for_other_errors_test() {
  let model = client_state.default_model()
  let err = ApiError(status: 422, code: "INVALID", message: "Invalid")

  let #(next_model, _effect) =
    helpers.handle_401_or(model, err, fn() {
      #(
        client_state.update_core(model, fn(core) {
          client_state.CoreModel(..core, page: client_state.Admin)
        }),
        effect.none(),
      )
    })

  let client_state.Model(core: core, ..) = next_model
  let client_state.CoreModel(page: page, ..) = core
  let assert client_state.Admin = page
}
