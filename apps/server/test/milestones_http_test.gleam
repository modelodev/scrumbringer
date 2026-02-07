import fixtures
import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/option
import gleam/result
import gleeunit
import gleeunit/should
import pog
import scrumbringer_server
import wisp/simulate

pub fn main() {
  gleeunit.main()
}

pub fn milestones_crud_patch_delete_ready_empty_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(..) = app

  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(milestone_id) =
    create_milestone(handler, session, project_id, "Release 1", "Initial")

  let patch_res =
    handler(
      simulate.request(
        http.Patch,
        "/api/v1/milestones/" <> int.to_string(milestone_id),
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(
        json.object([
          #("name", json.string("Release 1.1")),
          #("description", json.string("Updated")),
        ]),
      ),
    )

  patch_res.status |> should.equal(200)

  let get_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/milestones/" <> int.to_string(milestone_id),
      )
      |> fixtures.with_auth(session),
    )

  get_res.status |> should.equal(200)
  let assert Ok(#(name, description)) =
    decode_milestone_name_desc(simulate.read_body(get_res))
  name |> should.equal("Release 1.1")
  description |> should.equal("Updated")

  let delete_res =
    handler(
      simulate.request(
        http.Delete,
        "/api/v1/milestones/" <> int.to_string(milestone_id),
      )
      |> fixtures.with_auth(session),
    )

  delete_res.status |> should.equal(204)

  let get_after_delete =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/milestones/" <> int.to_string(milestone_id),
      )
      |> fixtures.with_auth(session),
    )

  get_after_delete.status |> should.equal(404)
}

pub fn milestones_delete_conflict_when_not_empty_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(..) = app

  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(milestone_id) =
    create_milestone(handler, session, project_id, "Release 1", "Initial")

  let card_create_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/cards",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(
        json.object([
          #("title", json.string("Card 1")),
          #("description", json.string("")),
          #("color", json.string("blue")),
          #("milestone_id", json.int(milestone_id)),
        ]),
      ),
    )

  card_create_res.status |> should.equal(200)

  let delete_res =
    handler(
      simulate.request(
        http.Delete,
        "/api/v1/milestones/" <> int.to_string(milestone_id),
      )
      |> fixtures.with_auth(session),
    )

  delete_res.status |> should.equal(409)
  let assert Ok(code) = decode_error_code(simulate.read_body(delete_res))
  code |> should.equal("MILESTONE_DELETE_NOT_ALLOWED")
}

pub fn milestones_patch_requires_project_admin_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(milestone_id) =
    create_milestone(handler, session, project_id, "Release 1", "Initial")

  let assert Ok(member_id) =
    fixtures.create_member_user(handler, db, "member@example.com", "inv_member")
  let assert Ok(_) =
    fixtures.add_member(handler, session, project_id, member_id, "member")
  let assert Ok(member_session) =
    fixtures.login(handler, "member@example.com", "passwordpassword")

  let patch_res =
    handler(
      simulate.request(
        http.Patch,
        "/api/v1/milestones/" <> int.to_string(milestone_id),
      )
      |> fixtures.with_auth(member_session)
      |> simulate.json_body(json.object([#("name", json.string("Nope"))])),
    )

  patch_res.status |> should.equal(403)
}

pub fn create_task_with_card_and_milestone_is_rejected_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(milestone_id) =
    create_milestone(handler, session, project_id, "Release 1", "Initial")

  let card_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/cards",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(
        json.object([
          #("title", json.string("Card 1")),
          #("description", json.string("")),
          #("color", json.string("blue")),
          #("milestone_id", json.int(milestone_id)),
        ]),
      ),
    )
  card_res.status |> should.equal(200)
  let card_id =
    fixtures.query_int(
      db,
      "select id from cards where project_id = $1 order by id desc limit 1",
      [pog.int(project_id)],
    )
    |> result.unwrap(0)

  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")

  let task_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/tasks",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(
        json.object([
          #("title", json.string("Task linked")),
          #("description", json.string("")),
          #("priority", json.int(3)),
          #("type_id", json.int(type_id)),
          #("card_id", json.int(card_id)),
          #("milestone_id", json.int(milestone_id)),
        ]),
      ),
    )

  task_res.status |> should.equal(422)
  let assert Ok(code) = decode_error_code(simulate.read_body(task_res))
  code |> should.equal("TASK_MILESTONE_INHERITED_FROM_CARD")
}

