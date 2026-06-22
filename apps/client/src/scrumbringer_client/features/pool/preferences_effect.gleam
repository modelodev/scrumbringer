//// Root effects for member pool display preferences.

import gleam/option as opt
import lustre/effect

import scrumbringer_client/client_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/pool/preferences
import scrumbringer_client/pool_prefs
import scrumbringer_client/theme

pub fn try_update(
  model: client_state.Model,
  inner: pool_messages.Msg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case preferences.try_update(model.member.pool, inner) {
    opt.Some(#(pool, persistence)) ->
      opt.Some(#(update_member_pool(model, fn(_) { pool }), apply(persistence)))
    opt.None -> opt.None
  }
}

pub fn apply(
  persistence: preferences.Persistence,
) -> effect.Effect(client_state.Msg) {
  case persistence {
    preferences.NoPersistence -> effect.none()
    preferences.SaveViewMode(mode) -> save_view_mode(mode)
  }
}

fn save_view_mode(mode: pool_prefs.ViewMode) -> effect.Effect(client_state.Msg) {
  effect.from(fn(_dispatch) {
    theme.local_storage_set(
      pool_prefs.view_mode_storage_key,
      pool_prefs.encode_view_mode_storage(mode),
    )
  })
}

fn update_member_pool(
  model: client_state.Model,
  f: fn(member_pool.Model) -> member_pool.Model,
) -> client_state.Model {
  client_state.update_member(model, fn(member) {
    let pool = member.pool
    member_state.MemberModel(..member, pool: f(pool))
  })
}
