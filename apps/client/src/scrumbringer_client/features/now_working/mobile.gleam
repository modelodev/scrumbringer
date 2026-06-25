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

import domain/remote.{type Remote, Loaded}
import domain/task as domain_task
import domain/task/state as task_execution_state
import domain/task_status.{Claimed, Ongoing, Taken}

import scrumbringer_client/client_ffi
import scrumbringer_client/helpers/time as helpers_time
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/theme.{type Theme}
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/empty_state
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/task_item
import scrumbringer_client/ui/task_state as task_state_ui
import scrumbringer_client/ui/task_type_icon

pub type Config(msg) {
  Config(
    locale: Locale,
    theme: Theme,
    panel_expanded: Bool,
    user_id: Int,
    tasks: Remote(List(domain_task.Task)),
    active_sessions: List(domain_task.WorkSession),
    server_offset_ms: Int,
    disable_actions: Bool,
    on_panel_toggled: msg,
    on_pause: msg,
    on_complete: fn(Int, Int) -> msg,
    on_start: fn(Int) -> msg,
    on_release: fn(Int, Int) -> msg,
  )
}

// =============================================================================
// Mini-Bar (Sticky Bottom)
// =============================================================================

/// Sticky mini-bar at bottom of mobile screen.
/// Shows "Now Working (N)" with aggregated timer.
pub fn view_mini_bar(config: Config(msg)) -> Element(msg) {
  let active_sessions = get_active_sessions(config)
  let count = list.length(active_sessions)
  let total_time = aggregate_session_time(active_sessions)

  let expand_icon = case config.panel_expanded {
    True -> "▼"
    False -> "▲"
  }

  button(
    [
      attribute.class("member-mini-bar"),
      attribute.type_("button"),
      event.on_click(config.on_panel_toggled),
    ],
    [
      span([attribute.class("member-mini-bar-expand")], [text(expand_icon)]),
      div([attribute.class("member-mini-bar-status")], [
        span([attribute.class("member-mini-bar-label")], [
          text(
            i18n.t(config.locale, i18n_text.NowWorking)
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
pub fn view_panel_sheet(config: Config(msg)) -> Element(msg) {
  case config.panel_expanded {
    False -> element.none()
    True -> view_open_panel_sheet(config)
  }
}

fn view_open_panel_sheet(config: Config(msg)) -> Element(msg) {
  let active_sessions = get_active_sessions(config)
  let claimed_tasks = get_claimed_not_working(config, active_sessions)

  div(
    [
      attribute.class("member-panel-sheet open"),
      attribute.attribute("role", "dialog"),
      attribute.attribute("aria-modal", "true"),
      attribute.attribute(
        "aria-label",
        i18n.t(config.locale, i18n_text.NowWorking),
      ),
    ],
    [
      // Handle for closing
      div(
        [
          attribute.class("member-panel-sheet-handle"),
          event.on_click(config.on_panel_toggled),
        ],
        [],
      ),
      div([attribute.class("member-panel-sheet-content")], [
        // Section 1: NOW WORKING (primary)
        div([attribute.class("sheet-section sheet-section-primary")], [
          h3([], [text(i18n.t(config.locale, i18n_text.NowWorking))]),
          case active_sessions {
            [] ->
              div([attribute.class("sheet-empty")], [
                empty_state.simple(
                  "clock",
                  i18n.t(config.locale, i18n_text.NowWorkingNone),
                ),
              ])
            _ ->
              div(
                [],
                list.map(active_sessions, fn(session) {
                  view_session_row(config, session)
                }),
              )
          },
        ]),
        // Divider
        hr([attribute.class("sheet-divider")]),
        // Section 2: CLAIMED (secondary)
        div([attribute.class("sheet-section")], [
          h3([], [text(i18n.t(config.locale, i18n_text.MyTasks))]),
          case claimed_tasks {
            [] ->
              div([attribute.class("sheet-empty")], [
                empty_state.simple(
                  "hand-raised",
                  i18n.t(config.locale, i18n_text.NoClaimedTasks),
                ),
              ])
            _ ->
              div(
                [],
                list.map(claimed_tasks, fn(task) {
                  view_claimed_row(config, task)
                }),
              )
          },
        ]),
      ]),
    ],
  )
}

/// Overlay that appears behind the sheet when expanded.
pub fn view_overlay(config: Config(msg)) -> Element(msg) {
  case config.panel_expanded {
    True ->
      div(
        [
          attribute.class("member-panel-overlay visible"),
          event.on_click(config.on_panel_toggled),
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
fn view_session_row(config: Config(msg), session: SessionInfo) -> Element(msg) {
  let SessionInfo(
    task_id: task_id,
    title: title,
    icon: icon,
    elapsed: elapsed,
    version: version,
  ) = session

  let actions = [
    action_buttons.task_icon_button_with_class(
      task_state_ui.next_action(config.locale, Claimed(Ongoing)),
      config.on_pause,
      icons.Pause,
      icons.Small,
      config.disable_actions,
      "btn-action",
      opt.None,
      opt.None,
    ),
    action_buttons.task_icon_button_with_class(
      task_state_ui.complete_action(config.locale),
      config.on_complete(task_id, version),
      icons.Check,
      icons.Small,
      config.disable_actions,
      "btn-action btn-complete",
      opt.None,
      opt.None,
    ),
  ]

  task_item.view(
    task_item.Config(
      container_class: "session-row",
      content_class: "session-row-content",
      leading: opt.None,
      on_click: opt.None,
      content_title: opt.None,
      content_label: opt.None,
      icon: opt.Some(task_type_icon.view(icon, 18, config.theme)),
      icon_class: opt.Some("session-icon"),
      title: title,
      title_class: opt.Some("session-title"),
      secondary: span(
        [
          attribute.class("session-timer"),
          attribute.attribute(
            "title",
            task_state_ui.hint(config.locale, Claimed(Ongoing)),
          ),
        ],
        [text(elapsed)],
      ),
      actions: [div([attribute.class("session-actions")], actions)],
      reserve_actions_slot: False,
      action_slot_class: opt.None,
      content_testid: opt.None,
      testid: opt.None,
    ),
    task_item.Div,
  )
}

/// Row for a claimed (paused) task (CLAIMED section).
/// Actions: Start, Release
fn view_claimed_row(config: Config(msg), task: domain_task.Task) -> Element(msg) {
  let domain_task.Task(
    id: id,
    title: title,
    task_type: task_type,
    version: version,
    ..,
  ) = task

  let actions = [
    action_buttons.task_icon_button_with_class(
      task_state_ui.next_action(config.locale, Claimed(Taken)),
      config.on_start(id),
      icons.Play,
      icons.Small,
      config.disable_actions,
      "btn-action btn-start",
      opt.None,
      opt.None,
    ),
    action_buttons.task_icon_button_with_class(
      task_state_ui.release_action(config.locale),
      config.on_release(id, version),
      icons.Return,
      icons.Small,
      config.disable_actions,
      "btn-action",
      opt.None,
      opt.None,
    ),
  ]

  task_item.view(
    task_item.Config(
      container_class: "claimed-row",
      content_class: "claimed-row-content",
      leading: opt.None,
      on_click: opt.None,
      content_title: opt.None,
      content_label: opt.None,
      icon: opt.Some(task_type_icon.view(task_type.icon, 18, config.theme)),
      icon_class: opt.Some("claimed-icon"),
      title: title,
      title_class: opt.Some("claimed-title"),
      secondary: span([attribute.class("claimed-state-hint")], [
        text(task_state_ui.hint(config.locale, Claimed(Taken))),
      ]),
      actions: [div([attribute.class("claimed-actions")], actions)],
      reserve_actions_slot: False,
      action_slot_class: opt.None,
      content_testid: opt.None,
      testid: opt.None,
    ),
    task_item.Div,
  )
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
fn get_active_sessions(config: Config(msg)) -> List(SessionInfo) {
  config.active_sessions
  |> list.map(fn(session) {
    let domain_task.WorkSession(
      task_id: task_id,
      started_at: started_at,
      accumulated_s: accumulated_s,
    ) = session
    let task_info = find_task_by_id(config.tasks, task_id)
    let #(title, icon, version) = case task_info {
      opt.Some(domain_task.Task(title: t, task_type: tt, version: v, ..)) -> #(
        t,
        tt.icon,
        v,
      )
      opt.None -> #(i18n.t(config.locale, i18n_text.TaskNumber(task_id)), "", 0)
    }
    let elapsed =
      calculate_elapsed(config.server_offset_ms, started_at, accumulated_s)
    SessionInfo(task_id, title, icon, elapsed, version)
  })
}

/// Get claimed tasks that are NOT currently being worked on.
fn get_claimed_not_working(
  config: Config(msg),
  active_sessions: List(SessionInfo),
) -> List(domain_task.Task) {
  let active_ids =
    list.map(active_sessions, fn(s) {
      let SessionInfo(task_id: id, ..) = s
      id
    })

  case config.tasks {
    Loaded(tasks) ->
      tasks
      |> list.filter(fn(t) {
        case t.state {
          task_execution_state.Claimed(
            claimed_by: claimed_by,
            mode: task_execution_state.Taken,
            ..,
          ) -> claimed_by == config.user_id && !list.contains(active_ids, t.id)
          _ -> False
        }
      })
    _ -> []
  }
}

/// Calculate aggregated time for all active sessions.
fn aggregate_session_time(sessions: List(SessionInfo)) -> String {
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
  server_offset_ms: Int,
  started_at: String,
  accumulated_s: Int,
) -> String {
  let started_ms = client_ffi.parse_iso_ms(started_at)
  let local_now_ms = client_ffi.now_ms()
  let server_now_ms = local_now_ms - server_offset_ms
  helpers_time.now_working_elapsed_from_ms(
    accumulated_s,
    started_ms,
    server_now_ms,
  )
}

fn find_task_by_id(
  tasks: Remote(List(domain_task.Task)),
  task_id: Int,
) -> opt.Option(domain_task.Task) {
  case tasks {
    Loaded(items) ->
      case
        list.find(items, fn(task) {
          let domain_task.Task(id: id, ..) = task
          id == task_id
        })
      {
        Ok(task) -> opt.Some(task)
        Error(_) -> opt.None
      }
    _ -> opt.None
  }
}
