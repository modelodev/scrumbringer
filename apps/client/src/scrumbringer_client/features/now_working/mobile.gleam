//// Now Working Mobile Components
////
//// ## Mission
////
//// Provides mobile-specific views for Now Working:
//// - Mini-bar: Sticky bar at bottom showing aggregated session info
//// - Panel sheet: Bottom sheet with NOW WORKING and CLAIMED sections
////
//// ## Mobile Philosophy (from Brief)
////
//// "Mobile: no se muestra el Pool; solo My Bar + lista Now Working + acciones rápidas"
//// - Desktop: explore, choose, organize
//// - Mobile: execute, track (tactical, quick actions)
////
//// ## Relations
////
//// - **client_view.gleam**: Uses these components in mobile layout
//// - **features/now_working/panel.gleam**: Desktop panel component

import gleam/int
import gleam/list
import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, h3, hr, span, text}
import lustre/event

import domain/task.{type Task, ActiveTask, Task}
import domain/task_status.{Claimed, Taken}

import scrumbringer_client/client_ffi
import scrumbringer_client/client_state.{
  type Model, type Msg, Loaded, MemberCompleteClicked,
  MemberNowWorkingPauseClicked, MemberNowWorkingStartClicked, MemberPanelToggled,
  MemberReleaseClicked, pool_msg,
}
import scrumbringer_client/features/admin/view as admin_view
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/icons
import scrumbringer_client/update_helpers

// =============================================================================
// Mini-Bar (Sticky Bottom)
// =============================================================================

/// Sticky mini-bar at bottom of mobile screen.
/// Shows "Now Working (N)" with aggregated timer.
pub fn view_mini_bar(model: Model) -> Element(Msg) {
  let active_sessions = get_active_sessions(model)
  let count = list.length(active_sessions)
  let total_time = aggregate_session_time(model, active_sessions)

  let expand_icon = case model.member.member_panel_expanded {
    True -> "▼"
    False -> "▲"
  }

  div(
    [
      attribute.class("member-mini-bar"),
      event.on_click(pool_msg(MemberPanelToggled)),
    ],
    [
      span([attribute.class("member-mini-bar-expand")], [text(expand_icon)]),
      div([attribute.class("member-mini-bar-status")], [
        span([attribute.class("member-mini-bar-label")], [
          text(
            update_helpers.i18n_t(model, i18n_text.NowWorking)
            <> " ("
            <> int.to_string(count)
            <> ")",
          ),
        ]),
        case count > 0 {
          True ->
            span([attribute.class("member-mini-bar-timer")], [
              text(total_time),
            ])
          False -> element.none()
        },
      ]),
    ],
  )
}

// =============================================================================
// Panel Sheet (Bottom Sheet)
// =============================================================================

/// Bottom sheet with NOW WORKING and CLAIMED sections.
/// Appears when mini-bar is tapped.
pub fn view_panel_sheet(model: Model, user_id: Int) -> Element(Msg) {
  let active_sessions = get_active_sessions(model)
  let claimed_tasks = get_claimed_not_working(model, user_id, active_sessions)

  let sheet_class = case model.member.member_panel_expanded {
    True -> "member-panel-sheet open"
    False -> "member-panel-sheet"
  }

  div([attribute.class(sheet_class)], [
    // Handle for closing
    div(
      [
        attribute.class("member-panel-sheet-handle"),
        event.on_click(pool_msg(MemberPanelToggled)),
      ],
      [],
    ),
    div([attribute.class("member-panel-sheet-content")], [
      // Section 1: NOW WORKING (primary)
      div([attribute.class("sheet-section sheet-section-primary")], [
        h3([], [text(update_helpers.i18n_t(model, i18n_text.NowWorking))]),
        case active_sessions {
          [] ->
            div([attribute.class("sheet-empty")], [
              span([attribute.class("sheet-empty-icon")], [
                text(icons.emoji_to_string(icons.Clock)),
              ]),
              text(update_helpers.i18n_t(model, i18n_text.NowWorkingNone)),
            ])
          _ ->
            div(
              [],
              list.map(active_sessions, fn(session) {
                view_session_row(model, session)
              }),
            )
        },
      ]),
      // Divider
      hr([attribute.class("sheet-divider")]),
      // Section 2: CLAIMED (secondary)
      div([attribute.class("sheet-section")], [
        h3([], [text(update_helpers.i18n_t(model, i18n_text.MyTasks))]),
        case claimed_tasks {
          [] ->
            div([attribute.class("sheet-empty")], [
              span([attribute.class("sheet-empty-icon")], [
                text(icons.emoji_to_string(icons.Hand)),
              ]),
              text(update_helpers.i18n_t(model, i18n_text.NoClaimedTasks)),
            ])
          _ ->
            div(
              [],
              list.map(claimed_tasks, fn(task) { view_claimed_row(model, task) }),
            )
        },
      ]),
    ]),
  ])
}

/// Overlay that appears behind the sheet when expanded.
pub fn view_overlay(model: Model) -> Element(Msg) {
  case model.member.member_panel_expanded {
    True ->
      div(
        [
          attribute.class("member-panel-overlay visible"),
          event.on_click(pool_msg(MemberPanelToggled)),
        ],
        [],
      )
    False -> element.none()
  }
}

// =============================================================================
// Row Components
// =============================================================================

