import fixtures
import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import pog
import scrumbringer_server
import support/assertions as expect
import wisp/simulate

pub fn workflows_project_crud_and_active_cascade_test() {
  let #(app, handler, session) = fixtures.bootstrap() |> expect.ok
  let scrumbringer_server.App(db: db, ..) = app

  let project_id = fixtures.default_project_id(db) |> expect.ok

  let workflow_id =
    fixtures.create_workflow(handler, session, project_id, "Project Workflow")
    |> expect.ok

  insert_rule(db, workflow_id)

  let patch_res =
    handler(
      simulate.request(
        http.Patch,
        "/api/v1/workflows/" <> int.to_string(workflow_id),
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(
        json.object([
          #("active", json.bool(False)),
        ]),
      ),
    )

  expect.expect_status(patch_res, 200)
  rule_active(db, workflow_id) |> expect.equal(False)

  let list_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/workflows",
      )
      |> fixtures.with_auth(session),
    )

  expect.expect_status(list_res, 200)
  decode_workflow_names(simulate.read_body(list_res))
  |> expect.equal(["Project Workflow"])

  let delete_res =
    handler(
      simulate.request(
        http.Delete,
        "/api/v1/workflows/" <> int.to_string(workflow_id),
      )
      |> fixtures.with_auth(session),
    )

  expect.expect_status(delete_res, 204)
}

pub fn workflow_delete_with_execution_pauses_and_preserves_history_test() {
  let #(app, handler, session) = fixtures.bootstrap() |> expect.ok
  let scrumbringer_server.App(db: db, ..) = app

  let project_id = fixtures.default_project_id(db) |> expect.ok

  let workflow_id =
    fixtures.create_workflow(handler, session, project_id, "Workflow History")
    |> expect.ok
  let rule_id = insert_rule(db, workflow_id)
  let type_id = insert_task_type(db, project_id)
  let task_id = insert_origin_task(db, project_id, type_id)
  insert_rule_execution(db, rule_id, task_id, "workflow-delete")

  let delete_res =
    handler(
      simulate.request(
        http.Delete,
        "/api/v1/workflows/" <> int.to_string(workflow_id),
      )
      |> fixtures.with_auth(session),
    )

  expect.expect_status(delete_res, 204)
  fixtures.query_int(db, "select count(*)::int from workflows where id = $1", [
    pog.int(workflow_id),
  ])
  |> expect.ok
  |> expect.equal(1)
  workflow_active(db, workflow_id) |> expect.equal(False)
  rule_active(db, workflow_id) |> expect.equal(False)
  fixtures.query_int(
    db,
    "select count(*)::int from rule_executions where rule_id = $1",
    [pog.int(rule_id)],
  )
  |> expect.ok
  |> expect.equal(1)
}

pub fn workflow_delete_with_created_task_pauses_and_preserves_origin_test() {
  let #(app, handler, session) = fixtures.bootstrap() |> expect.ok
  let scrumbringer_server.App(db: db, ..) = app

  let project_id = fixtures.default_project_id(db) |> expect.ok

  let workflow_id =
    fixtures.create_workflow(handler, session, project_id, "Workflow Origin")
    |> expect.ok
  let rule_id = insert_rule(db, workflow_id)
  let type_id = insert_task_type(db, project_id)
  let created_task_id =
    insert_created_task_from_rule(db, project_id, type_id, rule_id)

  let delete_res =
    handler(
      simulate.request(
        http.Delete,
        "/api/v1/workflows/" <> int.to_string(workflow_id),
      )
      |> fixtures.with_auth(session),
    )

  expect.expect_status(delete_res, 204)
  fixtures.query_int(db, "select count(*)::int from workflows where id = $1", [
    pog.int(workflow_id),
  ])
  |> expect.ok
  |> expect.equal(1)
  workflow_active(db, workflow_id) |> expect.equal(False)
  rule_active(db, workflow_id) |> expect.equal(False)
  fixtures.query_int(
    db,
    "select count(*)::int from tasks where id = $1 and created_from_rule_id = $2",
    [pog.int(created_task_id), pog.int(rule_id)],
  )
  |> expect.ok
  |> expect.equal(1)
}

pub fn workflows_project_scope_requires_project_manager_test() {
  let #(app, handler, admin_session) = fixtures.bootstrap() |> expect.ok
  let scrumbringer_server.App(db: db, ..) = app

  let project_id =
    fixtures.create_project(handler, admin_session, "Core")
    |> expect.ok

  let member_id =
    fixtures.create_member_user(handler, db, "member@example.com", "inv_member")
    |> expect.ok

  fixtures.add_member(handler, admin_session, project_id, member_id, "member")
  |> expect.ok

  let member_session =
    fixtures.login(handler, "member@example.com", "passwordpassword")
    |> expect.ok

  let list_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/workflows",
      )
      |> fixtures.with_auth(member_session),
    )

  expect.expect_status(list_res, 403)

  let create_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/workflows",
      )
      |> fixtures.with_auth(member_session)
      |> simulate.json_body(
        json.object([
          #("name", json.string("Proj Workflow")),
          #("description", json.string("Proj desc")),
        ]),
      ),
    )

  expect.expect_status(create_res, 403)
}