pub fn card_move_from_pool_to_milestone_is_rejected_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(milestone_id) =
    create_milestone(handler, session, project_id, "Release 1", "Initial")

  let card_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/cards",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(
        json.object([
          #("title", json.string("Pool Card")),
          #("description", json.string("")),
          #("color", json.string("blue")),
        ]),
      ),
    )
  card_res.status |> should.equal(200)

  let card_id =
    fixtures.query_int(
      db,
      "select id from cards where project_id = $1 and title = 'Pool Card'",
      [pog.int(project_id)],
    )
    |> result.unwrap(0)

  let patch_res =
    handler(
      simulate.request(http.Patch, "/api/v1/cards/" <> int.to_string(card_id))
      |> fixtures.with_auth(session)
      |> simulate.json_body(
        json.object([
          #("title", json.string("Pool Card")),
          #("description", json.string("")),
          #("color", json.string("blue")),
          #("milestone_id", json.int(milestone_id)),
        ]),
      ),
    )

  patch_res.status |> should.equal(422)
  let assert Ok(code) = decode_error_code(simulate.read_body(patch_res))
  code |> should.equal("INVALID_MOVE_POOL_TO_MILESTONE")
}

pub fn task_patch_with_card_and_milestone_is_rejected_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(milestone_id) =
    create_milestone(handler, session, project_id, "Release 1", "Initial")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(card_id) =
    fixtures.create_card(handler, session, project_id, "Card 1")
  let assert Ok(task_id) =
    fixtures.create_task_with_card(
      handler,
      session,
      project_id,
      type_id,
      card_id,
      "Task linked",
    )

  let claim_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "/claim",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(
        json.object([#("version", json.int(task_version(db, task_id)))]),
      ),
    )
  claim_res.status |> should.equal(200)

  let patch_res =
    handler(
      simulate.request(http.Patch, "/api/v1/tasks/" <> int.to_string(task_id))
      |> fixtures.with_auth(session)
      |> simulate.json_body(
        json.object([
          #("version", json.int(task_version(db, task_id))),
          #("milestone_id", json.int(milestone_id)),
        ]),
      ),
    )

  patch_res.status |> should.equal(422)
  let assert Ok(code) = decode_error_code(simulate.read_body(patch_res))
  code |> should.equal("TASK_MILESTONE_INHERITED_FROM_CARD")
}

pub fn task_move_from_pool_to_milestone_is_rejected_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(milestone_id) =
    create_milestone(handler, session, project_id, "Release 1", "Initial")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Standalone")

  let claim_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "/claim",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(
        json.object([#("version", json.int(task_version(db, task_id)))]),
      ),
    )
  claim_res.status |> should.equal(200)

  let patch_res =
    handler(
      simulate.request(http.Patch, "/api/v1/tasks/" <> int.to_string(task_id))
      |> fixtures.with_auth(session)
      |> simulate.json_body(
        json.object([
          #("version", json.int(task_version(db, task_id))),
          #("milestone_id", json.int(milestone_id)),
        ]),
      ),
    )

  patch_res.status |> should.equal(422)
  let assert Ok(code) = decode_error_code(simulate.read_body(patch_res))
  code |> should.equal("INVALID_MOVE_POOL_TO_MILESTONE")
}

