import fixtures
import gleam/http
import gleam/int
import gleam/json
import gleam/option
import gleam/result
import gleam/string
import gleeunit
import gleeunit/should
import pog
import scrumbringer_server
import scrumbringer_server/seed_db
import wisp/simulate

pub fn main() {
  gleeunit.main()
}

pub fn include_metrics_returns_metrics_payload_for_milestone_card_and_task_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")

  create_milestone(handler, session, project_id) |> should.equal(200)
  let milestone_id =
    fixtures.query_int(
      db,
      "select id from milestones where project_id = $1 and name = 'Release 1'",
      [pog.int(project_id)],
    )
    |> result.unwrap(0)

  create_card_in_milestone(handler, session, project_id, milestone_id)
  |> should.equal(200)
  let card_id =
    fixtures.query_int(
      db,
      "select id from cards where project_id = $1 and title = 'Card in milestone'",
      [pog.int(project_id)],
    )
    |> result.unwrap(0)

  let assert Ok(task_id) =
    fixtures.create_task_with_card(
      handler,
      session,
      project_id,
      type_id,
      card_id,
      "Task for metrics",
    )

  let milestone_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/milestones/"
          <> int.to_string(milestone_id)
          <> "?include=metrics",
      )
      |> fixtures.with_auth(session),
    )
  milestone_res.status |> should.equal(200)
  string.contains(simulate.read_body(milestone_res), "\"metrics\"")
  |> should.be_true

  let card_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/cards/" <> int.to_string(card_id) <> "?include=metrics",
      )
      |> fixtures.with_auth(session),
    )
  card_res.status |> should.equal(200)
  string.contains(simulate.read_body(card_res), "\"metrics\"")
  |> should.be_true

  let task_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "?include=metrics",
      )
      |> fixtures.with_auth(session),
    )
  task_res.status |> should.equal(200)
  string.contains(simulate.read_body(task_res), "\"metrics\"")
  |> should.be_true
}

pub fn include_metrics_forbidden_uses_typed_error_code_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(card_id) =
    fixtures.create_card(handler, session, project_id, "Card")

  let assert Ok(_) =
    fixtures.create_member_user(handler, db, "member@example.com", "inv_member")
  let assert Ok(member_session) =
    fixtures.login(handler, "member@example.com", "passwordpassword")

  let res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/cards/" <> int.to_string(card_id) <> "?include=metrics",
      )
      |> fixtures.with_auth(member_session),
    )

  res.status |> should.equal(403)
  string.contains(simulate.read_body(res), "\"code\":\"forbidden\"")
  |> should.be_true
}

pub fn include_metrics_milestone_forbidden_uses_typed_error_code_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")

  create_milestone(handler, session, project_id) |> should.equal(200)
  let milestone_id =
    fixtures.query_int(
      db,
      "select id from milestones where project_id = $1 and name = 'Release 1'",
      [pog.int(project_id)],
    )
    |> result.unwrap(0)

  let assert Ok(_) =
    fixtures.create_member_user(
      handler,
      db,
      "member2@example.com",
      "inv_member",
    )
  let assert Ok(member_session) =
    fixtures.login(handler, "member2@example.com", "passwordpassword")

  let res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/milestones/"
          <> int.to_string(milestone_id)
          <> "?include=metrics",
      )
      |> fixtures.with_auth(member_session),
    )

  res.status |> should.equal(403)
  string.contains(simulate.read_body(res), "\"code\":\"forbidden\"")
  |> should.be_true
}

pub fn include_metrics_task_forbidden_returns_not_found_typed_error_code_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(task_id) =
    fixtures.create_task(
      handler,
      session,
      project_id,
      type_id,
      "Task forbidden",
    )

  let assert Ok(_) =
    fixtures.create_member_user(
      handler,
      db,
      "member3@example.com",
      "inv_member",
    )
  let assert Ok(member_session) =
    fixtures.login(handler, "member3@example.com", "passwordpassword")

  let res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "?include=metrics",
      )
      |> fixtures.with_auth(member_session),
    )

  res.status |> should.equal(404)
  string.contains(simulate.read_body(res), "\"code\":\"not_found\"")
  |> should.be_true
}

