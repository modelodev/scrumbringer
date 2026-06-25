import gleam/dynamic/decode
import gleam/erlang/charlist
import gleam/http
import gleam/http/request
import gleam/json
import gleam/list
import gleam/string
import pog
import scrumbringer_server
import support/assertions as expect
import wisp
import wisp/simulate

const secret = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

// Justification: large function kept intact to preserve cohesive logic.
pub fn rules_crud_with_selected_template_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  create_project(handler, session, csrf, "Core")
  let project_id =
    single_int(db, "select id from projects where name = 'Core'", [])

  create_task_type(handler, session, csrf, project_id, "QA", "bug-ant")
  let type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'QA'",
      [pog.int(project_id)],
    )

  let workflow_id =
    create_workflow(handler, session, csrf, project_id, "Rule Workflow")

  let template_id =
    create_template(
      handler,
      session,
      csrf,
      project_id,
      type_id,
      "Rule Template",
    )

  let rule_id =
    create_rule(
      handler,
      session,
      csrf,
      workflow_id,
      type_id,
      template_id,
      "Rule 1",
    )

  let list_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/workflows/" <> int_to_string(workflow_id) <> "/rules",
      )
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf),
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
      simulate.request(http.Patch, "/api/v1/rules/" <> int_to_string(rule_id))
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf)
      |> request.set_header("X-CSRF", csrf)
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
      simulate.request(http.Delete, "/api/v1/rules/" <> int_to_string(rule_id))
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf)
      |> request.set_header("X-CSRF", csrf),
    )

  expect.expect_status(delete_res, 204)
}

pub fn rule_delete_with_execution_pauses_and_preserves_history_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  create_project(handler, session, csrf, "RuleHistory")
  let project_id =
    single_int(db, "select id from projects where name = 'RuleHistory'", [])

  create_task_type(handler, session, csrf, project_id, "QA", "bug-ant")
  let type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'QA'",
      [pog.int(project_id)],
    )

  let workflow_id =
    create_workflow(handler, session, csrf, project_id, "History Workflow")

  let template_id =
    create_template(
      handler,
      session,
      csrf,
      project_id,
      type_id,
      "History Template",
    )

  let rule_id =
    create_rule(
      handler,
      session,
      csrf,
      workflow_id,
      type_id,
      template_id,
      "History Rule",
    )

  let task_id = insert_origin_task(db, project_id, type_id)
  insert_rule_execution(db, rule_id, task_id, "rule-delete")

  let delete_res =
    handler(
      simulate.request(http.Delete, "/api/v1/rules/" <> int_to_string(rule_id))
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf)
      |> request.set_header("X-CSRF", csrf),
    )

  expect.expect_status(delete_res, 204)
  single_int(db, "select count(*)::int from rules where id = $1", [
    pog.int(rule_id),
  ])
  |> expect.equal(1)
  single_bool(db, "select active from rules where id = $1", [pog.int(rule_id)])
  |> expect.equal(False)
  single_int(
    db,
    "select count(*)::int from rule_executions where rule_id = $1",
    [pog.int(rule_id)],
  )
  |> expect.equal(1)
}

pub fn rule_delete_with_created_task_pauses_and_preserves_origin_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  create_project(handler, session, csrf, "RuleOrigin")
  let project_id =
    single_int(db, "select id from projects where name = 'RuleOrigin'", [])

  create_task_type(handler, session, csrf, project_id, "QA", "bug-ant")
  let type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'QA'",
      [pog.int(project_id)],
    )

  let workflow_id =
    create_workflow(handler, session, csrf, project_id, "Origin Workflow")
  let template_id =
    create_template(handler, session, csrf, project_id, type_id, "Origin Task")
  let rule_id =
    create_rule(
      handler,
      session,
      csrf,
      workflow_id,
      type_id,
      template_id,
      "Origin Rule",
    )
  let created_task_id =
    insert_created_task_from_rule(db, project_id, type_id, rule_id)

  let delete_res =
    handler(
      simulate.request(http.Delete, "/api/v1/rules/" <> int_to_string(rule_id))
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf)
      |> request.set_header("X-CSRF", csrf),
    )

  expect.expect_status(delete_res, 204)
  single_int(db, "select count(*)::int from rules where id = $1", [
    pog.int(rule_id),
  ])
  |> expect.equal(1)
  single_bool(db, "select active from rules where id = $1", [pog.int(rule_id)])
  |> expect.equal(False)
  single_int(
    db,
    "select count(*)::int from tasks where id = $1 and created_from_rule_id = $2",
    [pog.int(created_task_id), pog.int(rule_id)],
  )
  |> expect.equal(1)
}

