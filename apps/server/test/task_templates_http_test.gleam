import fixtures
import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/string
import pog
import support/assertions as expect
import wisp
import wisp/simulate

// Justification: large function kept intact to preserve cohesive logic.
pub fn task_templates_project_crud_test() {
  let #(db, handler, session, project_id, type_id) =
    fixtures.require_project_with_task_type("Core", "QA", "bug-ant")

  let create_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/task-templates",
      )
      |> fixtures.with_auth(session)
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
    fixtures.require_query_int(
      db,
      "select version from task_templates where id = $1",
      [pog.int(template_id)],
    )
  created_version |> expect.equal(1)

  let list_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/task-templates",
      )
      |> fixtures.with_auth(session),
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
      |> fixtures.with_auth(session)
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
    fixtures.require_query_int(
      db,
      "select version from task_templates where id = $1",
      [pog.int(template_id)],
    )
  updated_version |> expect.equal(2)

  let delete_res =
    handler(
      simulate.request(
        http.Delete,
        "/api/v1/task-templates/" <> int.to_string(template_id),
      )
      |> fixtures.with_auth(session),
    )

  expect.expect_status(delete_res, 204)

  let list_after_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/task-templates",
      )
      |> fixtures.with_auth(session),
    )

  expect.expect_status(list_after_res, 200)
  decode_template_names(simulate.read_body(list_after_res))
  |> expect.equal([])
}

pub fn task_template_used_by_rule_cannot_be_deleted_test() {
  let #(_db, handler, session, project_id, type_id) =
    fixtures.require_project_with_task_type("Core", "QA", "bug-ant")

  let template_id =
    fixtures.create_template(
      handler,
      session,
      project_id,
      type_id,
      "Protected Template",
    )
    |> expect.ok
  let workflow_id =
    fixtures.create_workflow(handler, session, project_id, "Release flow")
    |> expect.ok

  create_rule(
    handler,
    session,
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
      |> fixtures.with_auth(session),
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
      |> fixtures.with_auth(session),
    )

  expect.expect_status(list_res, 200)
  decode_template_names(simulate.read_body(list_res))
  |> expect.equal(["Protected Template"])
}

pub fn task_template_with_only_execution_history_archives_on_delete_test() {
  let #(db, handler, session, project_id, type_id) =
    fixtures.require_project_with_task_type("TemplateHistory", "QA", "bug-ant")

  let workflow_id =
    fixtures.create_workflow(handler, session, project_id, "History Engine")
    |> expect.ok
  let template_id =
    fixtures.create_template(
      handler,
      session,
      project_id,
      type_id,
      "Historical Template",
    )
    |> expect.ok
  let rule_id = insert_rule_without_template(db, workflow_id, type_id)
  let task_id = insert_origin_task(db, project_id, type_id)
  insert_template_execution(db, rule_id, template_id, task_id)

  let delete_res =
    handler(
      simulate.request(
        http.Delete,
        "/api/v1/task-templates/" <> int.to_string(template_id),
      )
      |> fixtures.with_auth(session),
    )

  expect.expect_status(delete_res, 204)
  fixtures.require_query_int(
    db,
    "select count(*)::int from task_templates where id = $1 and archived_at is not null",
    [pog.int(template_id)],
  )
  |> expect.equal(1)
  fixtures.require_query_int(
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
      |> fixtures.with_auth(session),
    )

  expect.expect_status(list_res, 200)
  decode_template_names(simulate.read_body(list_res))
  |> expect.equal([])
}

pub fn task_templates_project_scope_requires_project_manager_test() {
  let #(db, handler, admin_session, project_id, type_id) =
    fixtures.require_project_with_task_type("Core", "QA", "bug-ant")

  let member_id =
    fixtures.create_member_user(handler, db, "member@example.com", "inv_member")
    |> expect.ok

  fixtures.add_member(handler, admin_session, project_id, member_id, "member")
  |> expect.ok

  let member_session =
    fixtures.login(handler, "member@example.com", "passwordpassword")
    |> expect.ok

  let create_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/task-templates",
      )
      |> fixtures.with_auth(member_session)
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
      |> fixtures.with_auth(member_session),
    )

  expect.expect_status(list_res, 403)
}

pub fn task_templates_project_list_filters_scope_test() {
  let #(db, handler, session, core_project_id, core_type_id) =
    fixtures.require_project_with_task_type("Core", "QA", "bug-ant")
  let default_project_id = fixtures.default_project_id(db) |> expect.ok

  // Create task type in each project
  let default_type_id =
    fixtures.create_task_type(
      handler,
      session,
      default_project_id,
      "Bug",
      "bug-ant",
    )
    |> expect.ok
  // Create template in default project
  fixtures.create_template_full(
    handler,
    session,
    default_project_id,
    default_type_id,
    "Default Template",
    "Default desc",
    4,
  )
  |> expect.ok

  // Create template in Core project
  fixtures.create_template_full(
    handler,
    session,
    core_project_id,
    core_type_id,
    "Core Template",
    "Core desc",
    3,
  )
  |> expect.ok

  // List Core project templates - should only show Core Template
  let list_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/projects/"
          <> int.to_string(core_project_id)
          <> "/task-templates",
      )
      |> fixtures.with_auth(session),
    )

  expect.expect_status(list_res, 200)
  decode_template_names(simulate.read_body(list_res))
  |> expect.equal(["Core Template"])
}

pub fn task_templates_invalid_type_id_returns_422_test() {
  let #(db, handler, session) = fixtures.require_org_context()
  let project_id = fixtures.default_project_id(db) |> expect.ok

  let create_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/task-templates",
      )
      |> fixtures.with_auth(session)
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
  fixtures.require_entity_id(body, fixtures.Template)
}

fn decode_template_name(body: String) -> String {
  let template_decoder = {
    use name <- decode.field("name", decode.string)
    decode.success(name)
  }
  fixtures.require_data(
    body,
    decode.field("template", template_decoder, decode.success),
  )
}

fn decode_template_names(body: String) -> List(String) {
  fixtures.require_data_string_list_field(body, "templates", "name")
}

fn create_rule(
  handler: fn(wisp.Request) -> wisp.Response,
  session: fixtures.Session,
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
      |> fixtures.with_auth(session)
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
  fixtures.require_query_int(
    db,
    "insert into rules (workflow_id, name, goal, resource_type, trigger_kind, task_type_id, to_state, active)
     values ($1, 'Historical rule', 'Historical execution only', 'task', 'task_closed', $2, 'closed', false)
     returning id",
    [pog.int(workflow_id), pog.int(type_id)],
  )
}

fn insert_origin_task(db: pog.Connection, project_id: Int, type_id: Int) -> Int {
  fixtures.require_query_int(
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
