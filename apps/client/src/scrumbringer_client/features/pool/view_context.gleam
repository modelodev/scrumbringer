//// Builds pool view context from root client state.

import gleam/list
import gleam/option as opt

import domain/card.{type Card}
import domain/project/settings as project_settings
import domain/remote.{unwrap}
import scrumbringer_client/client_state
import scrumbringer_client/client_state/selectors as state_selectors
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/pool/view_config as pool_view

pub fn from_state(
  model: client_state.Model,
  cards: List(Card),
) -> pool_view.Context(client_state.Msg) {
  pool_view.Context(
    locale: model.ui.locale,
    theme: model.ui.theme,
    has_active_projects: !list.is_empty(state_selectors.active_projects(model)),
    healthy_pool_limit: selected_healthy_pool_limit(model),
    current_user_id: model.core.user |> opt.map(fn(user) { user.id }),
    active_task_id: state_selectors.now_working_active_task_id(model),
    now_working_sessions: state_selectors.now_working_all_sessions(model),
    cards: cards,
    capabilities: unwrap(model.admin.capabilities.capabilities, []),
    pool: model.member.pool,
    now_working: model.member.now_working,
    skills: model.member.skills,
    notes: model.member.notes,
    positions: model.member.positions,
    callbacks: callbacks(),
  )
}

fn selected_healthy_pool_limit(model: client_state.Model) -> Int {
  case state_selectors.selected_project(model) {
    opt.Some(project) -> project.healthy_pool_limit
    opt.None -> project_settings.default_healthy_pool_limit()
  }
}

fn callbacks() -> pool_view.Callbacks(client_state.Msg) {
  pool_view.Callbacks(
    on_drag_moved: fn(x, y) {
      client_state.pool_msg(pool_messages.MemberDragMoved(x, y))
    },
    on_drag_ended: client_state.pool_msg(pool_messages.MemberDragEnded),
    on_create_opened: client_state.pool_msg(
      pool_messages.MemberCreateDialogOpened,
    ),
    on_capability_scope_change: fn(value) {
      client_state.pool_msg(pool_messages.MemberPoolCapabilityScopeChanged(
        value,
      ))
    },
    on_type_filter_change: fn(value) {
      client_state.pool_msg(pool_messages.MemberPoolTypeChanged(value))
    },
    on_capability_filter_change: fn(value) {
      client_state.pool_msg(pool_messages.MemberPoolCapabilityChanged(value))
    },
    on_search_change: fn(value) {
      client_state.pool_msg(pool_messages.MemberPoolSearchChanged(value))
    },
    on_visibility_change: fn(value) {
      client_state.pool_msg(pool_messages.MemberPoolVisibilityChanged(value))
    },
    on_view_mode_change: fn(mode) {
      client_state.pool_msg(pool_messages.MemberPoolViewModeSet(mode))
    },
    on_now_working_pause: client_state.pool_msg(
      pool_messages.MemberNowWorkingPauseClicked,
    ),
    on_now_working_start: fn(task_id) {
      client_state.pool_msg(pool_messages.MemberNowWorkingStartClicked(task_id))
    },
    on_claim: fn(task_id, version) {
      client_state.pool_msg(pool_messages.MemberClaimClicked(task_id, version))
    },
    on_release: fn(task_id, version) {
      client_state.pool_msg(pool_messages.MemberReleaseClicked(task_id, version))
    },
    on_close: fn(task_id, version) {
      client_state.pool_msg(pool_messages.MemberCloseClicked(task_id, version))
    },
    on_open: fn(task_id) {
      client_state.pool_msg(pool_messages.MemberTaskShowOpened(task_id))
    },
    on_hover_opened: fn(task_id) {
      client_state.pool_msg(pool_messages.MemberTaskHoverOpened(task_id))
    },
    on_hover_closed: client_state.pool_msg(pool_messages.MemberTaskHoverClosed),
    on_focused: fn(task_id) {
      client_state.pool_msg(pool_messages.MemberTaskFocused(task_id))
    },
    on_blurred: client_state.pool_msg(pool_messages.MemberTaskBlurred),
    on_drag_started: fn(task_id, x, y) {
      client_state.pool_msg(pool_messages.MemberDragStarted(task_id, x, y))
    },
    on_touch_started: fn(task_id, x, y) {
      client_state.pool_msg(pool_messages.MemberPoolTouchStarted(task_id, x, y))
    },
    on_touch_ended: fn(task_id) {
      client_state.pool_msg(pool_messages.MemberPoolTouchEnded(task_id))
    },
  )
}
