import fixtures
import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/option.{Some}
import gleam/string
import pog
import scrumbringer_server
import support/assertions as expect
import wisp/simulate

// Justification: large function kept intact to preserve cohesive logic.
pub fn rules_crud_with_selected_template_test() {
  let #(_, handler, session) = fixtures.bootstrap() |> expect.ok

  let project_id =
    fixtures.create_project(handler, session, "Core")
    |> expect.ok

  let type_id =
    fixtures.create_task_type(handler, session, project_id, "QA", "bug-ant")
    |> expect.ok

  let workflow_id =
    fixtures.create_workflow(handler, session, project_id, "Rule Workflow")
    |> expect.ok

  let template_id =
    fixtures.create_template(
      handler,
      session,
      project_id,
      type_id,
      "Rule Template",
    )
    |> expect.ok

  let rule_id =
    fixtures.create_task_rule_with_trigger(
      handler,
      session,
      workflow_id,
      Some(type_id),
      "Rule 1",
      "task_closed",
      template_id,
    )
    |> expect.ok

  let list_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/workflows/" <> int.to_string(workflow_id) <> "/rules",
      )
      |> fixtures.with_auth(session),
    )

  expect.expect_status(list_res, 200)
  let list_body = simulate.read_body(list_res)
  let assert False = string.contains(list_body, "\"active\":")
  decode_rule_names(list_body)
  |> expect.equal(["Rule 1"])
  decode_first_rule_template_name(list_body)
  |> expect.equal("Rule Template")

  let patch_res =
    handler(
      simulate.request(http.Patch, "/api/v1/rules/" <> int.to_string(rule_id))
      |> fixtures.with_auth(session)
      |> simulate.json_body(
        json.object([
          #("name", json.string("Rule 1 Updated")),
          #("status", json.object([#("type", json.string("paused"))])),
        ]),
      ),
    )

  expect.expect_status(patch_res, 200)
  let patch_body = simulate.read_body(patch_res)
  let assert False = string.contains(patch_body, "\"active\":")
  decode_rule_name(patch_body)
  |> expect.equal("Rule 1 Updated")

  let delete_res =
    handler(
      simulate.request(http.Delete, "/api/v1/rules/" <> int.to_string(rule_id))
      |> fixtures.with_auth(session),
    )

  expect.expect_status(delete_res, 204)
}

pub fn rule_delete_with_execution_pauses_and_preserves_history_test() {
  let #(app, handler, session) = fixtures.bootstrap() |> expect.ok
  let scrumbringer_server.App(db: db, ..) = app

  let project_id =
    fixtures.create_project(handler, session, "RuleHistory")
    |> expect.ok

  let type_id =
    fixtures.create_task_type(handler, session, project_id, "QA", "bug-ant")
    |> expect.ok

  let workflow_id =
    fixtures.create_workflow(handler, session, project_id, "History Workflow")
    |> expect.ok

  let template_id =
    fixtures.create_template(
      handler,
      session,
      project_id,
      type_id,
      "History Template",
    )
    |> expect.ok

  let rule_id =
    fixtures.create_task_rule_with_trigger(
      handler,
      session,
      workflow_id,
      Some(type_id),
      "History Rule",
      "task_closed",
      template_id,
    )
    |> expect.ok

  let task_id = insert_origin_task(db, project_id, type_id)
  insert_rule_execution(db, rule_id, task_id, "rule-delete")

  let delete_res =
    handler(
      simulate.request(http.Delete, "/api/v1/rules/" <> int.to_string(rule_id))
      |> fixtures.with_auth(session),
    )

  expect.expect_status(delete_res, 204)
  fixtures.query_int(db, "select count(*)::int from rules where id = $1", [
    pog.int(rule_id),
  ])
  |> expect.ok
  |> expect.equal(1)
  fixtures.query_bool(db, "select active from rules where id = $1", [
    pog.int(rule_id),
  ])
  |> expect.ok
  |> expect.equal(False)
  fixtures.query_int(
    db,
    "select count(*)::int from rule_executions where rule_id = $1",
    [pog.int(rule_id)],
  )
  |> expect.ok
  |> expect.equal(1)
}

