import fixtures
import gleam/http
import gleam/http/request
import gleam/int
import gleam/json
import gleam/option
import gleam/string
import pog
import scrumbringer_server
import support/assertions as expect
import wisp
import wisp/simulate

fn create_card_req(
  project_id: Int,
  title: String,
  color: String,
) -> wisp.Request {
  simulate.request(
    http.Post,
    "/api/v1/projects/" <> int.to_string(project_id) <> "/cards",
  )
  |> simulate.json_body(
    json.object([
      #("title", json.string(title)),
      #("description", json.string("desc")),
      #("color", json.string(color)),
    ]),
  )
}

fn create_child_card(
  handler: fn(wisp.Request) -> wisp.Response,
  session: fixtures.Session,
  project_id: Int,
  parent_card_id: Int,
  title: String,
) -> Result(Int, String) {
  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/cards",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(
        json.object([
          #("title", json.string(title)),
          #("description", json.string("desc")),
          #("parent_card_id", json.int(parent_card_id)),
        ]),
      ),
    )

  case res.status {
    200 ->
      fixtures.decode_entity_id(simulate.read_body(res), fixtures.CardEntity)
    status ->
      Error(
        "create_child_card failed: status="
        <> int.to_string(status)
        <> " body="
        <> simulate.read_body(res),
      )
  }
}

fn activate_card(
  handler: fn(wisp.Request) -> wisp.Response,
  session: fixtures.Session,
  card_id: Int,
) -> wisp.Response {
  handler(
    simulate.request(
      http.Post,
      "/api/v1/cards/" <> int.to_string(card_id) <> "/activate",
    )
    |> fixtures.with_auth(session)
    |> simulate.json_body(json.object([])),
  )
}

fn claim_task(
  handler: fn(wisp.Request) -> wisp.Response,
  session: fixtures.Session,
  task_id: Int,
) -> wisp.Response {
  handler(
    simulate.request(
      http.Post,
      "/api/v1/tasks/" <> int.to_string(task_id) <> "/claim",
    )
    |> fixtures.with_auth(session)
    |> simulate.json_body(json.object([#("version", json.int(1))])),
  )
}

fn close_task(
  handler: fn(wisp.Request) -> wisp.Response,
  session: fixtures.Session,
  task_id: Int,
  version: Int,
) -> wisp.Response {
  handler(
    simulate.request(
      http.Post,
      "/api/v1/tasks/" <> int.to_string(task_id) <> "/close",
    )
    |> fixtures.with_auth(session)
    |> simulate.json_body(json.object([#("version", json.int(version))])),
  )
}

fn close_card(
  handler: fn(wisp.Request) -> wisp.Response,
  session: fixtures.Session,
  card_id: Int,
) -> wisp.Response {
  handler(
    simulate.request(
      http.Post,
      "/api/v1/cards/" <> int.to_string(card_id) <> "/close",
    )
    |> fixtures.with_auth(session)
    |> simulate.json_body(
      json.object([#("reason", json.string("manually_closed"))]),
    ),
  )
}

fn move_card(
  handler: fn(wisp.Request) -> wisp.Response,
  session: fixtures.Session,
  card_id: Int,
  parent_card_id: Int,
) -> wisp.Response {
  move_card_with_parent(handler, session, card_id, option.Some(parent_card_id))
}

fn move_card_to_root(
  handler: fn(wisp.Request) -> wisp.Response,
  session: fixtures.Session,
  card_id: Int,
) -> wisp.Response {
  move_card_with_parent(handler, session, card_id, option.None)
}

fn move_card_with_parent(
  handler: fn(wisp.Request) -> wisp.Response,
  session: fixtures.Session,
  card_id: Int,
  parent_card_id: option.Option(Int),
) -> wisp.Response {
  handler(
    simulate.request(
      http.Post,
      "/api/v1/cards/" <> int.to_string(card_id) <> "/move",
    )
    |> fixtures.with_auth(session)
    |> simulate.json_body(
      json.object([
        #("parent_card_id", case parent_card_id {
          option.Some(id) -> json.int(id)
          option.None -> json.null()
        }),
      ]),
    ),
  )
}

fn create_task_with_card_response(
  handler: fn(wisp.Request) -> wisp.Response,
  session: fixtures.Session,
  project_id: Int,
  type_id: Int,
  card_id: Int,
  title: String,
) -> wisp.Response {
  handler(
    simulate.request(
      http.Post,
      "/api/v1/projects/" <> int.to_string(project_id) <> "/tasks",
    )
    |> fixtures.with_auth(session)
    |> simulate.json_body(
      json.object([
        #("title", json.string(title)),
        #("description", json.string("desc")),
        #("type_id", json.int(type_id)),
        #("priority", json.int(3)),
        #("card_id", json.int(card_id)),
      ]),
    ),
  )
}

pub fn create_card_requires_auth_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")

  let res = handler(create_card_req(project_id, "Card", "red"))
  expect.expect_status(res, 401)
}

pub fn create_card_requires_csrf_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")

  let res =
    handler(
      create_card_req(project_id, "Card", "red")
      |> request.set_cookie("sb_session", session.token),
    )

  expect.expect_status(res, 403)
  string.contains(simulate.read_body(res), "FORBIDDEN") |> expect.is_true
}

pub fn create_card_rejects_invalid_color_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")

  let res =
    handler(
      create_card_req(project_id, "Card", "beige")
      |> fixtures.with_auth(session),
    )

  expect.expect_status(res, 422)
  string.contains(simulate.read_body(res), "VALIDATION_ERROR") |> expect.is_true
}

pub fn create_card_rejects_missing_title_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")

  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/cards",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([])),
    )

  expect.expect_status(res, 422)
  string.contains(simulate.read_body(res), "VALIDATION_ERROR") |> expect.is_true
}

pub fn create_card_rejects_invalid_content_type_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")

  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/cards",
      )
      |> fixtures.with_auth(session)
      |> simulate.string_body("not-json"),
    )

  expect.expect_status(res, 415)
}

