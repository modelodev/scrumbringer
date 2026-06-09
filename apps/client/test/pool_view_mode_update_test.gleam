import gleam/option as opt

import domain/view_mode
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/pool/view_mode_update
import scrumbringer_client/member_section
import scrumbringer_client/url_state

fn context(selected_project_id: opt.Option(Int)) -> view_mode_update.Context {
  view_mode_update.Context(
    selected_project_id: selected_project_id,
    member_section: member_section.Pool,
  )
}

pub fn try_update_changes_view_mode_and_preserves_project_route_test() {
  let assert opt.Some(view_mode_update.Update(next, route_policy)) =
    view_mode_update.try_update(
      member_pool.default_model(),
      pool_messages.ViewModeChanged(view_mode.Milestones),
      context(opt.Some(7)),
    )

  let assert view_mode.Milestones = next.view_mode
  let assert view_mode_update.ReplaceMemberRoute(section, state) = route_policy
  let assert member_section.Pool = section
  let assert opt.Some(7) = url_state.project(state)
  let assert view_mode.Milestones = url_state.view(state)
}

pub fn try_update_changes_view_mode_without_project_test() {
  let assert opt.Some(view_mode_update.Update(next, route_policy)) =
    view_mode_update.try_update(
      member_pool.default_model(),
      pool_messages.ViewModeChanged(view_mode.Cards),
      context(opt.None),
    )

  let assert view_mode.Cards = next.view_mode
  let assert view_mode_update.ReplaceMemberRoute(_, state) = route_policy
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