pub fn workflows_project_list_filters_scope_test() {
  let #(app, handler, session) = fixtures.bootstrap() |> expect.ok
  let scrumbringer_server.App(db: db, ..) = app

  let default_project_id = fixtures.default_project_id(db) |> expect.ok

  let core_project_id =
    fixtures.create_project(handler, session, "Core")
    |> expect.ok

  // Create workflow in default project
  fixtures.create_workflow(
    handler,
    session,
    default_project_id,
    "Default Workflow",
  )
  |> expect.ok

  // Create workflow in Core project
  fixtures.create_workflow(handler, session, core_project_id, "Core Workflow")
  |> expect.ok

  // List Core project workflows - should only show Core Workflow
  let list_core_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/projects/" <> int.to_string(core_project_id) <> "/workflows",
      )
      |> fixtures.with_auth(session),
    )

  expect.expect_status(list_core_res, 200)
  decode_workflow_names(simulate.read_body(list_core_res))
  |> expect.equal(["Core Workflow"])
}

pub fn workflows_duplicate_name_in_same_project_is_rejected_test() {
  let #(app, handler, session) = fixtures.bootstrap() |> expect.ok
  let scrumbringer_server.App(db: db, ..) = app

  let project_id = fixtures.default_project_id(db) |> expect.ok

  fixtures.create_workflow(handler, session, project_id, "Dup Workflow")
  |> expect.ok

  let dup_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/workflows",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(
        json.object([
          #("name", json.string("Dup Workflow")),
          #("description", json.string("Second")),
        ]),
      ),
    )

  expect.expect_status(dup_res, 422)
}

pub fn workflows_invalid_payload_returns_400_test() {
  let #(app, handler, session) = fixtures.bootstrap() |> expect.ok
  let scrumbringer_server.App(db: db, ..) = app

  let project_id = fixtures.default_project_id(db) |> expect.ok

  let bad_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/workflows",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("name", json.int(1))])),
    )

  expect.expect_status(bad_res, 400)
}

fn decode_workflow_names(body: String) -> List(String) {
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let workflow_decoder = {
    use name <- decode.field("name", decode.string)
    decode.success(name)
  }

  let data_decoder = {
    use workflows <- decode.field("workflows", decode.list(workflow_decoder))
    decode.success(workflows)
  }

  let response_decoder = {
    use workflows <- decode.field("data", data_decoder)
    decode.success(workflows)
  }

  let assert Ok(workflows) = decode.run(dynamic, response_decoder)
  workflows
}

fn insert_rule(db: pog.Connection, workflow_id: Int) -> Int {
  fixtures.query_int(
    db,
    "insert into rules (workflow_id, name, goal, resource_type, trigger_kind, task_type_id, to_state, active) values ($1, 'Rule', 'Goal', 'task', 'task_closed', null, 'closed', true) returning id",
    [pog.int(workflow_id)],
  )
  |> expect.ok
}

fn rule_active(db: pog.Connection, workflow_id: Int) -> Bool {
  let decoder = {
    use active <- decode.field(0, decode.bool)
    decode.success(active)
  }

  let assert Ok(pog.Returned(rows: [active, ..], ..)) =
    pog.query("select active from rules where workflow_id = $1 limit 1")
    |> pog.parameter(pog.int(workflow_id))
    |> pog.returning(decoder)
    |> pog.execute(db)

  active
}

fn workflow_active(db: pog.Connection, workflow_id: Int) -> Bool {
  let decoder = {
    use active <- decode.field(0, decode.bool)
    decode.success(active)
  }

  let assert Ok(pog.Returned(rows: [active, ..], ..)) =
    pog.query("select active from workflows where id = $1")
    |> pog.parameter(pog.int(workflow_id))
    |> pog.returning(decoder)
    |> pog.execute(db)

  active
}

fn insert_task_type(db: pog.Connection, project_id: Int) -> Int {
  fixtures.query_int(
    db,
    "insert into task_types (project_id, name, icon) values ($1, 'Workflow QA', 'bug-ant') returning id",
    [pog.int(project_id)],
  )
  |> expect.ok
}

fn insert_origin_task(db: pog.Connection, project_id: Int, type_id: Int) -> Int {
  let card_id = insert_active_card(db, project_id, "Automation origin card")
  fixtures.query_int(
    db,
    "insert into tasks (project_id, type_id, title, priority, execution_state, created_by, card_id, last_entered_pool_at) values ($1, $2, 'Automation origin', 3, 'closed', 1, $3, now()) returning id",
    [pog.int(project_id), pog.int(type_id), pog.int(card_id)],
  )
  |> expect.ok
}

fn insert_created_task_from_rule(
  db: pog.Connection,
  project_id: Int,
  type_id: Int,
  rule_id: Int,
) -> Int {
  let card_id = insert_active_card(db, project_id, "Generated task card")
  fixtures.query_int(
    db,
    "insert into tasks (project_id, type_id, title, priority, execution_state, created_by, card_id, created_from_rule_id, last_entered_pool_at) values ($1, $2, 'Generated task', 3, 'available', 1, $3, $4, now()) returning id",
    [pog.int(project_id), pog.int(type_id), pog.int(card_id), pog.int(rule_id)],
  )
  |> expect.ok
}

fn insert_active_card(db: pog.Connection, project_id: Int, title: String) -> Int {
  fixtures.query_int(
    db,
    "insert into cards (project_id, title, description, created_by, execution_state) values ($1, $2, '', 1, 'active') returning id",
    [pog.int(project_id), pog.text(title)],
  )
  |> expect.ok
}

fn insert_rule_execution(
  db: pog.Connection,
  rule_id: Int,
  task_id: Int,
  suffix: String,
) {
  let assert Ok(_) =
    pog.query(
      "insert into rule_executions (rule_id, event_key, task_id, outcome, user_id) values ($1, $2, $3, 'applied', 1)",
    )
    |> pog.parameter(pog.int(rule_id))
    |> pog.parameter(pog.text(
      "task:" <> int.to_string(task_id) <> ":" <> suffix,
    ))
    |> pog.parameter(pog.int(task_id))
    |> pog.execute(db)

  Nil
}