/// Row for an active work session (NOW WORKING section).
/// Actions: Pause, Complete
fn view_session_row(model: Model, session: SessionInfo) -> Element(Msg) {
  let SessionInfo(
    task_id: task_id,
    title: title,
    icon: icon,
    elapsed: elapsed,
    version: version,
  ) = session
  let disable_actions =
    model.member.member_task_mutation_in_flight
    || model.member.member_now_working_in_flight

  div([attribute.class("session-row")], [
    span([attribute.class("session-icon")], [
      admin_view.view_task_type_icon_inline(icon, 18, model.ui.theme),
    ]),
    span([attribute.class("session-title")], [text(title)]),
    span([attribute.class("session-timer")], [text(elapsed)]),
    div([attribute.class("session-actions")], [
      button(
        [
          attribute.class("btn-action"),
          attribute.attribute(
            "title",
            update_helpers.i18n_t(model, i18n_text.Pause),
          ),
          attribute.disabled(disable_actions),
          event.on_click(pool_msg(MemberNowWorkingPauseClicked)),
        ],
        [icons.nav_icon(icons.Pause, icons.Small)],
      ),
      button(
        [
          attribute.class("btn-action btn-complete"),
          attribute.attribute(
            "title",
            update_helpers.i18n_t(model, i18n_text.Complete),
          ),
          attribute.disabled(disable_actions),
          event.on_click(pool_msg(MemberCompleteClicked(task_id, version))),
        ],
        [icons.nav_icon(icons.Check, icons.Small)],
      ),
    ]),
  ])
}

/// Row for a claimed (paused) task (CLAIMED section).
/// Actions: Start, Release
fn view_claimed_row(model: Model, task: Task) -> Element(Msg) {
  let Task(id: id, title: title, task_type: task_type, version: version, ..) =
    task
  let disable_actions =
    model.member.member_task_mutation_in_flight
    || model.member.member_now_working_in_flight

  div([attribute.class("claimed-row")], [
    span([attribute.class("claimed-icon")], [
      admin_view.view_task_type_icon_inline(task_type.icon, 18, model.ui.theme),
    ]),
    span([attribute.class("claimed-title")], [text(title)]),
    div([attribute.class("claimed-actions")], [
      button(
        [
          attribute.class("btn-action btn-start"),
          attribute.attribute(
            "title",
            update_helpers.i18n_t(model, i18n_text.Start),
          ),
          attribute.disabled(disable_actions),
          event.on_click(pool_msg(MemberNowWorkingStartClicked(id))),
        ],
        [icons.nav_icon(icons.Play, icons.Small)],
      ),
      button(
        [
          attribute.class("btn-action"),
          attribute.attribute(
            "title",
            update_helpers.i18n_t(model, i18n_text.Release),
          ),
          attribute.disabled(disable_actions),
          event.on_click(pool_msg(MemberReleaseClicked(id, version))),
        ],
        [icons.nav_icon(icons.Return, icons.Small)],
      ),
    ]),
  ])
}

// =============================================================================
// Types & Helpers
// =============================================================================

/// Info about an active work session.
type SessionInfo {
  SessionInfo(
    task_id: Int,
    title: String,
    icon: String,
    elapsed: String,
    version: Int,
  )
}

/// Get all active work sessions with their display info.
fn get_active_sessions(model: Model) -> List(SessionInfo) {
  case update_helpers.now_working_active_task(model) {
    opt.None -> []
    opt.Some(ActiveTask(
      task_id: task_id,
      started_at: started_at,
      accumulated_s: accumulated_s,
      ..,
    )) -> {
      let task_info =
        update_helpers.find_task_by_id(model.member.member_tasks, task_id)
      let #(title, icon, version) = case task_info {
        opt.Some(Task(title: t, task_type: tt, version: v, ..)) -> #(
          t,
          tt.icon,
          v,
        )
        opt.None -> #(
          update_helpers.i18n_t(model, i18n_text.TaskNumber(task_id)),
          "",
          0,
        )
      }
      let elapsed = calculate_elapsed(model, started_at, accumulated_s)
      [SessionInfo(task_id, title, icon, elapsed, version)]
    }
  }
}

/// Get claimed tasks that are NOT currently being worked on.
fn get_claimed_not_working(
  model: Model,
  user_id: Int,
  active_sessions: List(SessionInfo),
) -> List(Task) {
  let active_ids =
    list.map(active_sessions, fn(s) {
      let SessionInfo(task_id: id, ..) = s
      id
    })

  case model.member.member_tasks {
    Loaded(tasks) ->
      tasks
      |> list.filter(fn(t) {
        let Task(id: id, status: status, claimed_by: claimed_by, ..) = t
        status == Claimed(Taken)
        && claimed_by == opt.Some(user_id)
        && !list.contains(active_ids, id)
      })
    _ -> []
  }
}

// Justification: nested case improves clarity for branching logic.
/// Calculate aggregated time for all active sessions.
fn aggregate_session_time(_model: Model, sessions: List(SessionInfo)) -> String {
  case sessions {
    [] -> "00:00"
    [SessionInfo(elapsed: elapsed, ..)] -> elapsed
    _ -> {
      // For multiple sessions, sum the times
      // For now, just show the first (since we only support 1 active)
      case sessions {
        [first, ..] -> {
          let SessionInfo(elapsed: elapsed, ..) = first
          elapsed
        }
        [] -> "00:00"
      }
    }
  }
}

/// Calculate elapsed time string for a session.
fn calculate_elapsed(
  model: Model,
  started_at: String,
  accumulated_s: Int,
) -> String {
  let started_ms = client_ffi.parse_iso_ms(started_at)
  let local_now_ms = client_ffi.now_ms()
  let server_now_ms = local_now_ms - model.member.now_working_server_offset_ms
  update_helpers.now_working_elapsed_from_ms(
    accumulated_s,
    started_ms,
    server_now_ms,
  )
}
