import gleam/dynamic/decode
import gleam/erlang/charlist
import gleam/http
import gleam/http/request
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import gleeunit/should
import pog
import scrumbringer_server
import wisp
import wisp/simulate

const secret = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

pub fn rules_crud_and_templates_test() {
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
    create_rule(handler, session, csrf, workflow_id, type_id, "Rule 1")

  let list_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/workflows/" <> int_to_string(workflow_id) <> "/rules",
      )
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf),
    )

  list_res.status |> should.equal(200)
  decode_rule_names(simulate.read_body(list_res))
  |> should.equal(["Rule 1"])

  let attach_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/rules/"
          <> int_to_string(rule_id)
          <> "/templates/"
          <> int_to_string(template_id),
      )
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf)
      |> request.set_header("X-CSRF", csrf)
      |> simulate.json_body(json.object([#("execution_order", json.int(1))])),
    )

  attach_res.status |> should.equal(200)
  decode_template_names(simulate.read_body(attach_res))
  |> should.equal(["Rule Template"])

  let patch_res =
    handler(
      simulate.request(http.Patch, "/api/v1/rules/" <> int_to_string(rule_id))
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf)
      |> request.set_header("X-CSRF", csrf)
      |> simulate.json_body(
        json.object([
          #("name", json.string("Rule 1 Updated")),
          #("active", json.int(0)),
        ]),
      ),
    )

  patch_res.status |> should.equal(200)
  decode_rule_name(simulate.read_body(patch_res))
  |> should.equal("Rule 1 Updated")

  let detach_res =
    handler(
      simulate.request(
        http.Delete,
        "/api/v1/rules/"
          <> int_to_string(rule_id)
          <> "/templates/"
          <> int_to_string(template_id),
      )
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf)
      |> request.set_header("X-CSRF", csrf),
    )

  detach_res.status |> should.equal(204)

  let delete_res =
    handler(
      simulate.request(http.Delete, "/api/v1/rules/" <> int_to_string(rule_id))
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf)
      |> request.set_header("X-CSRF", csrf),
    )

  delete_res.status |> should.equal(204)
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

  bad_res.status |> should.equal(400)
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
    |> simulate.json_body(json.object([#("name", json.string(name))]))

  let res = handler(req)
  res.status |> should.equal(200)
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
  res.status |> should.equal(200)
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

  res.status |> should.equal(200)
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

  res.status |> should.equal(200)
  decode_template_id(simulate.read_body(res))
}

fn create_rule(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  workflow_id: Int,
  type_id: Int,
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
          #("resource_type", json.string("task")),
          #("task_type_id", json.int(type_id)),
          #("to_state", json.string("completed")),
          #("active", json.bool(True)),
        ]),
      ),
    )

  res.status |> should.equal(200)
  decode_rule_id(simulate.read_body(res))
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

fn decode_template_names(body: String) -> List(String) {
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let template_decoder = {
    use name <- decode.field("name", decode.string)
    decode.success(name)
  }

  let data_decoder = {
    use templates <- decode.field("templates", decode.list(template_decoder))
    decode.success(templates)
  }

  let response_decoder = {
    use templates <- decode.field("data", data_decoder)
    decode.success(templates)
  }

  let assert Ok(templates) = decode.run(dynamic, response_decoder)
  templates
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
  res.status |> should.equal(200)

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

  let #(value, _) =
    header
    |> string.drop_start(string.length(target))
    |> string.split_once(";")
    |> result.unwrap(#("", ""))

  value
}

fn require_database_url() -> String {
  case getenv("DATABASE_URL", "") {
    "" -> {
      should.fail()
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
