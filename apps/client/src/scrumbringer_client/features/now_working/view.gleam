//// Now Working panel views for active task tracking.
////
//// ## Mission
////
//// Renders the "Now Working" panel showing the currently active task,
//// elapsed time, and controls for pausing/completing/releasing work.
////
//// ## Responsibilities
////
//// - Timer display with elapsed time calculation
//// - Active task state display (Loading, Loaded, Failed, NotAsked)
//// - Start/pause/complete/release action buttons
//// - Error message display
////
//// ## Non-responsibilities
////
//// - Task state management (see client_state.gleam)
//// - Timer tick effects (see client_update.gleam)
//// - API calls (see api/ modules)
////
//// ## Relations
////
//// - **client_view.gleam**: Main view imports this for member page
//// - **client_state.gleam**: Provides Model and Msg types
//// - **update_helpers.gleam**: Provides elapsed time calculation
////
//// ## Line Count Justification
////
//// Handles 4 distinct states (Loading, Loaded with/without task, Failed,
//// NotAsked) plus conditional rendering for timer, buttons, and errors.
//// The view logic is tightly coupled to the active task state machine.

import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, text}
import lustre/event

import domain/task.{ActiveTask, Task}

import scrumbringer_client/client_ffi
import scrumbringer_client/client_state.{
  type Model, type Msg, Failed, Loaded, Loading, MemberCompleteClicked,
  MemberNowWorkingPauseClicked, MemberReleaseClicked, NotAsked,
}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/update_helpers

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

/// Renders the "Now Working" panel showing active task timer and controls.
pub fn view_panel(model: Model) -> Element(Msg) {
  let error = case model.member_now_working_error {
    opt.Some(err) -> div([attribute.class("now-working-error")], [text(err)])
    opt.None -> element.none()
  }

  case model.member_active_task {
    Loading ->
      div([attribute.class("now-working")], [
        text(update_helpers.i18n_t(model, i18n_text.NowWorkingLoading)),
      ])

    Failed(err) ->
      div([attribute.class("now-working")], [
        div([attribute.class("now-working-error")], [
          text(
            update_helpers.i18n_t(model, i18n_text.NowWorkingErrorPrefix)
            <> err.message,
          ),
        ]),
      ])

    NotAsked | Loaded(_) -> {
      let active = update_helpers.now_working_active_task(model)

      case active {
        opt.None ->
          div([attribute.class("now-working")], [
            div([attribute.class("now-working-empty")], [
              text(update_helpers.i18n_t(model, i18n_text.NowWorkingNone)),
            ]),
            error,
          ])

        opt.Some(ActiveTask(task_id: task_id, ..)) -> {
          let title = case
            update_helpers.find_task_by_id(model.member_tasks, task_id)
          {
            opt.Some(Task(title: title, ..)) -> title
            opt.None ->
              update_helpers.i18n_t(model, i18n_text.TaskNumber(task_id))
          }

          let disable_actions =
            model.member_task_mutation_in_flight
            || model.member_now_working_in_flight

          let pause_action =
            button(
              [
                attribute.class("btn-xs"),
                attribute.disabled(disable_actions),
                event.on_click(MemberNowWorkingPauseClicked),
              ],
              [text(update_helpers.i18n_t(model, i18n_text.Pause))],
            )

          let task_actions = case
            update_helpers.find_task_by_id(model.member_tasks, task_id)
          {
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

          div([attribute.class("now-working")], [
            div([], [
              div([attribute.class("now-working-title")], [text(title)]),
              div([attribute.class("now-working-timer")], [
                text(now_working_elapsed(model)),
              ]),
            ]),
            div([attribute.class("now-working-actions")], [
              pause_action,
              ..task_actions
            ]),
            error,
          ])
        }
      }
    }
  }
}
