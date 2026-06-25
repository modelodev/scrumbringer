import fixtures
import gleam/http
import gleam/int
import gleam/json
import gleam/option.{Some}
import pog
import scrumbringer_server
import support/assertions as expect
import wisp/simulate

pub fn automation_config_mutations_record_actor_entity_and_change_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(actor_user_id) = fixtures.get_user_id(db, "admin@example.com")
  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "Automation Audit")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "QA", "bug-ant")

  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Audit Engine")
  let assert Ok(template_id) =
    fixtures.create_template(
      handler,
      session,
      project_id,
      type_id,
      "Audit Template",
    )
  let assert Ok(rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      Some(type_id),
      "Audit Rule",
      fixtures.task_done(),
      template_id,
    )

  let pause_workflow_res =
    handler(
      simulate.request(
        http.Patch,
        "/api/v1/workflows/" <> int.to_string(workflow_id),
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("active", json.int(0))])),
    )
  expect.expect_status(pause_workflow_res, 200)

  let pause_rule_res =
    handler(
      simulate.request(http.Patch, "/api/v1/rules/" <> int.to_string(rule_id))
      |> fixtures.with_auth(session)
      |> simulate.json_body(
        json.object([
          #("status", json.object([#("type", json.string("paused"))])),
        ]),
      ),
    )
  expect.expect_status(pause_rule_res, 200)

  let update_template_res =
    handler(
      simulate.request(
        http.Patch,
        "/api/v1/task-templates/" <> int.to_string(template_id),
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(
        json.object([#("name", json.string("Audit Template Updated"))]),
      ),
    )
  expect.expect_status(update_template_res, 200)

  let delete_rule_res =
    handler(
      simulate.request(http.Delete, "/api/v1/rules/" <> int.to_string(rule_id))
      |> fixtures.with_auth(session),
    )
  expect.expect_status(delete_rule_res, 204)

  let delete_template_res =
    handler(
      simulate.request(
        http.Delete,
        "/api/v1/task-templates/" <> int.to_string(template_id),
      )
      |> fixtures.with_auth(session),
    )
  expect.expect_status(delete_template_res, 204)

  let delete_workflow_res =
    handler(
      simulate.request(
        http.Delete,
        "/api/v1/workflows/" <> int.to_string(workflow_id),
      )
      |> fixtures.with_auth(session),
    )
  expect.expect_status(delete_workflow_res, 204)

  assert_audit_event(
    db,
    org_id,
    project_id,
    actor_user_id,
    "engine",
    workflow_id,
    "created",
    "Audit Engine",
  )
  assert_audit_event(
    db,
    org_id,
    project_id,
    actor_user_id,
    "engine",
    workflow_id,
    "paused",
    "",
  )
  assert_audit_event(
    db,
    org_id,
    project_id,
    actor_user_id,
    "engine",
    workflow_id,
    "deleted",
    "Audit Engine",
  )
  assert_audit_event(
    db,
    org_id,
    project_id,
    actor_user_id,
    "template",
    template_id,
    "created",
    "Audit Template",
  )
  assert_audit_event(
    db,
    org_id,
    project_id,
    actor_user_id,
    "template",
    template_id,
    "updated",
    "Audit Template Updated",
  )
  assert_audit_event(
    db,
    org_id,
    project_id,
    actor_user_id,
    "template",
    template_id,
    "deleted",
    "Audit Template Updated",
  )
  assert_audit_event(
    db,
    org_id,
    project_id,
    actor_user_id,
    "rule",
    rule_id,
    "created",
    "Audit Rule",
  )
  assert_audit_event(
    db,
    org_id,
    project_id,
    actor_user_id,
    "rule",
    rule_id,
    "paused",
    "Audit Rule",
  )
  assert_audit_event(
    db,
    org_id,
    project_id,
    actor_user_id,
    "rule",
    rule_id,
    "deleted",
    "Audit Rule",
  )
}

fn assert_audit_event(
  db: pog.Connection,
  org_id: Int,
  project_id: Int,
  actor_user_id: Int,
  entity_type: String,
  entity_id: Int,
  change_type: String,
  payload_name: String,
) {
  let assert Ok(count) =
    fixtures.query_int(
      db,
      "select count(*)::int
       from automation_config_events
       where org_id = $1
         and project_id = $2
         and actor_user_id = $3
         and entity_type = $4
         and entity_id = $5
         and change_type = $6
         and created_at is not null
         and ($7 = '' or payload_json->>'name' = $7)",
      [
        pog.int(org_id),
        pog.int(project_id),
        pog.int(actor_user_id),
        pog.text(entity_type),
        pog.int(entity_id),
        pog.text(change_type),
        pog.text(payload_name),
      ],
    )
  count |> expect.equal(1)
}