pub fn task_move_ready_to_ready_and_ready_to_pool_is_allowed_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(milestone_1) =
    create_milestone(handler, session, project_id, "Release 1", "Initial")
  let assert Ok(milestone_2) =
    create_milestone(handler, session, project_id, "Release 2", "Next")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(task_id) =
    create_task_with_milestone(
      handler,
      session,
      project_id,
      type_id,
      milestone_1,
      "Standalone",
    )

  let claim_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "/claim",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(
        json.object([#("version", json.int(task_version(db, task_id)))]),
      ),
    )
  claim_res.status |> should.equal(200)

  let move_ready_to_ready =
    handler(
      simulate.request(http.Patch, "/api/v1/tasks/" <> int.to_string(task_id))
      |> fixtures.with_auth(session)
      |> simulate.json_body(
        json.object([
          #("version", json.int(task_version(db, task_id))),
          #("milestone_id", json.int(milestone_2)),
        ]),
      ),
    )
  move_ready_to_ready.status |> should.equal(200)
  let assert Ok(db_milestone_after_move) =
    fixtures.query_int(db, "select milestone_id from tasks where id = $1", [
      pog.int(task_id),
    ])
  db_milestone_after_move |> should.equal(milestone_2)

  let move_ready_to_pool =
    handler(
      simulate.request(http.Patch, "/api/v1/tasks/" <> int.to_string(task_id))
      |> fixtures.with_auth(session)
      |> simulate.json_body(
        json.object([
          #("version", json.int(task_version(db, task_id))),
          #("milestone_id", json.null()),
        ]),
      ),
    )
  move_ready_to_pool.status |> should.equal(200)
  let assert Ok(db_milestone_after_pool) =
    fixtures.query_nullable_int(
      db,
      "select milestone_id from tasks where id = $1",
      [
        pog.int(task_id),
      ],
    )
  db_milestone_after_pool |> should.equal(option.None)
}

pub fn task_pool_lifetime_tracking_fields_are_wired_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(task_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Standalone")

  let assert Ok(initial_pool_lifetime_s) =
    fixtures.query_int(db, "select pool_lifetime_s from tasks where id = $1", [
      pog.int(task_id),
    ])
  initial_pool_lifetime_s |> should.equal(0)

  let claim_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "/claim",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(
        json.object([#("version", json.int(task_version(db, task_id)))]),
      ),
    )
  claim_res.status |> should.equal(200)

  let assert Ok(non_negative_after_claim) =
    fixtures.query_int(
      db,
      "select case when pool_lifetime_s >= 0 then 1 else 0 end from tasks where id = $1",
      [pog.int(task_id)],
    )
  non_negative_after_claim |> should.equal(1)

  let release_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "/release",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(
        json.object([#("version", json.int(task_version(db, task_id)))]),
      ),
    )
  release_res.status |> should.equal(200)

  let assert Ok(release_last_entered_present) =
    fixtures.query_int(
      db,
      "select case when last_entered_pool_at is null then 0 else 1 end from tasks where id = $1",
      [pog.int(task_id)],
    )
  release_last_entered_present |> should.equal(1)
}

pub fn milestone_activation_returns_snapshot_and_blocks_second_active_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(..) = app

  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(milestone_1) =
    create_milestone(handler, session, project_id, "Release 1", "Initial")
  let assert Ok(milestone_2) =
    create_milestone(handler, session, project_id, "Release 2", "Next")

  let activate_1 =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/milestones/" <> int.to_string(milestone_1) <> "/activate",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([])),
    )

  activate_1.status |> should.equal(200)
  let assert Ok(#(cards_released, tasks_released, activated_at_present)) =
    decode_activation_snapshot(simulate.read_body(activate_1))
  cards_released |> should.equal(0)
  tasks_released |> should.equal(0)
  activated_at_present |> should.equal(True)

  let activate_2 =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/milestones/" <> int.to_string(milestone_2) <> "/activate",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([])),
    )

  activate_2.status |> should.equal(409)
  let assert Ok(code) = decode_error_code(simulate.read_body(activate_2))
  code |> should.equal("MILESTONE_ALREADY_ACTIVE")
}

pub fn milestone_completes_when_all_items_complete_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(milestone_id) =
    create_milestone(handler, session, project_id, "Release 1", "Initial")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")
  let assert Ok(task_id) =
    create_task_with_milestone(
      handler,
      session,
      project_id,
      type_id,
      milestone_id,
      "Standalone",
    )

  let activate =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/milestones/" <> int.to_string(milestone_id) <> "/activate",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([])),
    )
  activate.status |> should.equal(200)

  let claim =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "/claim",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(
        json.object([#("version", json.int(task_version(db, task_id)))]),
      ),
    )
  claim.status |> should.equal(200)

  let complete =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "/complete",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(
        json.object([#("version", json.int(task_version(db, task_id)))]),
      ),
    )
  complete.status |> should.equal(200)

  let assert Ok(state_after_complete) =
    fixtures.query_string(db, "select state from milestones where id = $1", [
      pog.int(milestone_id),
    ])
  state_after_complete |> should.equal("completed")

  let assert Ok(completed_at_present) =
    fixtures.query_int(
      db,
      "select case when completed_at is null then 0 else 1 end from milestones where id = $1",
      [pog.int(milestone_id)],
    )
  completed_at_present |> should.equal(1)
}

fn create_milestone(
  handler: fixtures.Handler,
  session: fixtures.Session,
  project_id: Int,
  name: String,
  description: String,
) -> Result(Int, String) {
  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/milestones",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(
        json.object([
          #("name", json.string(name)),
          #("description", json.string(description)),
        ]),
      ),
    )

  case res.status {
    200 -> decode_milestone_id(simulate.read_body(res))
    status ->
      Error(
        "create_milestone failed: status="
        <> int.to_string(status)
        <> " body="
        <> simulate.read_body(res),
      )
  }
}

