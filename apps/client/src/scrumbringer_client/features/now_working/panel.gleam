//// Now Working Panel Component
////
//// ## Mission
////
//// Provides the "En curso" (Now Working) section view component for the
//// persistent right panel. Supports multiple concurrent active work sessions.
////
//// ## Responsibilities
////
//// - Now Working section rendering (multiple active tasks with timers)
//// - Elapsed time calculation for each active work session
//// - Empty state when no tasks are in progress
////
//// ## Non-responsibilities
////
//// - Full right panel assembly (see client_view.gleam)
//// - My Tasks dropzone (see pool/view.gleam)
////
//// ## Relations
////
//// - **client_view.gleam**: Uses this for unified right panel
//// - **pool/view.gleam**: Uses this for pool right panel

import gleam/int
import gleam/list
import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, h3, span, text}
import lustre/event

import domain/task.{type WorkSession, Task, WorkSession}

import scrumbringer_client/client_ffi
import scrumbringer_client/client_state.{
  type Model, type Msg, MemberCompleteClicked, MemberNowWorkingPauseClicked,
  pool_msg,
}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/error_banner
import scrumbringer_client/ui/icons
import scrumbringer_client/update_helpers

// =============================================================================
// Now Working Section View
// =============================================================================

/// Now Working section within the right panel.
/// Shows all active tasks with their timers, or empty state.
pub fn view(model: Model) -> Element(Msg) {
  let error_el = case model.member.member_now_working_error {
    opt.Some(err) -> error_banner.view(err)
    opt.None -> element.none()
  }

  let sessions = update_helpers.now_working_all_sessions(model)
  let session_count = list.length(sessions)

  // Header with count if multiple sessions
  let header_text = case session_count {
    0 | 1 -> update_helpers.i18n_t(model, i18n_text.NowWorking)
    n ->
      update_helpers.i18n_t(model, i18n_text.NowWorking)
      <> " ("
      <> int.to_string(n)
      <> ")"
  }

  div([], [
    h3([], [text(header_text)]),
    case sessions {
      [] ->
        // Empty state
        div([attribute.class("now-working-section")], [
          div([attribute.class("now-working-empty")], [
            span([attribute.class("now-working-empty-icon")], [
              text(icons.emoji_to_string(icons.Clock)),
            ]),
            span([], [
              text(update_helpers.i18n_t(model, i18n_text.NowWorkingNone)),
            ]),
          ]),
          error_el,
        ])

      _ ->
        // One or more active sessions
        div(
          [
            attribute.class(
              "now-working-section now-working-active now-working-multi",
            ),
          ],
          [
            div(
              [attribute.class("now-working-sessions")],
              list.map(sessions, fn(session) { view_session(model, session) }),
            ),
            error_el,
          ],
        )
    },
  ])
}

/// Render a single work session with its timer and actions.
fn view_session(model: Model, session: WorkSession) -> Element(Msg) {
  let WorkSession(task_id: task_id, ..) = session

  let task_info = update_helpers.find_task_by_id(model.member.member_tasks, task_id)
  let title = case task_info {
    opt.Some(Task(title: t, ..)) -> t
    opt.None -> update_helpers.i18n_t(model, i18n_text.TaskNumber(task_id))
  }

  let elapsed = session_elapsed(model, session)
  let disable_actions =
    model.member.member_task_mutation_in_flight || model.member.member_now_working_in_flight

  div([attribute.class("now-working-session-item")], [
    div([attribute.class("now-working-task-title")], [text(title)]),
    div([attribute.class("now-working-timer")], [text(elapsed)]),
    div([attribute.class("now-working-actions")], [
      button(
        [
          attribute.class("btn-xs btn-icon"),
          attribute.disabled(disable_actions),
          attribute.attribute(
            "title",
            update_helpers.i18n_t(model, i18n_text.Pause),
          ),
          event.on_click(pool_msg(MemberNowWorkingPauseClicked)),
        ],
        [icons.nav_icon(icons.Pause, icons.Small)],
      ),
      ..case task_info {
        opt.Some(Task(version: version, ..)) -> [
          button(
            [
              attribute.class("btn-xs btn-icon"),
              attribute.disabled(disable_actions),
              attribute.attribute(
                "title",
                update_helpers.i18n_t(model, i18n_text.Complete),
              ),
              event.on_click(pool_msg(MemberCompleteClicked(task_id, version))),
            ],
            [icons.nav_icon(icons.Check, icons.Small)],
          ),
        ]
        opt.None -> []
      }
    ]),
  ])
}

// =============================================================================
// Helpers
// =============================================================================

/// Calculate elapsed time for a specific work session.
fn session_elapsed(model: Model, session: WorkSession) -> String {
  let WorkSession(started_at: started_at, accumulated_s: accumulated_s, ..) =
    session
  let started_ms = client_ffi.parse_iso_ms(started_at)
  let local_now_ms = client_ffi.now_ms()
  let server_now_ms = local_now_ms - model.member.now_working_server_offset_ms
  update_helpers.now_working_elapsed_from_ms(
    accumulated_s,
    started_ms,
    server_now_ms,
  )
}
