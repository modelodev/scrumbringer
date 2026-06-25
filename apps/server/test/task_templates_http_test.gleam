import gleam/dynamic/decode
import gleam/erlang/charlist
import gleam/http
import gleam/http/request
import gleam/int
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
pub fn task_templates_project_crud_test() {
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

  let create_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/task-templates",
      )
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf)
      |> request.set_header("X-CSRF", csrf)
      |> simulate.json_body(
        json.object([
          #("name", json.string("Project Template")),
          #("description", json.string("Project desc")),
          #("type_id", json.int(type_id)),
          #("priority", json.int(4)),
        ]),
      ),
    )

  expect.expect_status(create_res, 200)
  let template_id = decode_template_id(simulate.read_body(create_res))
  let created_version =
    single_int(db, "select version from task_templates where id = $1", [
      pog.int(template_id),
    ])
  created_version |> expect.equal(1)

  let list_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/task-templates",
      )
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf),
    )

  expect.expect_status(list_res, 200)
  decode_template_names(simulate.read_body(list_res))
  |> expect.equal(["Project Template"])

  let patch_res =
    handler(
      simulate.request(
        http.Patch,
        "/api/v1/task-templates/" <> int.to_string(template_id),
      )
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf)
      |> request.set_header("X-CSRF", csrf)
      |> simulate.json_body(
        json.object([
          #("name", json.string("Project Updated")),
          #("priority", json.int(2)),
        ]),
      ),
    )

  expect.expect_status(patch_res, 200)
  decode_template_name(simulate.read_body(patch_res))
  |> expect.equal("Project Updated")
  let updated_version =
    single_int(db, "select version from task_templates where id = $1", [
      pog.int(template_id),
    ])
  updated_version |> expect.equal(2)

  let delete_res =
    handler(
      simulate.request(
        http.Delete,
        "/api/v1/task-templates/" <> int.to_string(template_id),
      )
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf)
      |> request.set_header("X-CSRF", csrf),
    )

  expect.expect_status(delete_res, 204)

  let list_after_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/task-templates",
      )
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf),
    )

  expect.expect_status(list_after_res, 200)
  decode_template_names(simulate.read_body(list_after_res))
  |> expect.equal([])
}

pub fn task_template_used_by_rule_cannot_be_deleted_test() {
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

  let template_id =
    create_template(
      handler,
      session,
      csrf,
      project_id,
      type_id,
      "Protected Template",
    )
  let workflow_id =
    create_workflow(handler, session, csrf, project_id, "Release flow")

  create_rule(
    handler,
    session,
    csrf,
    workflow_id,
    type_id,
    template_id,
    "Development done",
  )

  let delete_res =
    handler(
      simulate.request(
        http.Delete,
        "/api/v1/task-templates/" <> int.to_string(template_id),
      )
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf)
      |> request.set_header("X-CSRF", csrf),
    )

  expect.expect_status(delete_res, 409)
  let body = simulate.read_body(delete_res)
  expect.expect_json_contains_code(body, "CONFLICT")
  let assert True = string.contains(body, "Pause or update")

  let list_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/task-templates",
      )
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf),
    )

  expect.expect_status(list_res, 200)
  decode_template_names(simulate.read_body(list_res))
  |> expect.equal(["Protected Template"])
}

pub fn task_template_with_only_execution_history_archives_on_delete_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  create_project(handler, session, csrf, "TemplateHistory")
  let project_id =
    single_int(db, "select id from projects where name = 'TemplateHistory'", [])

  create_task_type(handler, session, csrf, project_id, "QA", "bug-ant")
  let type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'QA'",
      [pog.int(project_id)],
    )

  let workflow_id =
    create_workflow(handler, session, csrf, project_id, "History Engine")
  let template_id =
    create_template(
      handler,
      session,
      csrf,
      project_id,
      type_id,
      "Historical Template",
    )
  let rule_id = insert_rule_without_template(db, workflow_id, type_id)
  let task_id = insert_origin_task(db, project_id, type_id)
  insert_template_execution(db, rule_id, template_id, task_id)

  let delete_res =
    handler(
      simulate.request(
        http.Delete,
        "/api/v1/task-templates/" <> int.to_string(template_id),
      )
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf)
      |> request.set_header("X-CSRF", csrf),
    )

  expect.expect_status(delete_res, 204)
  single_int(
    db,
    "select count(*)::int from task_templates where id = $1 and archived_at is not null",
    [pog.int(template_id)],
  )
  |> expect.equal(1)
  single_int(
    db,
    "select count(*)::int from automation_config_events where entity_type = 'template' and entity_id = $1 and change_type = 'archived'",
    [pog.int(template_id)],
  )
  |> expect.equal(1)

  let list_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/task-templates",
      )
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf),
    )

  expect.expect_status(list_res, 200)
  decode_template_names(simulate.read_body(list_res))
  |> expect.equal([])
}

pub fn task_templates_project_scope_requires_project_manager_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_login_res =
    login_as(handler, "admin@example.com", "passwordpassword")
  let admin_session = find_cookie_value(admin_login_res.headers, "sb_session")
  let admin_csrf = find_cookie_value(admin_login_res.headers, "sb_csrf")

  create_project(handler, admin_session, admin_csrf, "Core")
  let project_id =
    single_int(db, "select id from projects where name = 'Core'", [])

  create_task_type(
    handler,
    admin_session,
    admin_csrf,
    project_id,
    "QA",
    "bug-ant",
  )
  let type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'QA'",
      [pog.int(project_id)],
    )

  create_member_user(handler, db, "member@example.com", "inv_member")
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

  let create_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/task-templates",
      )
      |> request.set_cookie("sb_session", member_session)
      |> request.set_cookie("sb_csrf", member_csrf)
      |> request.set_header("X-CSRF", member_csrf)
      |> simulate.json_body(
        json.object([
          #("name", json.string("Proj Template")),
          #("description", json.string("Desc")),
          #("type_id", json.int(type_id)),
          #("priority", json.int(3)),
        ]),
      ),
    )

  expect.expect_status(create_res, 403)

  let list_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/task-templates",
      )
      |> request.set_cookie("sb_session", member_session)
      |> request.set_cookie("sb_csrf", member_csrf),
    )

  expect.expect_status(list_res, 403)
}