pub fn create_card_requires_project_admin_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")

  let assert Ok(member_id) =
    fixtures.create_member_user(handler, db, "member@example.com", "il_member")
  let assert Ok(Nil) =
    fixtures.add_member(handler, session, project_id, member_id, "member")

  let assert Ok(member_session) =
    fixtures.login(handler, "member@example.com", "passwordpassword")

  let res =
    handler(
      create_card_req(project_id, "Card", "red")
      |> fixtures.with_auth(member_session),
    )

  expect.expect_status(res, 403)
  string.contains(simulate.read_body(res), "FORBIDDEN") |> expect.is_true
}

pub fn get_card_not_found_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()

  let res =
    handler(
      simulate.request(http.Get, "/api/v1/cards/999999")
      |> fixtures.with_auth(session),
    )

  expect.expect_status(res, 404)
  string.contains(simulate.read_body(res), "NOT_FOUND") |> expect.is_true
}

pub fn retired_hierarchy_routes_return_not_found_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()
  let retired_collection = "card_" <> "trees"

  let project_route =
    handler(
      simulate.request(http.Get, "/api/v1/projects/1/" <> retired_collection)
      |> fixtures.with_auth(session),
    )
  let item_route =
    handler(
      simulate.request(http.Get, "/api/v1/" <> retired_collection <> "/1")
      |> fixtures.with_auth(session),
    )
  let activate_route =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/" <> retired_collection <> "/1/activate",
      )
      |> fixtures.with_auth(session),
    )

  expect.expect_status(project_route, 404)
  expect.expect_status(item_route, 404)
  expect.expect_status(activate_route, 404)
}

pub fn activate_card_cascades_and_reports_descendant_pool_impact_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(root_id) =
    fixtures.create_card(handler, session, project_id, "Root")
  let assert Ok(child_id) =
    create_child_card(handler, session, project_id, root_id, "Child")
  let assert Ok(leaf_id) =
    create_child_card(handler, session, project_id, child_id, "Leaf")
  let assert Ok(_task_id) =
    fixtures.create_task_with_card(
      handler,
      session,
      project_id,
      type_id,
      leaf_id,
      "Leaf task",
    )

  let res = activate_card(handler, session, root_id)

  expect.expect_status(res, 200)
  string.contains(simulate.read_body(res), "\"pool_impact\":1")
  |> expect.is_true

  let assert Ok(leaf_state) =
    fixtures.query_string(
      db,
      "select execution_state from cards where id = $1",
      [pog.int(leaf_id)],
    )
  let assert Ok(audit_count) =
    fixtures.query_int(
      db,
      "select count(*) from audit_events where card_id = $1 and event_type = 'card_activated'",
      [pog.int(root_id)],
    )
  leaf_state |> expect.equal("active")
  audit_count |> expect.equal(1)
}

