//// Root adapter for admin member and org-user search messages.

import gleam/option as opt

import lustre/effect

import scrumbringer_client/client_state
import scrumbringer_client/features/admin/member_add_update
import scrumbringer_client/features/admin/member_list_update
import scrumbringer_client/features/admin/member_release_all_update
import scrumbringer_client/features/admin/member_remove_update
import scrumbringer_client/features/admin/member_role_update
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/admin/search_update

pub fn try_update(
  model: client_state.Model,
  inner: admin_messages.Msg,
  refresh_section: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case member_list_update.try_update(model, inner) {
    opt.Some(result) -> opt.Some(result)
    opt.None -> update_without_member_list(model, inner, refresh_section)
  }
}

fn update_without_member_list(
  model: client_state.Model,
  inner: admin_messages.Msg,
  refresh_section: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case member_add_update.try_update(model, inner, refresh_section) {
    opt.Some(result) -> opt.Some(result)
    opt.None -> update_without_member_add(model, inner, refresh_section)
  }
}

fn update_without_member_add(
  model: client_state.Model,
  inner: admin_messages.Msg,
  refresh_section: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case member_remove_update.try_update(model, inner, refresh_section) {
    opt.Some(result) -> opt.Some(result)
    opt.None -> update_without_member_remove(model, inner)
  }
}

fn update_without_member_remove(
  model: client_state.Model,
  inner: admin_messages.Msg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case member_release_all_update.try_update(model, inner) {
    opt.Some(result) -> opt.Some(result)
    opt.None -> update_without_member_release_all(model, inner)
  }
}

fn update_without_member_release_all(
  model: client_state.Model,
  inner: admin_messages.Msg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case member_role_update.try_update(model, inner) {
    opt.Some(result) -> opt.Some(result)
    opt.None -> update_without_member_role(model, inner)
  }
}

fn update_without_member_role(
  model: client_state.Model,
  inner: admin_messages.Msg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case search_update.try_update(model, inner) {
    opt.Some(result) -> opt.Some(result)
    opt.None -> opt.None
  }
}
