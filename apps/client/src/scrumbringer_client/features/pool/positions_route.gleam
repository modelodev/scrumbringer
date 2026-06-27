//// Root-aware adapter for member pool position updates.

import gleam/option as opt
import lustre/effect

import domain/api_error.{type ApiError}
import scrumbringer_client/app/effects as app_effects
import scrumbringer_client/client_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/positions as member_positions
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/pool/position_update
import scrumbringer_client/features/route_support
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/text as i18n_text

pub fn try_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    position_update.try_update(model.member.positions, inner, context(model))
  {
    opt.Some(update) -> opt.Some(apply_update(model, update))
    opt.None -> opt.None
  }
}

fn apply_update(
  model: client_state.Model,
  update: position_update.Update(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let position_update.Update(positions, fx, auth_policy) = update

  route_support.apply_auth_check(
    model,
    route_support.auth_check_before(auth_error(auth_policy)),
    fn() { #(set_member_positions(model, positions), fx) },
  )
}

fn context(
  model: client_state.Model,
) -> position_update.Context(client_state.Msg) {
  position_update.Context(
    selected_project_id: model.core.selected_project_id,
    invalid_xy: i18n.t(model.ui.locale, i18n_text.InvalidXY),
    on_position_saved: fn(result) {
      client_state.pool_msg(pool_messages.MemberPositionSaved(result))
    },
    on_positions_fetched: fn(result) {
      client_state.pool_msg(pool_messages.MemberPositionsFetched(result))
    },
    on_error_toast: app_effects.toast_error,
  )
}

fn auth_error(policy: position_update.AuthPolicy) -> opt.Option(ApiError) {
  case policy {
    position_update.NoAuthCheck -> opt.None
    position_update.CheckAuth(err) -> opt.Some(err)
  }
}

fn set_member_positions(
  model: client_state.Model,
  positions: member_positions.Model,
) -> client_state.Model {
  client_state.update_member(model, fn(member) {
    member_state.MemberModel(..member, positions: positions)
  })
}