pub fn close_card_blocks_claimed_descendant_task_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(root_id) =
    fixtures.create_card(handler, session, project_id, "Root")
  let assert Ok(child_id) =
    create_child_card(handler, session, project_id, root_id, "Child")
  let assert Ok(leaf_id) =
    create_child_card(handler, session, project_id, child_id, "Leaf")
  let assert Ok(task_id) =
    fixtures.create_task_with_card(
      handler,
      session,
      project_id,
      type_id,
      leaf_id,
      "Claimed leaf task",
    )

  expect.expect_status(activate_card(handler, session, root_id), 200)
  expect.expect_status(claim_task(handler, session, task_id), 200)

  let res = close_card(handler, session, root_id)

  expect.expect_status(res, 409)
  string.contains(simulate.read_body(res), "CARD_HAS_CLAIMED_DESCENDANT")
  |> expect.is_true
}

pub fn close_card_closes_available_descendant_tasks_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(root_id) =
    fixtures.create_card(handler, session, project_id, "Root")
  let assert Ok(child_id) =
    create_child_card(handler, session, project_id, root_id, "Child")
  let assert Ok(task_id) =
    fixtures.create_task_with_card(
      handler,
      session,
      project_id,
      type_id,
      child_id,
      "Available task",
    )

  expect.expect_status(activate_card(handler, session, root_id), 200)
  let res = close_card(handler, session, root_id)

  expect.expect_status(res, 200)
  let assert Ok(task_state) =
    fixtures.query_string(
      db,
      "select execution_state from tasks where id = $1",
      [pog.int(task_id)],
    )
  let assert Ok(close_reason) =
    fixtures.query_string(
      db,
      "select coalesce(closed_reason, '') from tasks where id = $1",
      [pog.int(task_id)],
    )
  let assert Ok(child_state) =
    fixtures.query_string(
      db,
      "select execution_state from cards where id = $1",
      [pog.int(child_id)],
    )
  let assert Ok(audit_count) =
    fixtures.query_int(
      db,
      "select count(*) from audit_events where card_id = $1 and event_type = 'card_closed'",
      [pog.int(root_id)],
    )

  task_state |> expect.equal("closed")
  close_reason |> expect.equal("closed_by_ancestor")
  child_state |> expect.equal("closed")
  audit_count |> expect.equal(1)
}

pub fn activate_card_rejects_closed_card_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(card_id) =
    fixtures.create_card(handler, session, project_id, "Closed card")

  expect.expect_status(close_card(handler, session, card_id), 200)
  let res = activate_card(handler, session, card_id)

  expect.expect_status(res, 409)
  string.contains(simulate.read_body(res), "CARD_CLOSED") |> expect.is_true
}

pub fn activate_empty_card_exposes_persisted_active_state_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(card_id) =
    fixtures.create_card(handler, session, project_id, "Empty active card")

  expect.expect_status(activate_card(handler, session, card_id), 200)
  let res =
    handler(
      simulate.request(http.Get, "/api/v1/cards/" <> int.to_string(card_id))
      |> fixtures.with_auth(session),
    )

  expect.expect_status(res, 200)
  string.contains(simulate.read_body(res), "\"state\":\"en_curso\"")
  |> expect.is_true
}

pub fn create_task_rejects_closed_card_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(card_id) =
    fixtures.create_card(handler, session, project_id, "Closed card")

  expect.expect_status(close_card(handler, session, card_id), 200)
  let res =
    create_task_with_card_response(
      handler,
      session,
      project_id,
      type_id,
      card_id,
      "Should not be created",
    )

  expect.expect_status(res, 422)
  let body = simulate.read_body(res)
  expect.expect_json_contains_code(body, "VALIDATION_ERROR")
  string.contains(body, "Card is closed") |> expect.is_true
}