pub fn task_templates_project_list_filters_scope_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  let default_project_id = get_default_project_id(db)

  create_project(handler, session, csrf, "Core")
  let core_project_id =
    single_int(db, "select id from projects where name = 'Core'", [])

  // Create task type in each project
  create_task_type(handler, session, csrf, default_project_id, "Bug", "bug-ant")
  create_task_type(handler, session, csrf, core_project_id, "QA", "bug-ant")

  let default_type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Bug'",
      [pog.int(default_project_id)],
    )
  let core_type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'QA'",
      [pog.int(core_project_id)],
    )

  // Create template in default project
  let _default_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/projects/"
          <> int.to_string(default_project_id)
          <> "/task-templates",
      )
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf)
      |> request.set_header("X-CSRF", csrf)
      |> simulate.json_body(
        json.object([
          #("name", json.string("Default Template")),
          #("description", json.string("Default desc")),
          #("type_id", json.int(default_type_id)),
          #("priority", json.int(4)),
        ]),
      ),
    )

  // Create template in Core project
  let _core_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/projects/"
          <> int.to_string(core_project_id)
          <> "/task-templates",
      )
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf)
      |> request.set_header("X-CSRF", csrf)
      |> simulate.json_body(
        json.object([
          #("name", json.string("Core Template")),
          #("description", json.string("Core desc")),
          #("type_id", json.int(core_type_id)),
          #("priority", json.int(3)),
        ]),
      ),
    )

  // List Core project templates - should only show Core Template
  let list_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/projects/"
          <> int.to_string(core_project_id)
          <> "/task-templates",
      )
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf),
    )

  expect.expect_status(list_res, 200)
  decode_template_names(simulate.read_body(list_res))
  |> expect.equal(["Core Template"])
}

pub fn task_templates_invalid_type_id_returns_422_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let project_id = get_default_project_id(db)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  let create_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/task-templates",
      )
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf)
      |> request.set_header("X-CSRF", csrf)
      |> simulate.json_body(
        json.object([
          #("name", json.string("Bad Template")),
          #("description", json.string("Desc")),
          #("type_id", json.int(99_999)),
          #("priority", json.int(3)),
        ]),
      ),
    )

  expect.expect_status(create_res, 422)
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

fn decode_template_name(body: String) -> String {
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let template_decoder = {
    use name <- decode.field("name", decode.string)
    decode.success(name)
  }

  let data_decoder = {
    use template <- decode.field("template", template_decoder)
    decode.success(template)
  }

  let response_decoder = {
    use name <- decode.field("data", data_decoder)
    decode.success(name)
  }

  let assert Ok(name) = decode.run(dynamic, response_decoder)
  name
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
        "/api/v1/projects/" <> int.to_string(project_id) <> "/task-templates",
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
        "/api/v1/projects/" <> int.to_string(project_id) <> "/workflows",
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

fn create_rule(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  workflow_id: Int,
  type_id: Int,
  template_id: Int,
  name: String,
) -> Nil {
  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/workflows/" <> int.to_string(workflow_id) <> "/rules",
      )
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf)
      |> request.set_header("X-CSRF", csrf)
      |> simulate.json_body(
        json.object([
          #("name", json.string(name)),
          #("goal", json.string("Create QA work")),
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
}

fn insert_rule_without_template(
  db: pog.Connection,
  workflow_id: Int,
  type_id: Int,
) -> Int {
  single_int(
    db,
    "insert into rules (workflow_id, name, goal, resource_type, trigger_kind, task_type_id, to_state, active)
     values ($1, 'Historical rule', 'Historical execution only', 'task', 'task_closed', $2, 'closed', false)
     returning id",
    [pog.int(workflow_id), pog.int(type_id)],
  )
}

fn insert_origin_task(db: pog.Connection, project_id: Int, type_id: Int) -> Int {
  single_int(
    db,
    "insert into tasks (title, description, priority, type_id, project_id, created_by, execution_state)
     values ('Origin task', '', 3, $1, $2, 1, 'closed')
     returning id",
    [pog.int(type_id), pog.int(project_id)],
  )
}

fn insert_template_execution(
  db: pog.Connection,
  rule_id: Int,
  template_id: Int,
  task_id: Int,
) {
  let assert Ok(_) =
    pog.query(
      "insert into rule_executions (rule_id, event_key, task_id, outcome, user_id, template_id, template_version)
       values ($1, 'template-archive-history', $2, 'applied', 1, $3, 1)",
    )
    |> pog.parameter(pog.int(rule_id))
    |> pog.parameter(pog.int(task_id))
    |> pog.parameter(pog.int(template_id))
    |> pog.execute(db)

  Nil
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
      "/api/v1/projects/" <> int.to_string(project_id) <> "/task-types",
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
      "/api/v1/projects/" <> int.to_string(project_id) <> "/members",
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

fn get_default_project_id(db: pog.Connection) -> Int {
  single_int(db, "select id from projects where org_id = 1 limit 1", [])
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