pub fn rule_delete_with_created_task_pauses_and_preserves_origin_test() {
  let #(app, handler, session) = fixtures.bootstrap() |> expect.ok
  let scrumbringer_server.App(db: db, ..) = app

  let project_id =
    fixtures.create_project(handler, session, "RuleOrigin")
    |> expect.ok

  let type_id =
    fixtures.create_task_type(handler, session, project_id, "QA", "bug-ant")
    |> expect.ok

  let workflow_id =
    fixtures.create_workflow(handler, session, project_id, "Origin Workflow")
    |> expect.ok
  let template_id =
    fixtures.create_template(
      handler,
      session,
      project_id,
      type_id,
      "Origin Task",
    )
    |> expect.ok
  let rule_id =
    fixtures.create_task_rule_with_trigger(
      handler,
      session,
      workflow_id,
      Some(type_id),
      "Origin Rule",
      "task_closed",
      template_id,
    )
    |> expect.ok
  let created_task_id =
    insert_created_task_from_rule(db, project_id, type_id, rule_id)

  let delete_res =
    handler(
      simulate.request(http.Delete, "/api/v1/rules/" <> int.to_string(rule_id))
      |> fixtures.with_auth(session),
    )

  expect.expect_status(delete_res, 204)
  fixtures.query_int(db, "select count(*)::int from rules where id = $1", [
    pog.int(rule_id),
  ])
  |> expect.ok
  |> expect.equal(1)
  fixtures.query_bool(db, "select active from rules where id = $1", [
    pog.int(rule_id),
  ])
  |> expect.ok
  |> expect.equal(False)
  fixtures.query_int(
    db,
    "select count(*)::int from tasks where id = $1 and created_from_rule_id = $2",
    [pog.int(created_task_id), pog.int(rule_id)],
  )
  |> expect.ok
  |> expect.equal(1)
}

pub fn rules_invalid_payload_returns_400_test() {
  let #(_, handler, session) = fixtures.bootstrap() |> expect.ok

  // Create a valid project and workflow first
  let project_id =
    fixtures.create_project(handler, session, "InvalidPayloadTest")
    |> expect.ok

  let workflow_id =
    fixtures.create_workflow(handler, session, project_id, "Test Workflow")
    |> expect.ok

  // Now test with invalid payload (name is an int instead of string)
  let bad_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/workflows/" <> int.to_string(workflow_id) <> "/rules",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("name", json.int(1))])),
    )

  expect.expect_status(bad_res, 400)
}

pub fn rule_create_without_template_returns_400_test() {
  let #(_, handler, session) = fixtures.bootstrap() |> expect.ok

  let project_id =
    fixtures.create_project(handler, session, "MissingTemplateTest")
    |> expect.ok
  let type_id =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
    |> expect.ok
  let workflow_id =
    fixtures.create_workflow(handler, session, project_id, "Missing Template")
    |> expect.ok

  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/workflows/" <> int.to_string(workflow_id) <> "/rules",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(
        json.object([
          #("name", json.string("No Template")),
          #("goal", json.string("Should fail")),
          #(
            "trigger",
            json.object([
              #("type", json.string("task_closed")),
              #("task_type_id", json.int(type_id)),
            ]),
          ),
          #("status", json.object([#("type", json.string("active"))])),
        ]),
      ),
    )

  expect.expect_status(res, 400)
}

pub fn rule_create_rejects_missing_card_depth_scope_test() {
  let #(app, handler, session) = fixtures.bootstrap() |> expect.ok
  let scrumbringer_server.App(db: db, ..) = app

  let project_id =
    fixtures.create_project(handler, session, "MissingCardDepthRule")
    |> expect.ok
  let type_id =
    fixtures.create_task_type(handler, session, project_id, "Checklist", "list")
    |> expect.ok
  let workflow_id =
    fixtures.create_workflow(handler, session, project_id, "Card Depth Rule")
    |> expect.ok
  let template_id =
    fixtures.create_template(handler, session, project_id, type_id, "Card task")
    |> expect.ok

  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/workflows/" <> int.to_string(workflow_id) <> "/rules",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(
        json.object([
          #("name", json.string("Stale card depth")),
          #("goal", json.string("Should fail")),
          #(
            "trigger",
            json.object([
              #("type", json.string("card_closed")),
              #(
                "scope",
                json.object([
                  #("type", json.string("at_depth")),
                  #("depth", json.int(9)),
                ]),
              ),
            ]),
          ),
          #(
            "action",
            json.object([
              #("type", json.string("create_task")),
              #("template_id", json.int(template_id)),
            ]),
          ),
          #("status", json.object([#("type", json.string("active"))])),
        ]),
      ),
    )

  expect.expect_status(res, 422)
  let body = simulate.read_body(res)
  let assert True = string.contains(body, "Card level is no longer available")
  fixtures.query_int(
    db,
    "select count(*)::int from rules where workflow_id = $1",
    [
      pog.int(workflow_id),
    ],
  )
  |> expect.ok
  |> expect.equal(0)
}