pub fn create_card_rejects_parent_with_tasks_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(parent_id) =
    fixtures.create_card(handler, session, project_id, "Task group")
  let assert Ok(_task_id) =
    fixtures.create_task_with_card(
      handler,
      session,
      project_id,
      type_id,
      parent_id,
      "Existing task",
    )

  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/cards",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(
        json.object([
          #("title", json.string("Should not fit")),
          #("parent_card_id", json.int(parent_id)),
        ]),
      ),
    )

  expect.expect_status(res, 422)
  string.contains(simulate.read_body(res), "PARENT_DOES_NOT_ACCEPT_CARDS")
  |> expect.is_true
}

pub fn create_task_rejects_card_with_child_cards_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(parent_id) =
    fixtures.create_card(handler, session, project_id, "Card group")
  let assert Ok(_child_id) =
    create_child_card(handler, session, project_id, parent_id, "Child")

  let res =
    create_task_with_card_response(
      handler,
      session,
      project_id,
      type_id,
      parent_id,
      "Should not fit",
    )

  expect.expect_status(res, 422)
  string.contains(simulate.read_body(res), "CARD_HAS_CHILD_CARDS")
  |> expect.is_true
  string.contains(simulate.read_body(res), "Card already contains child cards")
  |> expect.is_true
}

pub fn draft_card_task_enters_pool_when_card_activates_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(card_id) =
    fixtures.create_card(handler, session, project_id, "Draft task group")
  let assert Ok(task_id) =
    fixtures.create_task_with_card(
      handler,
      session,
      project_id,
      type_id,
      card_id,
      "Prepared task",
    )

  let assert Ok(pool_time_before) =
    fixtures.query_string(
      db,
      "select coalesce(to_char(last_entered_pool_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') from tasks where id = $1",
      [pog.int(task_id)],
    )
  pool_time_before |> expect.equal("")

  let activate_res = activate_card(handler, session, card_id)
  expect.expect_status(activate_res, 200)

  let assert Ok(pool_time_after) =
    fixtures.query_string(
      db,
      "select coalesce(to_char(last_entered_pool_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') from tasks where id = $1",
      [pog.int(task_id)],
    )
  let has_pool_time = pool_time_after != ""
  has_pool_time |> expect.is_true
}

pub fn claim_task_rejects_draft_card_task_until_activation_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(card_id) =
    fixtures.create_card(handler, session, project_id, "Draft task group")
  let assert Ok(task_id) =
    fixtures.create_task_with_card(
      handler,
      session,
      project_id,
      type_id,
      card_id,
      "Prepared task",
    )

  let draft_claim = claim_task(handler, session, task_id)

  expect.expect_status(draft_claim, 409)
  string.contains(simulate.read_body(draft_claim), "TASK_NOT_CLAIMABLE")
  |> expect.is_true

  expect.expect_status(activate_card(handler, session, card_id), 200)
  expect.expect_status(claim_task(handler, session, task_id), 200)
}

pub fn close_task_rolls_up_direct_parent_cards_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(root_id) =
    fixtures.create_card(handler, session, project_id, "Root")
  let assert Ok(child_id) =
    create_child_card(handler, session, project_id, root_id, "Child")
  let assert Ok(task_id) =
    fixtures.create_task_with_card(
      handler,
      session,
      project_id,
      type_id,
      child_id,
      "Leaf task",
    )

  expect.expect_status(activate_card(handler, session, root_id), 200)
  expect.expect_status(claim_task(handler, session, task_id), 200)
  expect.expect_status(close_task(handler, session, task_id, 2), 200)

  let assert Ok(child_state) =
    fixtures.query_string(
      db,
      "select execution_state from cards where id = $1",
      [pog.int(child_id)],
    )
  let assert Ok(root_state) =
    fixtures.query_string(
      db,
      "select execution_state from cards where id = $1",
      [pog.int(root_id)],
    )
  let assert Ok(child_reason) =
    fixtures.query_string(
      db,
      "select coalesce(closed_reason, '') from cards where id = $1",
      [pog.int(child_id)],
    )
  let assert Ok(root_reason) =
    fixtures.query_string(
      db,
      "select coalesce(closed_reason, '') from cards where id = $1",
      [pog.int(root_id)],
    )

  child_state |> expect.equal("closed")
  root_state |> expect.equal("closed")
  child_reason |> expect.equal("rollup")
  root_reason |> expect.equal("rollup")
}

