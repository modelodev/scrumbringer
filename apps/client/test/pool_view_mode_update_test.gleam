import gleam/option as opt

import domain/view_mode
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/pool/view_mode_update
import scrumbringer_client/url_state

fn context(selected_project_id: opt.Option(Int)) -> view_mode_update.Context {
  view_mode_update.Context(selected_project_id: selected_project_id)
}

pub fn try_update_changes_view_mode_and_preserves_project_route_test() {
  let assert opt.Some(view_mode_update.Update(next, route_policy)) =
    view_mode_update.try_update(
      member_pool.default_model(),
      pool_messages.ViewModeChanged(view_mode.People),
      context(opt.Some(7)),
    )

  let assert view_mode.People = next.view_mode
  let assert opt.None = next.member_card_depth_filter
  let assert view_mode_update.ReplaceMemberRoute(state) = route_policy
  let assert opt.Some(7) = url_state.project(state)
  let assert view_mode.People = url_state.view(state)
}

pub fn try_update_changes_view_mode_without_project_test() {
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_card_depth_filter: opt.Some(2),
    )
  let assert opt.Some(view_mode_update.Update(next, route_policy)) =
    view_mode_update.try_update(
      model,
      pool_messages.ViewModeChanged(view_mode.Cards),
      context(opt.None),
    )

  let assert view_mode.Cards = next.view_mode
  let assert opt.None = next.member_card_depth_filter
  let assert view_mode_update.ReplaceMemberRoute(state) = route_policy
  let assert opt.None = url_state.project(state)
  let assert view_mode.Cards = url_state.view(state)
}

pub fn try_update_ignores_non_view_mode_messages_test() {
  let assert opt.None =
    view_mode_update.try_update(
      member_pool.default_model(),
      pool_messages.MemberPoolFiltersToggled,
      context(opt.Some(7)),
    )
}