pub fn rules_invalid_payload_returns_400_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  // Create a valid project and workflow first
  create_project(handler, session, csrf, "InvalidPayloadTest")
  let project_id =
    single_int(
      db,
      "select id from projects where name = 'InvalidPayloadTest'",
      [],
    )

  let workflow_id =
    create_workflow(handler, session, csrf, project_id, "Test Workflow")

  // Now test with invalid payload (name is an int instead of string)
  let bad_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/workflows/" <> int_to_string(workflow_id) <> "/rules",
      )
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf)
      |> request.set_header("X-CSRF", csrf)
      |> simulate.json_body(json.object([#("name", json.int(1))])),
    )

  expect.expect_status(bad_res, 400)
}

pub fn rule_create_without_template_returns_400_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  create_project(handler, session, csrf, "MissingTemplateTest")
  let project_id =
    single_int(
      db,
      "select id from projects where name = 'MissingTemplateTest'",
      [],
    )
  create_task_type(handler, session, csrf, project_id, "Bug", "bug-ant")
  let type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Bug'",
      [pog.int(project_id)],
    )
  let workflow_id =
    create_workflow(handler, session, csrf, project_id, "Missing Template")

  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/workflows/" <> int_to_string(workflow_id) <> "/rules",
      )
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf)
      |> request.set_header("X-CSRF", csrf)
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
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  create_project(handler, session, csrf, "MissingCardDepthRule")
  let project_id =
    single_int(
      db,
      "select id from projects where name = 'MissingCardDepthRule'",
      [],
    )
  create_task_type(handler, session, csrf, project_id, "Checklist", "list")
  let type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Checklist'",
      [pog.int(project_id)],
    )
  let workflow_id =
    create_workflow(handler, session, csrf, project_id, "Card Depth Rule")
  let template_id =
    create_template(handler, session, csrf, project_id, type_id, "Card task")

  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/workflows/" <> int_to_string(workflow_id) <> "/rules",
      )
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf)
      |> request.set_header("X-CSRF", csrf)
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
  single_int(db, "select count(*)::int from rules where workflow_id = $1", [
    pog.int(workflow_id),
  ])
  |> expect.equal(0)
}

pub fn rules_project_scope_requires_project_manager_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_login_res =
    login_as(handler, "admin@example.com", "passwordpassword")
  let admin_session = find_cookie_value(admin_login_res.headers, "sb_session")
  let admin_csrf = find_cookie_value(admin_login_res.headers, "sb_csrf")

  create_project(handler, admin_session, admin_csrf, "Rule Permissions")
  let project_id =
    single_int(
      db,
      "select id from projects where name = 'Rule Permissions'",
      [],
    )

  create_task_type(handler, admin_session, admin_csrf, project_id, "QA", "bug")
  let type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'QA'",
      [pog.int(project_id)],
    )
  let workflow_id =
    create_workflow(handler, admin_session, admin_csrf, project_id, "Rules")
  let template_id =
    create_template(
      handler,
      admin_session,
      admin_csrf,
      project_id,
      type_id,
      "Follow-up",
    )
  let rule_id =
    create_rule(
      handler,
      admin_session,
      admin_csrf,
      workflow_id,
      type_id,
      template_id,
      "Protected Rule",
    )

  create_member_user(handler, db, "member@example.com", "rule_member_invite")
  let member_id =
    single_int(
      db,
      "select id from users where email = 'member@example.com'",
      [],
    )
  add_member(
    handler,
    admin_session,
    admin_csrf,
    project_id,
    member_id,
    "member",
  )

  let member_login_res =
    login_as(handler, "member@example.com", "passwordpassword")
  let member_session = find_cookie_value(member_login_res.headers, "sb_session")
  let member_csrf = find_cookie_value(member_login_res.headers, "sb_csrf")

  let list_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/workflows/" <> int_to_string(workflow_id) <> "/rules",
      )
      |> request.set_cookie("sb_session", member_session)
      |> request.set_cookie("sb_csrf", member_csrf),
    )
  expect.expect_status(list_res, 403)

  let create_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/workflows/" <> int_to_string(workflow_id) <> "/rules",
      )
      |> request.set_cookie("sb_session", member_session)
      |> request.set_cookie("sb_csrf", member_csrf)
      |> request.set_header("X-CSRF", member_csrf)
      |> simulate.json_body(rule_create_json(
        "Member Rule",
        type_id,
        template_id,
      )),
    )
  expect.expect_status(create_res, 403)

  let update_res =
    handler(
      simulate.request(http.Patch, "/api/v1/rules/" <> int_to_string(rule_id))
      |> request.set_cookie("sb_session", member_session)
      |> request.set_cookie("sb_csrf", member_csrf)
      |> request.set_header("X-CSRF", member_csrf)
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
      simulate.request(http.Delete, "/api/v1/rules/" <> int_to_string(rule_id))
      |> request.set_cookie("sb_session", member_session)
      |> request.set_cookie("sb_csrf", member_csrf)
      |> request.set_header("X-CSRF", member_csrf),
    )
  expect.expect_status(delete_res, 403)
  single_bool(db, "select active from rules where id = $1", [pog.int(rule_id)])
  |> expect.equal(True)
}