pub fn close_task_does_not_roll_up_when_child_card_stays_open_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(root_id) =
    fixtures.create_card(handler, session, project_id, "Root")
  let assert Ok(child_id) =
    create_child_card(handler, session, project_id, root_id, "Open child")
  let assert Ok(task_leaf_id) =
    create_child_card(handler, session, project_id, root_id, "Task leaf")
  let assert Ok(task_id) =
    fixtures.create_task_with_card(
      handler,
      session,
      project_id,
      type_id,
      task_leaf_id,
      "Leaf task",
    )

  expect.expect_status(activate_card(handler, session, root_id), 200)
  expect.expect_status(claim_task(handler, session, task_id), 200)
  expect.expect_status(close_task(handler, session, task_id, 2), 200)

  let assert Ok(root_state) =
    fixtures.query_string(
      db,
      "select execution_state from cards where id = $1",
      [pog.int(root_id)],
    )
  let assert Ok(child_state) =
    fixtures.query_string(
      db,
      "select execution_state from cards where id = $1",
      [pog.int(child_id)],
    )
  let assert Ok(root_reason) =
    fixtures.query_string(
      db,
      "select coalesce(closed_reason, '') from cards where id = $1",
      [pog.int(root_id)],
    )

  root_state |> expect.equal("active")
  child_state |> expect.equal("active")
  root_reason |> expect.equal("")
}

pub fn move_card_rejects_cycle_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(root_id) =
    fixtures.create_card(handler, session, project_id, "Root")
  let assert Ok(child_id) =
    create_child_card(handler, session, project_id, root_id, "Child")

  let res = move_card(handler, session, root_id, child_id)

  expect.expect_status(res, 422)
  string.contains(simulate.read_body(res), "MOVE_WOULD_CREATE_CYCLE")
  |> expect.is_true
}

pub fn move_card_rejects_destination_with_tasks_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(root_a_id) =
    fixtures.create_card(handler, session, project_id, "Root A")
  let assert Ok(root_b_id) =
    fixtures.create_card(handler, session, project_id, "Root B")
  let assert Ok(child_id) =
    create_child_card(handler, session, project_id, root_a_id, "Child")
  let assert Ok(_task_id) =
    fixtures.create_task_with_card(
      handler,
      session,
      project_id,
      type_id,
      root_b_id,
      "Root B task",
    )

  let res = move_card(handler, session, child_id, root_b_id)

  expect.expect_status(res, 422)
  string.contains(simulate.read_body(res), "DESTINATION_DOES_NOT_ACCEPT_CARDS")
  |> expect.is_true
}

pub fn move_card_rejects_closed_destination_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(root_a_id) =
    fixtures.create_card(handler, session, project_id, "Root A")
  let assert Ok(root_b_id) =
    fixtures.create_card(handler, session, project_id, "Root B")
  let assert Ok(child_id) =
    create_child_card(handler, session, project_id, root_a_id, "Child")

  expect.expect_status(close_card(handler, session, root_b_id), 200)
  let res = move_card(handler, session, child_id, root_b_id)

  expect.expect_status(res, 409)
  string.contains(simulate.read_body(res), "DESTINATION_CLOSED")
  |> expect.is_true
}

pub fn move_card_allows_depth_change_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(root_a_id) =
    fixtures.create_card(handler, session, project_id, "Root A")
  let assert Ok(root_b_id) =
    fixtures.create_card(handler, session, project_id, "Root B")
  let assert Ok(child_id) =
    create_child_card(handler, session, project_id, root_a_id, "Child")
  let assert Ok(grandchild_id) =
    create_child_card(handler, session, project_id, child_id, "Grandchild")

  let res = move_card(handler, session, grandchild_id, root_b_id)

  expect.expect_status(res, 200)
  let assert Ok(parent_id) =
    fixtures.query_nullable_int(
      db,
      "select parent_card_id from cards where id = $1",
      [pog.int(grandchild_id)],
    )
  let assert option.Some(actual_parent_id) = parent_id
  let assert True = actual_parent_id == root_b_id
}

