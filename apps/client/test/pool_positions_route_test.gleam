import gleam/option as opt
import lustre/effect

import domain/api_error.{ApiError}
import scrumbringer_client/client_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/positions as member_positions
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/pool/positions_route

fn model_with_positions(positions: member_positions.Model) -> client_state.Model {
  client_state.update_member(client_state.default_model(), fn(member) {
    member_state.MemberModel(..member, positions: positions)
  })
}

pub fn try_update_routes_position_opened_test() {
  let assert opt.Some(#(next, fx)) =
    positions_route.try_update(
      client_state.default_model(),
      pool_messages.MemberPositionEditOpened(7),
    )

  let assert opt.Some(7) = next.member.positions.member_position_edit_task
  let assert True = fx == effect.none()
}

pub fn try_update_handles_unauthorized_before_apply_test() {
  let err =
    ApiError(status: 401, code: "UNAUTHORIZED", message: "Sign in again")
  let model =
    model_with_positions(
      member_positions.Model(
        ..member_positions.default_model(),
        member_position_edit_in_flight: True,
      ),
    )

  let assert opt.Some(#(next, fx)) =
    positions_route.try_update(
      model,
      pool_messages.MemberPositionSaved(Error(err)),
    )

  let assert client_state.Login = next.core.page
  let assert opt.None = next.core.user
  let assert True = next.member.positions.member_position_edit_in_flight
  let assert opt.None = next.member.positions.member_position_edit_error
  let assert True = fx == effect.none()
}

pub fn try_update_ignores_non_position_messages_test() {
  let assert opt.None =
    positions_route.try_update(
      client_state.default_model(),
      pool_messages.MemberPoolVisibilityChanged("all-open"),
    )
}