fn create_project(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  name: String,
) {
  let req =
    simulate.request(http.Post, "/api/v1/projects")
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> request.set_header("X-CSRF", csrf)
    |> simulate.json_body(project_create_json(name))

  let res = handler(req)
  expect.expect_status(res, 200)
}

fn project_create_json(name: String) -> json.Json {
  json.object([
    #("name", json.string(name)),
    #("healthy_pool_limit", json.int(20)),
    #(
      "card_depth_names",
      json.array(
        [
          project_depth_name_json(1, "Initiative", "Initiatives"),
          project_depth_name_json(2, "Feature", "Features"),
          project_depth_name_json(3, "Task group", "Task groups"),
        ],
        of: fn(value) { value },
      ),
    ),
  ])
}

fn project_depth_name_json(
  depth: Int,
  singular_name: String,
  plural_name: String,
) -> json.Json {
  json.object([
    #("depth", json.int(depth)),
    #("singular_name", json.string(singular_name)),
    #("plural_name", json.string(plural_name)),
  ])
}

fn create_task_type(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  project_id: Int,
  name: String,
  icon: String,
) {
  let req =
    simulate.request(
      http.Post,
      "/api/v1/projects/" <> int_to_string(project_id) <> "/task-types",
    )
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> request.set_header("X-CSRF", csrf)
    |> simulate.json_body(
      json.object([
        #("name", json.string(name)),
        #("icon", json.string(icon)),
      ]),
    )

  let res = handler(req)
  expect.expect_status(res, 200)
}

fn create_workflow(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  project_id: Int,
  name: String,
) -> Int {
  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/projects/" <> int_to_string(project_id) <> "/workflows",
      )
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf)
      |> request.set_header("X-CSRF", csrf)
      |> simulate.json_body(
        json.object([
          #("name", json.string(name)),
          #("description", json.string("Rules")),
        ]),
      ),
    )

  expect.expect_status(res, 200)
  decode_workflow_id(simulate.read_body(res))
}

fn create_template(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  project_id: Int,
  type_id: Int,
  name: String,
) -> Int {
  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/projects/" <> int_to_string(project_id) <> "/task-templates",
      )
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf)
      |> request.set_header("X-CSRF", csrf)
      |> simulate.json_body(
        json.object([
          #("name", json.string(name)),
          #("description", json.string("Template desc")),
          #("type_id", json.int(type_id)),
          #("priority", json.int(3)),
        ]),
      ),
    )

  expect.expect_status(res, 200)
  decode_template_id(simulate.read_body(res))
}

fn create_rule(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  workflow_id: Int,
  type_id: Int,
  template_id: Int,
  name: String,
) -> Int {
  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/workflows/" <> int_to_string(workflow_id) <> "/rules",
      )
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf)
      |> request.set_header("X-CSRF", csrf)
      |> simulate.json_body(
        json.object([
          #("name", json.string(name)),
          #("goal", json.string("Test")),
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
        ]),
      ),
    )

  expect.expect_status(res, 200)
  decode_rule_id(simulate.read_body(res))
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