pub fn move_card_allows_root_card_inside_another_card_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(root_a_id) =
    fixtures.create_card(handler, session, project_id, "Root A")
  let assert Ok(root_b_id) =
    fixtures.create_card(handler, session, project_id, "Root B")

  let res = move_card(handler, session, root_b_id, root_a_id)

  expect.expect_status(res, 200)
  let assert Ok(parent_id) =
    fixtures.query_nullable_int(
      db,
      "select parent_card_id from cards where id = $1",
      [pog.int(root_b_id)],
    )
  let assert option.Some(actual_parent_id) = parent_id
  let assert True = actual_parent_id == root_a_id
}

pub fn move_card_allows_child_card_to_project_root_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(root_id) =
    fixtures.create_card(handler, session, project_id, "Root")
  let assert Ok(child_id) =
    create_child_card(handler, session, project_id, root_id, "Child")

  let res = move_card_to_root(handler, session, child_id)

  expect.expect_status(res, 200)
  let assert Ok(parent_id) =
    fixtures.query_nullable_int(
      db,
      "select parent_card_id from cards where id = $1",
      [pog.int(child_id)],
    )
  let assert option.None = parent_id
}

pub fn update_card_not_found_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()

  let res =
    handler(
      simulate.request(http.Patch, "/api/v1/cards/999999")
      |> fixtures.with_auth(session)
      |> simulate.json_body(
        json.object([
          #("title", json.string("Nope")),
          #("description", json.string("desc")),
          #("color", json.string("red")),
        ]),
      ),
    )

  expect.expect_status(res, 404)
  string.contains(simulate.read_body(res), "NOT_FOUND") |> expect.is_true
}

pub fn update_card_rejects_invalid_color_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(card_id) =
    fixtures.create_card(handler, session, project_id, "Card")

  let _ =
    fixtures.create_task_with_card(
      handler,
      session,
      project_id,
      type_id,
      card_id,
      "Task",
    )

  let res =
    handler(
      simulate.request(http.Patch, "/api/v1/cards/" <> int.to_string(card_id))
      |> fixtures.with_auth(session)
      |> simulate.json_body(
        json.object([
          #("title", json.string("Card")),
          #("description", json.string("desc")),
          #("color", json.string("beige")),
        ]),
      ),
    )

  expect.expect_status(res, 422)
  string.contains(simulate.read_body(res), "VALIDATION_ERROR") |> expect.is_true
}

pub fn delete_card_not_found_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()

  let res =
    handler(
      simulate.request(http.Delete, "/api/v1/cards/999999")
      |> fixtures.with_auth(session),
    )

  expect.expect_status(res, 404)
  string.contains(simulate.read_body(res), "NOT_FOUND") |> expect.is_true
}

pub fn delete_card_conflict_when_tasks_exist_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(card_id) =
    fixtures.create_card(handler, session, project_id, "Card")

  let _ =
    fixtures.create_task_with_card(
      handler,
      session,
      project_id,
      type_id,
      card_id,
      "Task",
    )

  let res =
    handler(
      simulate.request(http.Delete, "/api/v1/cards/" <> int.to_string(card_id))
      |> fixtures.with_auth(session),
    )

  expect.expect_status(res, 409)
  string.contains(simulate.read_body(res), "CONFLICT_HAS_TASKS")
  |> expect.is_true
}

pub fn delete_card_conflict_when_child_cards_exist_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(parent_id) =
    fixtures.create_card(handler, session, project_id, "Parent")
  let assert Ok(_child_id) =
    create_child_card(handler, session, project_id, parent_id, "Child")

  let res =
    handler(
      simulate.request(
        http.Delete,
        "/api/v1/cards/" <> int.to_string(parent_id),
      )
      |> fixtures.with_auth(session),
    )

  expect.expect_status(res, 409)
  string.contains(simulate.read_body(res), "CONFLICT_HAS_CHILD_CARDS")
  |> expect.is_true
}

pub fn delete_card_conflict_when_operational_history_exists_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()
  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(card_id) =
    fixtures.create_card(handler, session, project_id, "Activated card")

  expect.expect_status(activate_card(handler, session, card_id), 200)
  let res =
    handler(
      simulate.request(http.Delete, "/api/v1/cards/" <> int.to_string(card_id))
      |> fixtures.with_auth(session),
    )

  expect.expect_status(res, 409)
  string.contains(simulate.read_body(res), "CARD_HAS_OPERATIONAL_HISTORY")
  |> expect.is_true
}
