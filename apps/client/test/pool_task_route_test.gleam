import gleam/option as opt
import lustre/effect

import domain/api_error.{ApiError}
import scrumbringer_client/client_state
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/pool/task_route

fn no_refresh(model: client_state.Model) {
  #(model, effect.none())
}

fn model_with_pool(pool: member_pool.Model) -> client_state.Model {
  client_state.update_member(client_state.default_model(), fn(member) {
    member_state.MemberModel(..member, pool: pool)
  })
}

pub fn try_update_routes_task_create_opened_test() {
  let assert opt.Some(#(next, fx)) =
    task_route.try_update(
      client_state.default_model(),
      pool_messages.MemberCreateDialogOpened,
      no_refresh,
    )

  let assert dialog_mode.DialogCreate =
    next.member.pool.member_create_dialog_mode
  let assert True = fx == effect.none()
}

pub fn try_update_handles_create_unauthorized_before_apply_test() {
  let err =
    ApiError(status: 401, code: "UNAUTHORIZED", message: "Sign in again")
  let model =
    model_with_pool(
      member_pool.Model(
        ..member_pool.default_model(),
        member_create_in_flight: True,
      ),
    )

  let assert opt.Some(#(next, fx)) =
    task_route.try_update(
      model,
      pool_messages.MemberTaskCreated(Error(err)),
      no_refresh,
    )

  let assert client_state.Login = next.core.page
  let assert opt.None = next.core.user
  let assert True = next.member.pool.member_create_in_flight
  let assert True = fx == effect.none()
}

pub fn try_update_ignores_non_task_messages_test() {
  let assert opt.None =
    task_route.try_update(
      client_state.default_model(),
      pool_messages.MemberPoolFiltersToggled,
      no_refresh,
    )
}
