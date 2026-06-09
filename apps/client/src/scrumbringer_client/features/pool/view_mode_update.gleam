//// Member view-mode routing transitions.

import gleam/option as opt

import domain/view_mode
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/member_section
import scrumbringer_client/url_state

pub type Context {
  Context(
    selected_project_id: opt.Option(Int),
    member_section: member_section.MemberSection,
  )
}

pub type RoutePolicy {
  NoRouteChange
  ReplaceMemberRoute(member_section.MemberSection, url_state.UrlState)
}

pub type Update {
  Update(member_pool.Model, RoutePolicy)
}

pub fn try_update(
  model: member_pool.Model,
  inner: pool_messages.Msg,
  context: Context,
) -> opt.Option(Update) {
  case inner {
    pool_messages.ViewModeChanged(mode) ->
      opt.Some(view_mode_changed(model, mode, context))
    _ -> opt.None
  }
}

pub fn view_mode_changed(
  model: member_pool.Model,
  mode: view_mode.ViewMode,
  context: Context,
) -> Update {
  let Context(selected_project_id: selected_project_id, member_section: section) =
    context
  let state = case selected_project_id {
    opt.Some(project_id) ->
      url_state.with_project(url_state.empty(), project_id)
    opt.None -> url_state.empty()
  }
  let state = url_state.with_view(state, mode)

  Update(
    member_pool.Model(..model, view_mode: mode),
    ReplaceMemberRoute(section, state),
  )
}
