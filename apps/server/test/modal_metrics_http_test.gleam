import fixtures
import gleam/http
import gleam/int
import gleam/option
import gleam/string
import gleeunit
import pog
import scrumbringer_server/seed_db
import support/assertions as expect
import wisp/simulate

pub fn main() {
  gleeunit.main()
}

pub fn include_metrics_returns_metrics_payload_for_card_and_task_test() {
  let #(_db, handler, session, project_id, type_id) =
    fixtures.require_task_project("Core")
  let assert Ok(card_id) =
    fixtures.create_card(handler, session, project_id, "Metrics card")

  let assert Ok(task_id) =
    fixtures.create_task_with_card(
      handler,
      session,
      project_id,
      type_id,
      card_id,
      "Task for metrics",
    )

  let card_res = card_metrics_response(handler, session, card_id)
  expect.expect_status(card_res, 200)
  string.contains(simulate.read_body(card_res), "\"metrics\"")
  |> expect.is_true

  let task_res = task_metrics_response(handler, session, task_id)
  expect.expect_status(task_res, 200)
  string.contains(simulate.read_body(task_res), "\"metrics\"")
  |> expect.is_true
}

pub fn include_metrics_forbidden_uses_typed_error_code_test() {
  let #(db, handler, session, project_id) =
    fixtures.require_project_context("Core")
  let assert Ok(card_id) =
    fixtures.create_card(handler, session, project_id, "Card")

  let assert Ok(_) =
    fixtures.create_member_user(handler, db, "member@example.com", "inv_member")
  let assert Ok(member_session) =
    fixtures.login(handler, "member@example.com", "passwordpassword")

  let res = card_metrics_response(handler, member_session, card_id)

  expect.expect_status(res, 403)
  string.contains(simulate.read_body(res), "\"code\":\"forbidden\"")
  |> expect.is_true
}

pub fn include_metrics_task_forbidden_returns_not_found_typed_error_code_test() {
  let #(db, handler, session, project_id, type_id) =
    fixtures.require_task_project("Core")
  let assert Ok(task_id) =
    fixtures.create_task(
      handler,
      session,
      project_id,
      type_id,
      "Task forbidden",
    )

  let assert Ok(_member_id) =
    fixtures.create_member_user(
      handler,
      db,
      "member3@example.com",
      "inv_member",
    )
  let assert Ok(member_session) =
    fixtures.login(handler, "member3@example.com", "passwordpassword")

  let res = task_metrics_response(handler, member_session, task_id)

  expect.expect_status(res, 404)
  string.contains(simulate.read_body(res), "\"code\":\"not_found\"")
  |> expect.is_true
}

pub fn include_metrics_task_returns_expected_counts_test() {
  let #(db, handler, session, project_id, type_id) =
    fixtures.require_task_project("Core")
  let assert Ok(task_id) =
    fixtures.create_task(
      handler,
      session,
      project_id,
      type_id,
      "Task metrics exact",
    )

  let assert Ok(org_id) =
    fixtures.query_int(db, "select id from organizations limit 1", [])
  let assert Ok(admin_id) =
    fixtures.query_int(
      db,
      "select id from users where email = 'admin@example.com'",
      [],
    )

  let assert Ok(member_id) =
    fixtures.create_member_user(
      handler,
      db,
      "member4@example.com",
      "inv_member",
    )

  let _ =
    fixtures.insert_audit_event_db(
      db,
      org_id,
      project_id,
      task_id,
      admin_id,
      "task_claimed",
    )
  let _ =
    fixtures.insert_audit_event_db(
      db,
      org_id,
      project_id,
      task_id,
      admin_id,
      "task_released",
    )
  let _ =
    fixtures.insert_audit_event_db(
      db,
      org_id,
      project_id,
      task_id,
      member_id,
      "task_claimed",
    )

  let _ =
    pog.query(
      "update tasks set execution_state = 'claimed', claimed_mode = 'taken', claimed_by = $2, claimed_at = now(), pool_lifetime_s = 5400 where id = $1",
    )
    |> pog.parameter(pog.int(task_id))
    |> pog.parameter(pog.int(admin_id))
    |> pog.execute(db)

  let _ = fixtures.insert_work_session_db(db, admin_id, task_id, 120)
  let _ = fixtures.insert_work_session_db(db, member_id, task_id, 180)
  let _ =
    seed_db.insert_work_session_entry(
      db,
      seed_db.WorkSessionInsertOptions(
        user_id: admin_id,
        task_id: task_id,
        started_at: option.None,
        last_heartbeat_at: option.None,
        ended_at: option.Some("2026-02-08T00:00:00Z"),
        ended_reason: option.Some("manual"),
        created_at: option.Some("2026-02-08T00:00:00Z"),
      ),
    )
  let _ =
    seed_db.insert_work_session_entry(
      db,
      seed_db.WorkSessionInsertOptions(
        user_id: member_id,
        task_id: task_id,
        started_at: option.None,
        last_heartbeat_at: option.None,
        ended_at: option.Some("2026-02-08T00:10:00Z"),
        ended_reason: option.Some("manual"),
        created_at: option.Some("2026-02-08T00:10:00Z"),
      ),
    )

  let res = task_metrics_response(handler, session, task_id)

  expect.expect_status(res, 200)
  let body = simulate.read_body(res)

  let assert Ok(claim_count) =
    fixtures.query_int(
      db,
      "select count(*)::int from audit_events where task_id = $1 and event_type = 'task_claimed'",
      [pog.int(task_id)],
    )
  let assert Ok(release_count) =
    fixtures.query_int(
      db,
      "select count(*)::int from audit_events where task_id = $1 and event_type = 'task_released'",
      [pog.int(task_id)],
    )
  let assert Ok(unique_executors) =
    fixtures.query_int(
      db,
      "select count(distinct actor_user_id)::int from audit_events where task_id = $1 and event_type = 'task_claimed'",
      [pog.int(task_id)],
    )
  let assert Ok(session_count) =
    fixtures.query_int(
      db,
      "select count(*)::int from user_task_work_session where task_id = $1",
      [pog.int(task_id)],
    )
  let assert Ok(total_work_time_s) =
    fixtures.query_int(
      db,
      "select coalesce(sum(accumulated_s), 0)::int from user_task_work_total where task_id = $1",
      [pog.int(task_id)],
    )

  string.contains(body, "\"claim_count\":" <> int.to_string(claim_count))
  |> expect.is_true
  string.contains(body, "\"release_count\":" <> int.to_string(release_count))
  |> expect.is_true
  string.contains(
    body,
    "\"unique_executors\":" <> int.to_string(unique_executors),
  )
  |> expect.is_true
  string.contains(body, "\"pool_lifetime_s\":5400") |> expect.is_true
  string.contains(body, "\"session_count\":" <> int.to_string(session_count))
  |> expect.is_true
  string.contains(
    body,
    "\"total_work_time_s\":" <> int.to_string(total_work_time_s),
  )
  |> expect.is_true
  string.contains(body, "\"first_claim_at\":") |> expect.is_true
}