fn decode_milestone_id(body: String) -> Result(Int, String) {
  let decoder = {
    use id <- decode.field("id", decode.int)
    decode.success(id)
  }
  let response_decoder = {
    use milestone <- decode.field("milestone", decoder)
    decode.success(milestone)
  }

  case json.parse(body, decode.dynamic) {
    Error(_) -> Error("invalid json")
    Ok(dynamic) ->
      case
        decode.run(
          dynamic,
          decode.field("data", response_decoder, decode.success),
        )
      {
        Ok(id) -> Ok(id)
        Error(_) -> Error("decode milestone id failed")
      }
  }
}

fn decode_milestone_name_desc(body: String) -> Result(#(String, String), String) {
  let decoder = {
    use name <- decode.field("name", decode.string)
    use description <- decode.field("description", decode.string)
    decode.success(#(name, description))
  }
  let response_decoder = {
    use milestone <- decode.field("milestone", decoder)
    decode.success(milestone)
  }

  case json.parse(body, decode.dynamic) {
    Error(_) -> Error("invalid json")
    Ok(dynamic) ->
      case
        decode.run(
          dynamic,
          decode.field("data", response_decoder, decode.success),
        )
      {
        Ok(value) -> Ok(value)
        Error(_) -> Error("decode milestone failed")
      }
  }
}

fn decode_error_code(body: String) -> Result(String, String) {
  let decoder = {
    use code <- decode.field("code", decode.string)
    decode.success(code)
  }

  case json.parse(body, decode.dynamic) {
    Error(_) -> Error("invalid json")
    Ok(dynamic) ->
      case decode.run(dynamic, decode.field("error", decoder, decode.success)) {
        Ok(code) -> Ok(code)
        Error(_) -> Error("decode error code failed")
      }
  }
}

fn decode_activation_snapshot(body: String) -> Result(#(Int, Int, Bool), String) {
  let decoder = {
    use cards <- decode.field("cards_released", decode.int)
    use tasks <- decode.field("tasks_released", decode.int)
    use activated_at <- decode.field(
      "activated_at",
      decode.optional(decode.string),
    )
    decode.success(#(cards, tasks, option.is_some(activated_at)))
  }

  case json.parse(body, decode.dynamic) {
    Error(_) -> Error("invalid json")
    Ok(dynamic) ->
      case decode.run(dynamic, decode.field("data", decoder, decode.success)) {
        Ok(payload) -> Ok(payload)
        Error(_) -> Error("decode activation snapshot failed")
      }
  }
}

fn task_version(db: pog.Connection, task_id: Int) -> Int {
  fixtures.query_int(db, "select version from tasks where id = $1", [
    pog.int(task_id),
  ])
  |> result.unwrap(0)
}

fn create_task_with_milestone(
  handler: fixtures.Handler,
  session: fixtures.Session,
  project_id: Int,
  type_id: Int,
  milestone_id: Int,
  title: String,
) -> Result(Int, String) {
  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/tasks",
      )
      |> fixtures.with_auth(session)
      |> simulate.json_body(
        json.object([
          #("title", json.string(title)),
          #("description", json.string("")),
          #("priority", json.int(3)),
          #("type_id", json.int(type_id)),
          #("milestone_id", json.int(milestone_id)),
        ]),
      ),
    )

  case res.status {
    200 ->
      fixtures.decode_entity_id(simulate.read_body(res), fixtures.TaskEntity)
    status ->
      Error(
        "create_task_with_milestone failed: status="
        <> int.to_string(status)
        <> " body="
        <> simulate.read_body(res),
      )
  }
}
