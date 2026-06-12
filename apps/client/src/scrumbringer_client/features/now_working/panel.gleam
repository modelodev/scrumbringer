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
import lustre/element/html.{div, h3, text}

import domain/remote.{type Remote}
import domain/task.{type Task, type WorkSession, Task, WorkSession}
import domain/task_status.{Claimed, Ongoing}

import scrumbringer_client/client_ffi
import scrumbringer_client/helpers/lookup as helpers_lookup
import scrumbringer_client/helpers/time as helpers_time
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/empty_state
import scrumbringer_client/ui/error_notice

import scrumbringer_client/ui/task_actions
import scrumbringer_client/ui/task_item
import scrumbringer_client/ui/task_state as task_state_ui

pub type Config(msg) {
  Config(
    locale: Locale,
    sessions: List(WorkSession),
    tasks: Remote(List(Task)),
    server_offset_ms: Int,
    error: opt.Option(String),
    disable_actions: Bool,
    on_pause: msg,
    on_complete: fn(Int, Int) -> msg,
  )
}

// =============================================================================
// Now Working Section View
// =============================================================================

/// Now Working section within the right panel.
/// Shows all active tasks with their timers, or empty state.
pub fn view(config: Config(msg)) -> Element(msg) {
  let error_el = case config.error {
    opt.Some(err) -> error_notice.view(err)
    opt.None -> element.none()
  }

  let sessions = config.sessions
  let session_count = list.length(sessions)

  // Header with count if multiple sessions
  let header_text = case session_count {
    0 | 1 -> i18n.t(config.locale, i18n_text.NowWorking)
    n ->
      i18n.t(config.locale, i18n_text.NowWorking)
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
            empty_state.simple(
              "clock",
              i18n.t(config.locale, i18n_text.NowWorkingNone),
            ),
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
              list.map(sessions, fn(session) { view_session(config, session) }),
            ),
            error_el,
          ],
        )
    },
  ])
}

/// Render a single work session with its timer and actions.
fn view_session(config: Config(msg), session: WorkSession) -> Element(msg) {
  let WorkSession(task_id: task_id, ..) = session

  let task_info = helpers_lookup.find_task_by_id(config.tasks, task_id)
  let title = case task_info {
    opt.Some(Task(title: t, ..)) -> t
    opt.None -> i18n.t(config.locale, i18n_text.TaskNumber(task_id))
  }

  let elapsed = session_elapsed(config.server_offset_ms, session)

  let actions = case task_info {
    opt.Some(Task(version: version, ..)) ->
      task_actions.pause_and_complete(
        task_state_ui.next_action(config.locale, Claimed(Ongoing)),
        config.on_pause,
        task_state_ui.complete_action(config.locale),
        config.on_complete(task_id, version),
        action_buttons.SizeXs,
        config.disable_actions,
        "",
        "",
        opt.None,
        opt.None,
        opt.None,
        opt.None,
      )
    opt.None -> []
  }

  task_item.view(
    task_item.Config(
      container_class: "now-working-session-item",
      content_class: "now-working-task-title",
      leading: opt.None,
      on_click: opt.None,
      content_title: opt.None,
      content_label: opt.None,
      icon: opt.None,
      icon_class: opt.None,
      title: title,
      title_class: opt.Some("now-working-task-title"),
      secondary: div(
        [
          attribute.class("now-working-timer"),
          attribute.attribute(
            "title",
            task_state_ui.hint(config.locale, Claimed(Ongoing)),
          ),
        ],
        [text(elapsed)],
      ),
      actions: [div([attribute.class("now-working-actions")], actions)],
      reserve_actions_slot: False,
      action_slot_class: opt.None,
      testid: opt.None,
    ),
    task_item.Div,
  )
}

// =============================================================================
// Helpers
// =============================================================================

/// Calculate elapsed time for a specific work session.
fn session_elapsed(server_offset_ms: Int, session: WorkSession) -> String {
  let WorkSession(started_at: started_at, accumulated_s: accumulated_s, ..) =
    session
  let started_ms = client_ffi.parse_iso_ms(started_at)
  let local_now_ms = client_ffi.now_ms()
  let server_now_ms = local_now_ms - server_offset_ms
  helpers_time.now_working_elapsed_from_ms(
    accumulated_s,
    started_ms,
    server_now_ms,
  )
}