fn add_member(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  project_id: Int,
  user_id: Int,
  role: String,
) {
  let req =
    simulate.request(
      http.Post,
      "/api/v1/projects/" <> int_to_string(project_id) <> "/members",
    )
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> request.set_header("X-CSRF", csrf)
    |> simulate.json_body(
      json.object([
        #("user_id", json.int(user_id)),
        #("role", json.string(role)),
      ]),
    )

  let res = handler(req)
  expect.expect_status(res, 200)
}

fn create_member_user(
  handler: fn(wisp.Request) -> wisp.Response,
  db: pog.Connection,
  email: String,
  invite_code: String,
) {
  insert_invite_link_active(db, invite_code, email)

  let req =
    simulate.request(http.Post, "/api/v1/auth/register")
    |> simulate.json_body(
      json.object([
        #("password", json.string("passwordpassword")),
        #("invite_token", json.string(invite_code)),
      ]),
    )

  let res = handler(req)
  expect.expect_status(res, 200)
}

fn decode_workflow_id(body: String) -> Int {
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let workflow_decoder = {
    use id <- decode.field("id", decode.int)
    decode.success(id)
  }

  let data_decoder = {
    use workflow <- decode.field("workflow", workflow_decoder)
    decode.success(workflow)
  }

  let response_decoder = {
    use workflow_id <- decode.field("data", data_decoder)
    decode.success(workflow_id)
  }

  let assert Ok(workflow_id) = decode.run(dynamic, response_decoder)
  workflow_id
}

fn decode_template_id(body: String) -> Int {
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let template_decoder = {
    use id <- decode.field("id", decode.int)
    decode.success(id)
  }

  let data_decoder = {
    use template <- decode.field("template", template_decoder)
    decode.success(template)
  }

  let response_decoder = {
    use template_id <- decode.field("data", data_decoder)
    decode.success(template_id)
  }

  let assert Ok(template_id) = decode.run(dynamic, response_decoder)
  template_id
}