pub fn include_metrics_task_returns_expected_counts_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(task_id) =
    fixtures.create_task(
      handler,
      session,
      project_id,
      type_id,
      "Task metrics exact",
    )

  let org_id =
    fixtures.query_int(db, "select id from organizations limit 1", [])
    |> result.unwrap(1)
  let admin_id =
    fixtures.query_int(
      db,
      "select id from users where email = 'admin@example.com'",
      [],
    )
    |> result.unwrap(1)

  let assert Ok(_) =
    fixtures.create_member_user(
      handler,
      db,
      "member4@example.com",
      "inv_member",
    )
  let member_id =
    fixtures.query_int(
      db,
      "select id from users where email = 'member4@example.com'",
      [],
    )
    |> result.unwrap(2)

  let _ =
    fixtures.insert_task_event_db(
      db,
      org_id,
      project_id,
      task_id,
      admin_id,
      "task_claimed",
    )
  let _ =
    fixtures.insert_task_event_db(
      db,
      org_id,
      project_id,
      task_id,
      admin_id,
      "task_released",
    )
  let _ =
    fixtures.insert_task_event_db(
      db,
      org_id,
      project_id,
      task_id,
      member_id,
      "task_claimed",
    )

  let _ =
    pog.query(
      "update tasks set status = 'claimed', pool_lifetime_s = 5400 where id = $1",
    )
    |> pog.parameter(pog.int(task_id))
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

  let res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "?include=metrics",
      )
      |> fixtures.with_auth(session),
    )

  res.status |> should.equal(200)
  let body = simulate.read_body(res)

  let claim_count =
    fixtures.query_int(
      db,
      "select count(*)::int from task_events where task_id = $1 and event_type = 'task_claimed'",
      [pog.int(task_id)],
    )
    |> result.unwrap(0)
  let release_count =
    fixtures.query_int(
      db,
      "select count(*)::int from task_events where task_id = $1 and event_type = 'task_released'",
      [pog.int(task_id)],
    )
    |> result.unwrap(0)
  let unique_executors =
    fixtures.query_int(
      db,
      "select count(distinct actor_user_id)::int from task_events where task_id = $1 and event_type = 'task_claimed'",
      [pog.int(task_id)],
    )
    |> result.unwrap(0)
  let session_count =
    fixtures.query_int(
      db,
      "select count(*)::int from user_task_work_session where task_id = $1",
      [pog.int(task_id)],
    )
    |> result.unwrap(0)
  let total_work_time_s =
    fixtures.query_int(
      db,
      "select coalesce(sum(accumulated_s), 0)::int from user_task_work_total where task_id = $1",
      [pog.int(task_id)],
    )
    |> result.unwrap(0)

  string.contains(body, "\"claim_count\":" <> int.to_string(claim_count))
  |> should.be_true
  string.contains(body, "\"release_count\":" <> int.to_string(release_count))
  |> should.be_true
  string.contains(
    body,
    "\"unique_executors\":" <> int.to_string(unique_executors),
  )
  |> should.be_true
  string.contains(body, "\"pool_lifetime_s\":5400") |> should.be_true
  string.contains(body, "\"session_count\":" <> int.to_string(session_count))
  |> should.be_true
  string.contains(
    body,
    "\"total_work_time_s\":" <> int.to_string(total_work_time_s),
  )
  |> should.be_true
  string.contains(body, "\"first_claim_at\":") |> should.be_true
}

pub fn include_metrics_card_and_milestone_return_expected_counts_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")

  create_milestone(handler, session, project_id) |> should.equal(200)
  let milestone_id =
    fixtures.query_int(
      db,
      "select id from milestones where project_id = $1 and name = 'Release 1'",
      [pog.int(project_id)],
    )
    |> result.unwrap(0)

  create_card_in_milestone(handler, session, project_id, milestone_id)
  |> should.equal(200)
  let card_id =
    fixtures.query_int(
      db,
      "select id from cards where project_id = $1 and title = 'Card in milestone'",
      [pog.int(project_id)],
    )
    |> result.unwrap(0)

  let assert Ok(task_id) =
    fixtures.create_task_with_card(
      handler,
      session,
      project_id,
      type_id,
      card_id,
      "Task for card/milestone metrics",
    )

  let _ =
    pog.query("update tasks set status = 'completed' where id = $1")
    |> pog.parameter(pog.int(task_id))
    |> pog.execute(db)

  let card_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/cards/" <> int.to_string(card_id) <> "?include=metrics",
      )
      |> fixtures.with_auth(session),
    )
  card_res.status |> should.equal(200)
  let card_body = simulate.read_body(card_res)
  string.contains(card_body, "\"tasks_total\":1") |> should.be_true
  string.contains(card_body, "\"tasks_completed\":1") |> should.be_true
  string.contains(card_body, "\"tasks_percent\":100") |> should.be_true

  let milestone_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/milestones/"
          <> int.to_string(milestone_id)
          <> "?include=metrics",
      )
      |> fixtures.with_auth(session),
    )
  milestone_res.status |> should.equal(200)
  let milestone_body = simulate.read_body(milestone_res)
  string.contains(milestone_body, "\"cards_total\":1") |> should.be_true
  string.contains(milestone_body, "\"tasks_total\":1") |> should.be_true
  string.contains(milestone_body, "\"tasks_completed\":1") |> should.be_true
  string.contains(milestone_body, "\"tasks_percent\":100") |> should.be_true
}

