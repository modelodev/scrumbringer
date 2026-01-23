//// Now Working Panel Component
////
//// ## Mission
////
//// Provides the "En curso" (Now Working) section view component for the
//// persistent right panel. Extracted to avoid circular imports between
//// client_view.gleam and pool/view.gleam.
////
//// ## Responsibilities
////
//// - Now Working section rendering (active task with timer or empty state)
//// - Elapsed time calculation for active work sessions
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

import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, h3, span, text}
import lustre/event

import domain/task.{ActiveTask, Task}

import scrumbringer_client/client_ffi
import scrumbringer_client/client_state.{
  type Model, type Msg,
  MemberCompleteClicked, MemberNowWorkingPauseClicked,
  MemberReleaseClicked,
}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/icons
import scrumbringer_client/update_helpers

// =============================================================================
// Now Working Section View
// =============================================================================

/// Now Working section within the right panel.
/// Shows active task with timer or empty state.
pub fn view(model: Model) -> Element(Msg) {
  let error_el = case model.member_now_working_error {
    opt.Some(err) ->
      div([attribute.class("error-banner")], [
        span([attribute.class("error-banner-icon")], [icons.nav_icon(icons.Warning, icons.Small)]),
        span([], [text(err)]),
      ])
    opt.None -> element.none()
  }

  div([], [
    h3([], [text(update_helpers.i18n_t(model, i18n_text.NowWorking))]),
    case update_helpers.now_working_active_task(model) {
      opt.None ->
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

      opt.Some(ActiveTask(task_id: task_id, ..)) -> {
        let task_info = update_helpers.find_task_by_id(model.member_tasks, task_id)
        let title = case task_info {
          opt.Some(Task(title: t, ..)) -> t
          opt.None -> update_helpers.i18n_t(model, i18n_text.TaskNumber(task_id))
        }

        let elapsed = now_working_elapsed(model)
        let disable_actions =
          model.member_task_mutation_in_flight
          || model.member_now_working_in_flight

        div([attribute.class("now-working-section now-working-active")], [
          div([attribute.class("now-working-task-title")], [text(title)]),
          div([attribute.class("now-working-timer")], [text(elapsed)]),
          div([attribute.class("now-working-actions")], [
            button(
              [
                attribute.class("btn-xs"),
                attribute.disabled(disable_actions),
                event.on_click(MemberNowWorkingPauseClicked),
              ],
              [text(update_helpers.i18n_t(model, i18n_text.Pause))],
            ),
            ..case task_info {
              opt.Some(Task(version: version, ..)) -> [
                button(
                  [
                    attribute.class("btn-xs"),
                    attribute.disabled(disable_actions),
                    event.on_click(MemberCompleteClicked(task_id, version)),
                  ],
                  [text(update_helpers.i18n_t(model, i18n_text.Complete))],
                ),
                button(
                  [
                    attribute.class("btn-xs"),
                    attribute.disabled(disable_actions),
                    event.on_click(MemberReleaseClicked(task_id, version)),
                  ],
                  [text(update_helpers.i18n_t(model, i18n_text.Release))],
                ),
              ]
              opt.None -> []
            }
          ]),
          error_el,
        ])
      }
    },
  ])
}

// =============================================================================
// Helpers
// =============================================================================

/// Calculate elapsed time for the active task.
fn now_working_elapsed(model: Model) -> String {
  case update_helpers.now_working_active_task(model) {
    opt.None -> "00:00"

    opt.Some(ActiveTask(
      started_at: started_at,
      accumulated_s: accumulated_s,
      ..,
    )) -> {
      let started_ms = client_ffi.parse_iso_ms(started_at)
      let local_now_ms = client_ffi.now_ms()
      let server_now_ms = local_now_ms - model.now_working_server_offset_ms
      update_helpers.now_working_elapsed_from_ms(
        accumulated_s,
        started_ms,
        server_now_ms,
      )
    }
  }
}