pub fn rules_project_scope_requires_project_manager_test() {
  let #(app, handler, admin_session) = fixtures.bootstrap() |> expect.ok
  let scrumbringer_server.App(db: db, ..) = app

  let project_id =
    fixtures.create_project(handler, admin_session, "Rule Permissions")
    |> expect.ok

  let type_id =
    fixtures.create_task_type(handler, admin_session, project_id, "QA", "bug")
    |> expect.ok
  let workflow_id =
    fixtures.create_workflow(handler, admin_session, project_id, "Rules")
    |> expect.ok
  let template_id =
    fixtures.create_template(
      handler,
      admin_session,
      project_id,
      type_id,
      "Follow-up",
    )
    |> expect.ok
  let rule_id =
    fixtures.create_task_rule_with_trigger(
      handler,
      admin_session,
      workflow_id,
      Some(type_id),
      "Protected Rule",
      "task_closed",
      template_id,
    )
    |> expect.ok

  let member_id =
    fixtures.create_member_user(
      handler,
      db,
      "member@example.com",
      "rule_member_invite",
    )
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
        "/api/v1/workflows/" <> int.to_string(workflow_id) <> "/rules",
      )
      |> fixtures.with_auth(member_session),
    )
  expect.expect_status(list_res, 403)

  let create_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/workflows/" <> int.to_string(workflow_id) <> "/rules",
      )
      |> fixtures.with_auth(member_session)
      |> simulate.json_body(rule_create_json(
        "Member Rule",
        type_id,
        template_id,
      )),
    )
  expect.expect_status(create_res, 403)

  let update_res =
    handler(
      simulate.request(http.Patch, "/api/v1/rules/" <> int.to_string(rule_id))
      |> fixtures.with_auth(member_session)
      |> simulate.json_body(
        json.object([
          #("name", json.string("Member Updated Rule")),
          #("status", json.object([#("type", json.string("paused"))])),
        ]),
      ),
    )
  expect.expect_status(update_res, 403)

  let delete_res =
    handler(
      simulate.request(http.Delete, "/api/v1/rules/" <> int.to_string(rule_id))
      |> fixtures.with_auth(member_session),
    )
  expect.expect_status(delete_res, 403)
  fixtures.query_bool(db, "select active from rules where id = $1", [
    pog.int(rule_id),
  ])
  |> expect.ok
  |> expect.equal(True)
}

fn rule_create_json(name: String, type_id: Int, template_id: Int) -> json.Json {
  json.object([
    #("name", json.string(name)),
    #("goal", json.string("Member should not save this")),
    #(
      "trigger",
      json.object([
        #("type", json.string("task_closed")),
        #("task_type_id", json.int(type_id)),
      ]),
    ),
    #(
      "action",
      json.object([
        #("type", json.string("create_task")),
        #("template_id", json.int(template_id)),
      ]),
    ),
    #("status", json.object([#("type", json.string("active"))])),
  ])
}

fn decode_rule_name(body: String) -> String {
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let rule_decoder = {
    use name <- decode.field("name", decode.string)
    decode.success(name)
  }

  let data_decoder = {
    use rule <- decode.field("rule", rule_decoder)
    decode.success(rule)
  }

  let response_decoder = {
    use name <- decode.field("data", data_decoder)
    decode.success(name)
  }

  let assert Ok(name) = decode.run(dynamic, response_decoder)
  name
}

fn decode_rule_names(body: String) -> List(String) {
  fixtures.require_data_string_list_field(body, "rules", "name")
}

fn decode_first_rule_template_name(body: String) -> String {
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let template_decoder = {
    use name <- decode.field("name", decode.string)
    decode.success(name)
  }

  let rule_decoder = {
    use template <- decode.field("template", template_decoder)
    decode.success(template)
  }

  let data_decoder = {
    use rules <- decode.field("rules", decode.list(rule_decoder))
    decode.success(rules)
  }

  let response_decoder = {
    use rules <- decode.field("data", data_decoder)
    decode.success(rules)
  }

  let assert Ok([name, ..]) = decode.run(dynamic, response_decoder)
  name
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
