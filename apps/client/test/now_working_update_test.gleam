import gleam/option
import lustre/effect

import domain/api_error.{ApiError}
import domain/remote
import domain/task.{
  type WorkSession, type WorkSessionsPayload, WorkSessionsPayload,
}
import scrumbringer_client/client_state/member/metrics as member_metrics
import scrumbringer_client/client_state/member/now_working as member_now_working
import scrumbringer_client/features/now_working/update as now_working_update
import scrumbringer_client/features/pool/msg as pool_messages

fn model() -> now_working_update.Model {
  now_working_update.Model(
    now_working: member_now_working.default_model(),
    metrics: member_metrics.default_model(),
  )
}

fn context() -> now_working_update.Context(Nil) {
  now_working_update.Context(
    on_session_started: fn(_result) { Nil },
    on_session_paused: fn(_result) { Nil },
    on_session_heartbeated: fn(_result) { Nil },
    on_tick: fn() { Nil },
    on_error_toast: fn(_message) { effect.from(fn(_dispatch) { Nil }) },
  )
}

fn payload(sessions: List(WorkSession)) -> WorkSessionsPayload {
  WorkSessionsPayload(active_sessions: sessions, as_of: "2026-01-01T10:00:00Z")
}

pub fn start_clicked_ignores_in_flight_state_test() {
  let initial =
    now_working_update.Model(
      ..model(),
      now_working: member_now_working.Model(
        ..member_now_working.default_model(),
        member_now_working_in_flight: True,
      ),
    )

  let #(next, fx) =
    now_working_update.handle_start_clicked(initial, 5, context())

  let assert True = next.now_working.member_now_working_in_flight
  let assert True = fx == effect.none()
}

pub fn pause_clicked_without_active_session_is_noop_test() {
  let #(next, fx) = now_working_update.handle_pause_clicked(model(), context())

  let assert True = next == model()
  let assert True = fx == effect.none()
}

pub fn tick_without_active_session_stops_running_test() {
  let initial =
    now_working_update.Model(
      ..model(),
      now_working: member_now_working.Model(
        ..member_now_working.default_model(),
        now_working_tick_running: True,
      ),
    )

  let #(next, fx) = now_working_update.handle_ticked(initial, context())

  let assert 1 = next.now_working.now_working_tick
  let assert False = next.now_working.now_working_tick_running
  let assert True = fx == effect.none()
}

pub fn sessions_fetch_error_sets_failed_sessions_test() {
  let err = ApiError(status: 500, code: "SESSIONS", message: "Boom")

  let #(next, fx) =
    now_working_update.handle_sessions_fetched_error(model(), err)

  let assert True = next.metrics.member_work_sessions == remote.Failed(err)
  let assert True = fx == effect.none()
}

pub fn session_start_error_clears_in_flight_and_records_error_test() {
  let initial =
    now_working_update.Model(
      ..model(),
      now_working: member_now_working.Model(
        ..member_now_working.default_model(),
        member_now_working_in_flight: True,
      ),
    )
  let err = ApiError(status: 500, code: "START", message: "Cannot start")

  let #(next, fx) =
    now_working_update.handle_session_started_error(initial, err, context())

  let assert False = next.now_working.member_now_working_in_flight
  let assert True =
    next.now_working.member_now_working_error == option.Some("Cannot start")
  let assert False = fx == effect.none()
}

pub fn session_pause_error_clears_in_flight_and_records_error_test() {
  let initial =
    now_working_update.Model(
      ..model(),
      now_working: member_now_working.Model(
        ..member_now_working.default_model(),
        member_now_working_in_flight: True,
      ),
    )
  let err = ApiError(status: 500, code: "PAUSE", message: "Cannot pause")

  let #(next, fx) =
    now_working_update.handle_session_paused_error(initial, err, context())

  let assert False = next.now_working.member_now_working_in_flight
  let assert True =
    next.now_working.member_now_working_error == option.Some("Cannot pause")
  let assert False = fx == effect.none()
}

pub fn session_pause_success_with_no_sessions_stops_timer_test() {
  let initial =
    now_working_update.Model(
      ..model(),
      now_working: member_now_working.Model(
        ..member_now_working.default_model(),
        member_now_working_in_flight: True,
        now_working_tick_running: True,
      ),
    )

  let #(next, fx) =
    now_working_update.handle_session_paused_ok(initial, payload([]))

  let assert False = next.now_working.member_now_working_in_flight
  let assert False = next.now_working.now_working_tick_running
  let assert True =
    next.metrics.member_work_sessions == remote.Loaded(payload([]))
  let assert True = fx == effect.none()
}

pub fn try_update_sessions_fetch_error_checks_auth_before_local_update_test() {
  let err = ApiError(status: 401, code: "AUTH", message: "Expired")

  let assert option.Some(now_working_update.Update(
    next,
    fx,
    now_working_update.CheckAuthBefore(policy_err),
  )) =
    now_working_update.try_update(
      model(),
      pool_messages.MemberWorkSessionsFetched(Error(err)),
      context(),
    )

  let assert True = policy_err == err
  let assert True = next.metrics.member_work_sessions == remote.Failed(err)
  let assert True = fx == effect.none()
}

pub fn try_update_session_start_error_checks_auth_after_local_update_test() {
  let initial =
    now_working_update.Model(
      ..model(),
      now_working: member_now_working.Model(
        ..member_now_working.default_model(),
        member_now_working_in_flight: True,
      ),
    )
  let err = ApiError(status: 401, code: "AUTH", message: "Expired")

  let assert option.Some(now_working_update.Update(
    next,
    fx,
    now_working_update.CheckAuthAfter(policy_err),
  )) =
    now_working_update.try_update(
      initial,
      pool_messages.MemberWorkSessionStarted(Error(err)),
      context(),
    )

  let assert True = policy_err == err
  let assert False = next.now_working.member_now_working_in_flight
  let assert True =
    next.now_working.member_now_working_error == option.Some("Expired")
  let assert False = fx == effect.none()
}

pub fn try_update_ticked_handles_now_working_tick_without_auth_test() {
  let initial =
    now_working_update.Model(
      ..model(),
      now_working: member_now_working.Model(
        ..member_now_working.default_model(),
        now_working_tick_running: True,
      ),
    )

  let assert option.Some(now_working_update.Update(
    next,
    fx,
    now_working_update.NoAuthCheck,
  )) =
    now_working_update.try_update(
      initial,
      pool_messages.NowWorkingTicked,
      context(),
    )

  let assert 1 = next.now_working.now_working_tick
  let assert False = next.now_working.now_working_tick_running
  let assert True = fx == effect.none()
}

pub fn try_update_ignores_non_now_working_messages_test() {
  let assert option.None =
    now_working_update.try_update(
      model(),
      pool_messages.MemberPoolFiltersToggled,
      context(),
    )
}