pub fn include_metrics_card_return_expected_counts_test() {
  let #(db, handler, session, project_id, type_id) =
    fixtures.require_task_project("Core")
  let assert Ok(card_id) =
    fixtures.create_card(handler, session, project_id, "Metrics count card")

  let assert Ok(task_id) =
    fixtures.create_task_with_card(
      handler,
      session,
      project_id,
      type_id,
      card_id,
      "Task for card metrics",
    )

  let _ =
    pog.query(
      "update tasks set execution_state = 'closed', closed_at = now(), closed_by = 1, closed_reason = 'done' where id = $1",
    )
    |> pog.parameter(pog.int(task_id))
    |> pog.execute(db)

  let card_res = card_metrics_response(handler, session, card_id)
  expect.expect_status(card_res, 200)
  let card_body = simulate.read_body(card_res)
  string.contains(card_body, "\"tasks_total\":1") |> expect.is_true
  string.contains(card_body, "\"tasks_closed\":1") |> expect.is_true
  string.contains(card_body, "\"tasks_percent\":100") |> expect.is_true
}

pub fn include_metrics_not_found_uses_typed_error_code_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()

  let res = task_metrics_response(handler, session, 999_999)

  expect.expect_status(res, 404)
  string.contains(simulate.read_body(res), "\"code\":\"not_found\"")
  |> expect.is_true
}

pub fn include_metrics_card_not_found_uses_typed_error_code_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()

  let res = card_metrics_response(handler, session, 999_999)

  expect.expect_status(res, 404)
  string.contains(simulate.read_body(res), "\"code\":\"not_found\"")
  |> expect.is_true
}

pub fn include_metrics_task_unavailable_returns_typed_409_test() {
  let #(db, handler, session, project_id, type_id) =
    fixtures.require_task_project("Core")
  let assert Ok(task_id) =
    fixtures.create_task(
      handler,
      session,
      project_id,
      type_id,
      "Task unavailable",
    )

  create_shadow_tasks_table(db)
  let res = task_metrics_response(handler, session, task_id)
  drop_shadow_tasks_table(db)

  expect.expect_status(res, 409)
  string.contains(simulate.read_body(res), "\"code\":\"metrics_unavailable\"")
  |> expect.is_true
}

pub fn include_metrics_card_unavailable_returns_typed_409_test() {
  let #(db, handler, session, project_id) =
    fixtures.require_project_context("Core")
  let assert Ok(card_id) =
    fixtures.create_card(handler, session, project_id, "Card")

  create_shadow_tasks_table(db)
  let res = card_metrics_response(handler, session, card_id)
  drop_shadow_tasks_table(db)

  expect.expect_status(res, 409)
  string.contains(simulate.read_body(res), "\"code\":\"metrics_unavailable\"")
  |> expect.is_true
}

fn create_shadow_tasks_table(db: pog.Connection) -> Nil {
  let _ =
    pog.query("drop schema if exists metrics_shadow cascade")
    |> pog.execute(db)
  let _ =
    pog.query("create schema metrics_shadow")
    |> pog.execute(db)
  let _ =
    pog.query(
      "create table metrics_shadow.tasks (id int, pool_lifetime_s int, last_entered_pool_at timestamptz, created_from_rule_id int)",
    )
    |> pog.execute(db)

  Nil
}

fn card_metrics_response(handler, session: fixtures.Session, card_id: Int) {
  handler(
    simulate.request(
      http.Get,
      "/api/v1/cards/" <> int.to_string(card_id) <> "?include=metrics",
    )
    |> fixtures.with_auth(session),
  )
}

fn task_metrics_response(handler, session: fixtures.Session, task_id: Int) {
  handler(
    simulate.request(
      http.Get,
      "/api/v1/tasks/" <> int.to_string(task_id) <> "?include=metrics",
    )
    |> fixtures.with_auth(session),
  )
}

fn drop_shadow_tasks_table(db: pog.Connection) -> Nil {
  let _ =
    pog.query("drop schema if exists metrics_shadow cascade")
    |> pog.execute(db)

  Nil
}