fn decode_rule_id(body: String) -> Int {
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let rule_decoder = {
    use id <- decode.field("id", decode.int)
    decode.success(id)
  }

  let data_decoder = {
    use rule <- decode.field("rule", rule_decoder)
    decode.success(rule)
  }

  let response_decoder = {
    use rule_id <- decode.field("data", data_decoder)
    decode.success(rule_id)
  }

  let assert Ok(rule_id) = decode.run(dynamic, response_decoder)
  rule_id
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
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let rule_decoder = {
    use name <- decode.field("name", decode.string)
    decode.success(name)
  }

  let data_decoder = {
    use rules <- decode.field("rules", decode.list(rule_decoder))
    decode.success(rules)
  }

  let response_decoder = {
    use rules <- decode.field("data", data_decoder)
    decode.success(rules)
  }

  let assert Ok(rules) = decode.run(dynamic, response_decoder)
  rules
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

fn login_as(
  handler: fn(wisp.Request) -> wisp.Response,
  email: String,
  password: String,
) -> wisp.Response {
  let req =
    simulate.request(http.Post, "/api/v1/auth/login")
    |> simulate.json_body(
      json.object([
        #("email", json.string(email)),
        #("password", json.string(password)),
      ]),
    )

  handler(req)
}

fn new_test_app() -> scrumbringer_server.App {
  let database_url = require_database_url()
  let assert Ok(app) = scrumbringer_server.new_app(secret, database_url)
  app
}

fn bootstrap_app() -> scrumbringer_server.App {
  let app = new_test_app()
  let handler = scrumbringer_server.handler(app)
  let scrumbringer_server.App(db: db, ..) = app

  reset_db(db)
  reset_workflow_tables(db)

  let res =
    handler(bootstrap_request("admin@example.com", "passwordpassword", "Acme"))
  expect.expect_status(res, 200)

  app
}

fn bootstrap_request(email: String, password: String, org_name: String) {
  simulate.request(http.Post, "/api/v1/auth/register")
  |> simulate.json_body(
    json.object([
      #("email", json.string(email)),
      #("password", json.string(password)),
      #("org_name", json.string(org_name)),
    ]),
  )
}

fn set_cookie_headers(headers: List(#(String, String))) -> List(String) {
  headers
  |> list.filter_map(fn(h) {
    case h.0 {
      "set-cookie" -> Ok(h.1)
      _ -> Error(Nil)
    }
  })
}

fn find_cookie_value(headers: List(#(String, String)), name: String) -> String {
  let target = name <> "="

  let assert Ok(header) =
    set_cookie_headers(headers)
    |> list.find(fn(h) { string.starts_with(h, target) })

  let assert Ok(#(value, _)) =
    header
    |> string.drop_start(string.length(target))
    |> string.split_once(";")

  value
}

fn require_database_url() -> String {
  case getenv("DATABASE_URL", "") {
    "" -> {
      expect.fail()
      ""
    }

    url -> url
  }
}

fn reset_db(db: pog.Connection) {
  let assert Ok(_) =
    pog.query(
      "TRUNCATE project_members, org_invite_links, org_invites, users, projects, organizations RESTART IDENTITY CASCADE",
    )
    |> pog.execute(db)

  Nil
}

fn reset_workflow_tables(db: pog.Connection) {
  let assert Ok(_) =
    pog.query(
      "TRUNCATE rule_templates, rule_executions, rules, workflows, task_templates RESTART IDENTITY CASCADE",
    )
    |> pog.execute(db)

  Nil
}

fn single_int(db: pog.Connection, sql: String, params: List(pog.Value)) -> Int {
  let decoder = {
    use value <- decode.field(0, decode.int)
    decode.success(value)
  }

  let query =
    params
    |> list.fold(pog.query(sql), fn(query, param) {
      pog.parameter(query, param)
    })

  let assert Ok(pog.Returned(rows: [value, ..], ..)) =
    query
    |> pog.returning(decoder)
    |> pog.execute(db)

  value
}

fn single_bool(db: pog.Connection, sql: String, params: List(pog.Value)) -> Bool {
  let decoder = {
    use value <- decode.field(0, decode.bool)
    decode.success(value)
  }

  let query =
    params
    |> list.fold(pog.query(sql), fn(query, param) {
      pog.parameter(query, param)
    })

  let assert Ok(pog.Returned(rows: [value, ..], ..)) =
    query
    |> pog.returning(decoder)
    |> pog.execute(db)

  value
}

fn insert_origin_task(db: pog.Connection, project_id: Int, type_id: Int) -> Int {
  single_int(
    db,
    "insert into tasks (project_id, type_id, title, priority, execution_state, created_by, last_entered_pool_at) values ($1, $2, 'Automation origin', 3, 'closed', 1, now()) returning id",
    [pog.int(project_id), pog.int(type_id)],
  )
}

fn insert_created_task_from_rule(
  db: pog.Connection,
  project_id: Int,
  type_id: Int,
  rule_id: Int,
) -> Int {
  single_int(
    db,
    "insert into tasks (project_id, type_id, title, priority, execution_state, created_by, created_from_rule_id, last_entered_pool_at) values ($1, $2, 'Generated task', 3, 'available', 1, $3, now()) returning id",
    [pog.int(project_id), pog.int(type_id), pog.int(rule_id)],
  )
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
      "task:" <> int_to_string(task_id) <> ":" <> suffix,
    ))
    |> pog.parameter(pog.int(task_id))
    |> pog.execute(db)

  Nil
}

fn insert_invite_link_active(db: pog.Connection, token: String, email: String) {
  let assert Ok(_) =
    pog.query(
      "insert into org_invite_links (org_id, email, token, created_by) values (1, $1, $2, 1)",
    )
    |> pog.parameter(pog.text(email))
    |> pog.parameter(pog.text(token))
    |> pog.execute(db)

  Nil
}

fn int_to_string(value: Int) -> String {
  value |> int_to_string_unsafe
}

@external(erlang, "erlang", "integer_to_binary")
fn int_to_string_unsafe(value: Int) -> String

fn getenv(key: String, default: String) -> String {
  let key_charlist = charlist.from_string(key)
  let default_charlist = charlist.from_string(default)
  getenv_charlist(key_charlist, default_charlist)
  |> charlist.to_string
}

@external(erlang, "os", "getenv")
fn getenv_charlist(
  key: charlist.Charlist,
  default: charlist.Charlist,
) -> charlist.Charlist