pub fn include_metrics_not_found_uses_typed_error_code_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()

  let res =
    handler(
      simulate.request(http.Get, "/api/v1/tasks/999999?include=metrics")
      |> fixtures.with_auth(session),
    )

  res.status |> should.equal(404)
  string.contains(simulate.read_body(res), "\"code\":\"not_found\"")
  |> should.be_true
}

pub fn include_metrics_card_not_found_uses_typed_error_code_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()

  let res =
    handler(
      simulate.request(http.Get, "/api/v1/cards/999999?include=metrics")
      |> fixtures.with_auth(session),
    )

  res.status |> should.equal(404)
  string.contains(simulate.read_body(res), "\"code\":\"not_found\"")
  |> should.be_true
}

pub fn include_metrics_milestone_not_found_uses_typed_error_code_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()

  let res =
    handler(
      simulate.request(http.Get, "/api/v1/milestones/999999?include=metrics")
      |> fixtures.with_auth(session),
    )

  res.status |> should.equal(404)
  string.contains(simulate.read_body(res), "\"code\":\"not_found\"")
  |> should.be_true
}

pub fn include_metrics_task_unavailable_returns_typed_409_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(task_id) =
    fixtures.create_task(
      handler,
      session,
      project_id,
      type_id,
      "Task unavailable",
    )

  create_shadow_tasks_table(db)
  let res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "?include=metrics",
      )
      |> fixtures.with_auth(session),
    )
  drop_shadow_tasks_table(db)

  res.status |> should.equal(409)
  string.contains(simulate.read_body(res), "\"code\":\"metrics_unavailable\"")
  |> should.be_true
}

pub fn include_metrics_card_unavailable_returns_typed_409_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(card_id) =
    fixtures.create_card(handler, session, project_id, "Card")

  create_shadow_tasks_table(db)
  let res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/cards/" <> int.to_string(card_id) <> "?include=metrics",
      )
      |> fixtures.with_auth(session),
    )
  drop_shadow_tasks_table(db)

  res.status |> should.equal(409)
  string.contains(simulate.read_body(res), "\"code\":\"metrics_unavailable\"")
  |> should.be_true
}

pub fn include_metrics_milestone_unavailable_returns_typed_409_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")

  create_milestone(handler, session, project_id) |> should.equal(200)
  let milestone_id =
    fixtures.query_int(
      db,
      "select id from milestones where project_id = $1 and name = 'Release 1'",
      [pog.int(project_id)],
    )
    |> result.unwrap(0)

  create_shadow_tasks_table(db)
  let res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/milestones/"
          <> int.to_string(milestone_id)
          <> "?include=metrics",
      )
      |> fixtures.with_auth(session),
    )
  drop_shadow_tasks_table(db)

  res.status |> should.equal(409)
  string.contains(simulate.read_body(res), "\"code\":\"metrics_unavailable\"")
  |> should.be_true
}

fn create_milestone(
  handler: fixtures.Handler,
  session: fixtures.Session,
  project_id: Int,
) -> Int {
  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/milestones",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(
        json.object([
          #("name", json.string("Release 1")),
          #("description", json.string("Initial")),
        ]),
      ),
    )

  res.status
}

fn create_card_in_milestone(
  handler: fixtures.Handler,
  session: fixtures.Session,
  project_id: Int,
  milestone_id: Int,
) -> Int {
  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/cards",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(
        json.object([
          #("title", json.string("Card in milestone")),
          #("description", json.string("desc")),
          #("milestone_id", json.int(milestone_id)),
        ]),
      ),
    )

  res.status
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

fn drop_shadow_tasks_table(db: pog.Connection) -> Nil {
  let _ =
    pog.query("drop schema if exists metrics_shadow cascade")
    |> pog.execute(db)

  Nil
}
