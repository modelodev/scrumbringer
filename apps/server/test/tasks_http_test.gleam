import fixtures
import gleam/dynamic/decode
import gleam/http
import gleam/json
import gleam/list
import gleam/option
import gleam/string
import pog
import scrumbringer_server
import support/assertions as expect
import wisp
import wisp/simulate

fn fixture_session(token: String, csrf: String) -> fixtures.Session {
  fixtures.Session(token: token, csrf: csrf)
}

fn login_session(
  handler: fn(wisp.Request) -> wisp.Response,
  email: String,
) -> #(String, String) {
  let session = fixtures.login(handler, email, "passwordpassword") |> expect.ok
  #(session.token, session.csrf)
}

pub fn task_types_list_sorted_by_name_test() {
  let app = bootstrap_app()
  let handler = scrumbringer_server.handler(app)

  let #(session, csrf) = login_session(handler, "admin@example.com")
  let project_id = create_project(handler, session, csrf, "Core")

  create_task_type(handler, session, csrf, project_id, "Zulu", "bug-ant", 0)
  create_task_type(handler, session, csrf, project_id, "Alpha", "bolt", 0)

  let req =
    simulate.request(
      http.Get,
      "/api/v1/projects/" <> int_to_string(project_id) <> "/task-types",
    )
    |> fixtures.with_session_cookies(session, csrf)

  let res = handler(req)
  expect.expect_status(res, 200)

  let body = simulate.read_body(res)
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let task_type_decoder = {
    use name <- decode.field("name", decode.string)
    decode.success(name)
  }

  let data_decoder = {
    use task_types <- decode.field("task_types", decode.list(task_type_decoder))
    decode.success(task_types)
  }

  let response_decoder = {
    use task_types <- decode.field("data", data_decoder)
    decode.success(task_types)
  }

  let assert Ok(task_types) = decode.run(dynamic, response_decoder)
  task_types |> expect.equal(["Alpha", "General", "Zulu"])
}

pub fn task_types_create_requires_project_admin_and_csrf_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let #(admin_session, admin_csrf) = login_session(handler, "admin@example.com")
  let project_id = create_project(handler, admin_session, admin_csrf, "Core")

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

  let #(member_session, member_csrf) =
    login_session(handler, "member@example.com")

  let member_req =
    simulate.request(
      http.Post,
      "/api/v1/projects/" <> int_to_string(project_id) <> "/task-types",
    )
    |> fixtures.with_auth(fixture_session(member_session, member_csrf))
    |> simulate.json_body(
      json.object([
        #("name", json.string("Bug")),
        #("icon", json.string("bug-ant")),
      ]),
    )

  let member_res = handler(member_req)
  expect.expect_status(member_res, 403)

  let no_csrf_req =
    simulate.request(
      http.Post,
      "/api/v1/projects/" <> int_to_string(project_id) <> "/task-types",
    )
    |> fixtures.with_session_cookies(admin_session, admin_csrf)
    |> simulate.json_body(
      json.object([
        #("name", json.string("Bug")),
        #("icon", json.string("bug-ant")),
      ]),
    )

  let no_csrf_res = handler(no_csrf_req)
  expect.expect_status(no_csrf_res, 403)
}

// Justification: large function kept intact to preserve cohesive logic.
pub fn tasks_list_filters_sorting_and_q_search_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let #(session, csrf) = login_session(handler, "admin@example.com")
  let project_id = create_project(handler, session, csrf, "Core")

  let cap1 = insert_capability(db, project_id, "Frontend")
  let cap2 = insert_capability(db, project_id, "Backend")

  let needle_type_id =
    create_task_type(
      handler,
      session,
      csrf,
      project_id,
      "NeedleType",
      "bug-ant",
      cap1,
    )
  let other_type_id =
    create_task_type(
      handler,
      session,
      csrf,
      project_id,
      "OtherType",
      "bolt",
      cap2,
    )

  let t1_id =
    create_task(handler, session, csrf, project_id, "Old", "", 3, other_type_id)
  let t2_id =
    create_task(
      handler,
      session,
      csrf,
      project_id,
      "needle in title",
      "",
      3,
      other_type_id,
    )
  let t3_id =
    create_task(
      handler,
      session,
      csrf,
      project_id,
      "Unrelated",
      "",
      3,
      needle_type_id,
    )

  set_task_created_at(db, t1_id, "2000-01-01T00:00:00Z")
  set_task_created_at(db, t2_id, "2000-01-03T00:00:00Z")
  set_task_created_at(db, t3_id, "2000-01-02T00:00:00Z")

  let list_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/projects/" <> int_to_string(project_id) <> "/tasks",
      )
      |> fixtures.with_session_cookies(session, csrf),
    )

  expect.expect_status(list_res, 200)
  let list_titles = decode_task_titles(simulate.read_body(list_res))
  list_titles |> expect.equal(["needle in title", "Unrelated", "Old"])

  let q_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/projects/" <> int_to_string(project_id) <> "/tasks?q=needle",
      )
      |> fixtures.with_session_cookies(session, csrf),
    )

  expect.expect_status(q_res, 200)
  let q_titles = decode_task_titles(simulate.read_body(q_res))
  q_titles |> expect.equal(["needle in title"])

  let cap_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/projects/"
          <> int_to_string(project_id)
          <> "/tasks?capability_id="
          <> int_to_string(cap1),
      )
      |> fixtures.with_session_cookies(session, csrf),
    )

  expect.expect_status(cap_res, 200)
  let cap_titles = decode_task_titles(simulate.read_body(cap_res))
  cap_titles |> expect.equal(["Unrelated"])

  let multi_cap_req =
    simulate.request(
      http.Get,
      "/api/v1/projects/"
        <> int_to_string(project_id)
        <> "/tasks?capability_id=1,2",
    )
    |> fixtures.with_session_cookies(session, csrf)

  let multi_cap_res = handler(multi_cap_req)
  expect.expect_status(multi_cap_res, 422)
  string.contains(simulate.read_body(multi_cap_res), "VALIDATION_ERROR")
  |> expect.is_true
}

pub fn tasks_list_includes_task_contract_fields_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: _db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let #(session, csrf) = login_session(handler, "admin@example.com")
  let project_id = create_project(handler, session, csrf, "Core")
  let type_id =
    create_task_type(handler, session, csrf, project_id, "Bug", "bug-ant", 0)

  create_task(handler, session, csrf, project_id, "Core", "", 3, type_id)

  let req =
    simulate.request(
      http.Get,
      "/api/v1/projects/" <> int_to_string(project_id) <> "/tasks",
    )
    |> fixtures.with_session_cookies(session, csrf)

  let res = handler(req)
  expect.expect_status(res, 200)

  let body = simulate.read_body(res)
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let task_type_decoder = {
    use id <- decode.field("id", decode.int)
    use name <- decode.field("name", decode.string)
    use icon <- decode.field("icon", decode.string)
    decode.success(#(id, name, icon))
  }

  let ongoing_by_decoder =
    decode.optional({
      use user_id <- decode.field("user_id", decode.int)
      decode.success(user_id)
    })

  let task_decoder = {
    use status <- decode.field("status", decode.string)
    use work_state <- decode.field("work_state", decode.string)
    use task_type <- decode.field("task_type", task_type_decoder)
    use ongoing_by <- decode.field("ongoing_by", ongoing_by_decoder)
    decode.success(#(status, work_state, task_type, ongoing_by))
  }

  let data_decoder = {
    use tasks <- decode.field("tasks", decode.list(task_decoder))
    decode.success(tasks)
  }

  let response_decoder = decode.field("data", data_decoder, decode.success)

  let assert Ok(tasks) = decode.run(dynamic, response_decoder)

  case tasks {
    [
      #(
        status,
        work_state,
        #(task_type_id, task_type_name, task_type_icon),
        ongoing_by,
      ),
      ..
    ] -> {
      status |> expect.equal("available")
      work_state |> expect.equal("available")
      task_type_id |> expect.equal(type_id)
      task_type_name |> expect.equal("Bug")
      task_type_icon |> expect.equal("bug-ant")
      ongoing_by |> expect.equal(option.None)
      Nil
    }
    _ -> False |> expect.is_true
  }
}

pub fn task_get_includes_task_contract_fields_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: _db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let #(session, csrf) = login_session(handler, "admin@example.com")
  let project_id = create_project(handler, session, csrf, "Core")
  let type_id =
    create_task_type(handler, session, csrf, project_id, "Bug", "bug-ant", 0)

  let task_id =
    create_task(handler, session, csrf, project_id, "Core", "", 3, type_id)

  let req =
    simulate.request(http.Get, "/api/v1/tasks/" <> int_to_string(task_id))
    |> fixtures.with_session_cookies(session, csrf)

  let res = handler(req)
  expect.expect_status(res, 200)

  let body = simulate.read_body(res)
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let task_type_decoder = {
    use id <- decode.field("id", decode.int)
    use name <- decode.field("name", decode.string)
    use icon <- decode.field("icon", decode.string)
    decode.success(#(id, name, icon))
  }

  let ongoing_by_decoder =
    decode.optional({
      use user_id <- decode.field("user_id", decode.int)
      decode.success(user_id)
    })

  let task_decoder = {
    use work_state <- decode.field("work_state", decode.string)
    use task_type <- decode.field("task_type", task_type_decoder)
    use ongoing_by <- decode.field("ongoing_by", ongoing_by_decoder)
    decode.success(#(work_state, task_type, ongoing_by))
  }

  let data_decoder = {
    use task <- decode.field("task", task_decoder)
    decode.success(task)
  }

  let response_decoder = decode.field("data", data_decoder, decode.success)

  let assert Ok(#(
    work_state,
    #(task_type_id, task_type_name, task_type_icon),
    ongoing_by,
  )) = decode.run(dynamic, response_decoder)

  work_state |> expect.equal("available")
  task_type_id |> expect.equal(type_id)
  task_type_name |> expect.equal("Bug")
  task_type_icon |> expect.equal("bug-ant")
  ongoing_by |> expect.equal(option.None)
}

pub fn task_get_includes_ongoing_by_when_active_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let #(session, csrf) = login_session(handler, "admin@example.com")
  let project_id = create_project(handler, session, csrf, "Core")
  let type_id =
    create_task_type(handler, session, csrf, project_id, "Bug", "bug-ant", 0)

  let task_id =
    create_task(handler, session, csrf, project_id, "Core", "", 3, type_id)

  claim_task(handler, session, csrf, task_id, 1) |> expect.equal(200)
  expect.expect_status(start_work_session(handler, session, csrf, task_id), 200)

  let user_id =
    single_int(db, "select id from users where email = 'admin@example.com'", [])

  let req =
    simulate.request(http.Get, "/api/v1/tasks/" <> int_to_string(task_id))
    |> fixtures.with_session_cookies(session, csrf)

  let res = handler(req)
  expect.expect_status(res, 200)

  let body = simulate.read_body(res)
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let task_type_decoder = {
    use id <- decode.field("id", decode.int)
    use name <- decode.field("name", decode.string)
    use icon <- decode.field("icon", decode.string)
    decode.success(#(id, name, icon))
  }

  let ongoing_by_decoder =
    decode.optional({
      use user_id <- decode.field("user_id", decode.int)
      decode.success(user_id)
    })

  let task_decoder = {
    use status <- decode.field("status", decode.string)
    use work_state <- decode.field("work_state", decode.string)
    use task_type <- decode.field("task_type", task_type_decoder)
    use ongoing_by <- decode.field("ongoing_by", ongoing_by_decoder)
    decode.success(#(status, work_state, task_type, ongoing_by))
  }

  let data_decoder = {
    use task <- decode.field("task", task_decoder)
    decode.success(task)
  }

  let response_decoder = decode.field("data", data_decoder, decode.success)

  let assert Ok(#(
    status,
    work_state,
    #(task_type_id, task_type_name, task_type_icon),
    ongoing_by,
  )) = decode.run(dynamic, response_decoder)

  status |> expect.equal("claimed")
  work_state |> expect.equal("ongoing")
  task_type_id |> expect.equal(type_id)
  task_type_name |> expect.equal("Bug")
  task_type_icon |> expect.equal("bug-ant")
  ongoing_by |> expect.equal(option.Some(user_id))
}

// Justification: large function kept intact to preserve cohesive logic.
// Coverage marker: do_not_emit_audit_event_on_conflict, conflict_does_not_emit_audit.
pub fn claim_conflict_version_conflict_and_state_machine_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let #(admin_session, admin_csrf) = login_session(handler, "admin@example.com")
  let project_id = create_project(handler, admin_session, admin_csrf, "Core")
  let type_id =
    create_task_type(
      handler,
      admin_session,
      admin_csrf,
      project_id,
      "Bug",
      "bug-ant",
      0,
    )

  create_member_user(handler, db, "member@example.com", "inv_member")
  create_member_user(handler, db, "other@example.com", "inv_other")

  let member_id =
    single_int(
      db,
      "select id from users where email = 'member@example.com'",
      [],
    )
  let other_id =
    single_int(db, "select id from users where email = 'other@example.com'", [])

  add_member(
    handler,
    admin_session,
    admin_csrf,
    project_id,
    member_id,
    "member",
  )
  add_member(handler, admin_session, admin_csrf, project_id, other_id, "member")

  let #(member_session, member_csrf) =
    login_session(handler, "member@example.com")

  let #(other_session, other_csrf) = login_session(handler, "other@example.com")

  let task_id =
    create_task(
      handler,
      admin_session,
      admin_csrf,
      project_id,
      "Core",
      "",
      3,
      type_id,
    )

  let claim_req =
    simulate.request(
      http.Post,
      "/api/v1/tasks/" <> int_to_string(task_id) <> "/claim",
    )
    |> fixtures.with_auth(fixture_session(member_session, member_csrf))
    |> simulate.json_body(json.object([#("version", json.int(1))]))

  let claim_res = handler(claim_req)
  expect.expect_status(claim_res, 200)
  count_audit_events_for_task(db, task_id) |> expect.equal(2)

  let claim2_req =
    simulate.request(
      http.Post,
      "/api/v1/tasks/" <> int_to_string(task_id) <> "/claim",
    )
    |> fixtures.with_auth(fixture_session(other_session, other_csrf))
    |> simulate.json_body(json.object([#("version", json.int(1))]))

  let claim2_res = handler(claim2_req)
  expect.expect_status(claim2_res, 409)
  string.contains(simulate.read_body(claim2_res), "CONFLICT_CLAIMED")
  |> expect.is_true
  count_audit_events_for_task(db, task_id) |> expect.equal(2)

  let patch_req =
    simulate.request(http.Patch, "/api/v1/tasks/" <> int_to_string(task_id))
    |> fixtures.with_auth(fixture_session(member_session, member_csrf))
    |> simulate.json_body(
      json.object([
        #("version", json.int(1)),
        #("title", json.string("New")),
        #("claimed_by", json.int(999)),
      ]),
    )

  let patch_res = handler(patch_req)
  expect.expect_status(patch_res, 409)
  string.contains(simulate.read_body(patch_res), "CONFLICT_VERSION")
  |> expect.is_true
  count_audit_events_for_task(db, task_id) |> expect.equal(2)

  let release_bad_req =
    simulate.request(
      http.Post,
      "/api/v1/tasks/" <> int_to_string(task_id) <> "/release",
    )
    |> fixtures.with_auth(fixture_session(member_session, member_csrf))
    |> simulate.json_body(json.object([#("version", json.int(1))]))

  let release_bad_res = handler(release_bad_req)
  expect.expect_status(release_bad_res, 409)
  string.contains(simulate.read_body(release_bad_res), "CONFLICT_VERSION")
  |> expect.is_true
  count_audit_events_for_task(db, task_id) |> expect.equal(2)

  let release_ok_req =
    simulate.request(
      http.Post,
      "/api/v1/tasks/" <> int_to_string(task_id) <> "/release",
    )
    |> fixtures.with_auth(fixture_session(member_session, member_csrf))
    |> simulate.json_body(json.object([#("version", json.int(2))]))

  let release_ok_res = handler(release_ok_req)
  expect.expect_status(release_ok_res, 200)
  count_audit_events_for_task(db, task_id) |> expect.equal(3)

  let close_bad_req =
    simulate.request(
      http.Post,
      "/api/v1/tasks/" <> int_to_string(task_id) <> "/close",
    )
    |> fixtures.with_auth(fixture_session(member_session, member_csrf))
    |> simulate.json_body(json.object([#("version", json.int(3))]))

  let close_bad_res = handler(close_bad_req)
  expect.expect_status(close_bad_res, 422)
  string.contains(simulate.read_body(close_bad_res), "VALIDATION_ERROR")
  |> expect.is_true
  count_audit_events_for_task(db, task_id) |> expect.equal(3)
}

pub fn audit_events_persist_for_lifecycle_actions_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let #(session, csrf) = login_session(handler, "admin@example.com")
  let project_id = create_project(handler, session, csrf, "Core")
  let type_id =
    create_task_type(handler, session, csrf, project_id, "Bug", "bug-ant", 0)

  let admin_id =
    single_int(db, "select id from users where email = 'admin@example.com'", [])

  let task_id =
    create_task(handler, session, csrf, project_id, "Core", "", 3, type_id)

  count_audit_events(db, task_id, "task_created") |> expect.equal(1)
  count_audit_events_for_actor(db, task_id, admin_id, "task_created")
  |> expect.equal(1)

  claim_task(handler, session, csrf, task_id, 1) |> expect.equal(200)
  count_audit_events(db, task_id, "task_claimed") |> expect.equal(1)

  release_task(handler, session, csrf, task_id, 2) |> expect.equal(200)
  count_audit_events(db, task_id, "task_released") |> expect.equal(1)

  claim_task(handler, session, csrf, task_id, 3) |> expect.equal(200)
  close_task(handler, session, csrf, task_id, 4) |> expect.equal(200)
  count_audit_events(db, task_id, "task_closed") |> expect.equal(1)
}

pub fn delete_task_without_operational_history_removes_task_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let #(session, csrf) = login_session(handler, "admin@example.com")
  let project_id = create_project(handler, session, csrf, "Core")
  let type_id =
    create_task_type(handler, session, csrf, project_id, "Bug", "bug-ant", 0)
  let task_id =
    create_task(handler, session, csrf, project_id, "Clean", "", 3, type_id)

  delete_task(handler, session, csrf, task_id) |> expect.equal(204)
  count_task_rows(db, task_id) |> expect.equal(0)
  count_audit_events(db, task_id, "task_created") |> expect.equal(0)
}

pub fn delete_task_with_claim_returns_operational_history_conflict_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let #(session, csrf) = login_session(handler, "admin@example.com")
  let project_id = create_project(handler, session, csrf, "Core")
  let type_id =
    create_task_type(handler, session, csrf, project_id, "Bug", "bug-ant", 0)
  let task_id =
    create_task(handler, session, csrf, project_id, "Claimed", "", 3, type_id)

  claim_task(handler, session, csrf, task_id, 1) |> expect.equal(200)
  let res = delete_task_response(handler, session, csrf, task_id)

  expect.expect_status(res, 409)
  string.contains(simulate.read_body(res), "TASK_HAS_OPERATIONAL_HISTORY")
  |> expect.is_true
  count_task_rows(db, task_id) |> expect.equal(1)
}

pub fn delete_task_with_note_or_dependency_returns_conflict_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let #(session, csrf) = login_session(handler, "admin@example.com")
  let project_id = create_project(handler, session, csrf, "Core")
  let type_id =
    create_task_type(handler, session, csrf, project_id, "Bug", "bug-ant", 0)
  let noted_task =
    create_task(handler, session, csrf, project_id, "Noted", "", 3, type_id)
  let blocked_task =
    create_task(handler, session, csrf, project_id, "Blocked", "", 3, type_id)
  let blocker_task =
    create_task(handler, session, csrf, project_id, "Blocker", "", 3, type_id)

  create_task_note(handler, session, csrf, noted_task, "Operational context")
  |> expect.equal(200)
  create_dependency(handler, session, csrf, blocked_task, blocker_task)
  |> expect.equal(200)

  delete_task(handler, session, csrf, noted_task) |> expect.equal(409)
  delete_task(handler, session, csrf, blocker_task) |> expect.equal(409)
  count_task_rows(db, noted_task) |> expect.equal(1)
  count_task_rows(db, blocker_task) |> expect.equal(1)
}

pub fn task_patch_allows_unclaimed_task_for_project_member_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: _db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let #(session, csrf) = login_session(handler, "admin@example.com")
  let project_id = create_project(handler, session, csrf, "Editable Available")
  let type_id =
    create_task_type(handler, session, csrf, project_id, "Bug", "bug-ant", 0)

  let task_id =
    create_task(handler, session, csrf, project_id, "Editable", "", 3, type_id)

  let patch_req =
    simulate.request(http.Patch, "/api/v1/tasks/" <> int_to_string(task_id))
    |> fixtures.with_auth(fixture_session(session, csrf))
    |> simulate.json_body(
      json.object([
        #("version", json.int(1)),
        #("title", json.string("Editable updated")),
      ]),
    )

  let patch_res = handler(patch_req)
  expect.expect_status(patch_res, 200)
  string.contains(simulate.read_body(patch_res), "Editable updated")
  |> expect.is_true
}

pub fn release_all_tasks_for_member_success_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let #(session, csrf) = login_session(handler, "admin@example.com")
  let project_id = create_project(handler, session, csrf, "Bulk Release")

  create_member_user(handler, db, "member@example.com", "inv_member")
  let member_id =
    single_int(
      db,
      "select id from users where email = 'member@example.com'",
      [],
    )

  add_member(handler, session, csrf, project_id, member_id, "member")
  let type_id =
    create_task_type(handler, session, csrf, project_id, "Bug", "bug-ant", 0)

  let task_a =
    create_task(handler, session, csrf, project_id, "Task A", "", 1, type_id)
  let task_b =
    create_task(handler, session, csrf, project_id, "Task B", "", 1, type_id)

  let #(member_session, member_csrf) =
    login_session(handler, "member@example.com")

  claim_task(
    handler,
    member_session,
    member_csrf,
    task_a,
    task_version(db, task_a),
  )
  |> expect.equal(200)
  claim_task(
    handler,
    member_session,
    member_csrf,
    task_b,
    task_version(db, task_b),
  )
  |> expect.equal(200)

  let list_req =
    simulate.request(
      http.Get,
      "/api/v1/projects/" <> int_to_string(project_id) <> "/members",
    )
    |> fixtures.with_session_cookies(session, csrf)

  let list_res = handler(list_req)
  expect.expect_status(list_res, 200)
  let list_body = simulate.read_body(list_res)
  let assert Ok(list_dynamic) = json.parse(list_body, decode.dynamic)
  let member_decoder = {
    use user_id <- decode.field("user_id", decode.int)
    use claimed_count <- decode.field("claimed_count", decode.int)
    decode.success(#(user_id, claimed_count))
  }
  let members_decoder = {
    use members <- decode.field("members", decode.list(member_decoder))
    decode.success(members)
  }
  let list_response_decoder = {
    use members <- decode.field("data", members_decoder)
    decode.success(members)
  }

  let assert Ok(members_payload) =
    decode.run(list_dynamic, list_response_decoder)
  let member_claimed =
    members_payload
    |> list.filter(fn(row) { row.0 == member_id })
    |> list.map(fn(row) { row.1 })
  member_claimed |> expect.equal([2])

  let req =
    simulate.request(
      http.Post,
      "/api/v1/projects/"
        <> int_to_string(project_id)
        <> "/members/"
        <> int_to_string(member_id)
        <> "/release-all-tasks",
    )
    |> fixtures.with_auth(fixture_session(session, csrf))

  let res = handler(req)
  expect.expect_status(res, 200)

  let body = simulate.read_body(res)
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)
  let payload_decoder = {
    use released_count <- decode.field("released_count", decode.int)
    use task_ids <- decode.field("task_ids", decode.list(decode.int))
    decode.success(#(released_count, task_ids))
  }
  let response_decoder = {
    use payload <- decode.field("data", payload_decoder)
    decode.success(payload)
  }

  let assert Ok(#(released_count, task_ids)) =
    decode.run(dynamic, response_decoder)
  released_count |> expect.equal(2)
  list.length(task_ids) |> expect.equal(2)

  let claimed_left =
    single_int(
      db,
      "select count(*) from tasks where project_id = $1 and claimed_by = $2 and execution_state = 'claimed'",
      [pog.int(project_id), pog.int(member_id)],
    )
  claimed_left |> expect.equal(0)
}

pub fn release_all_tasks_for_member_forbidden_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let #(session, csrf) = login_session(handler, "admin@example.com")
  let project_id =
    create_project(handler, session, csrf, "Bulk Release Forbidden")

  create_member_user(handler, db, "member@example.com", "inv_member")
  let member_id =
    single_int(
      db,
      "select id from users where email = 'member@example.com'",
      [],
    )

  add_member(handler, session, csrf, project_id, member_id, "member")

  let admin_id =
    single_int(db, "select id from users where email = 'admin@example.com'", [])

  let #(member_session, member_csrf) =
    login_session(handler, "member@example.com")

  let req =
    simulate.request(
      http.Post,
      "/api/v1/projects/"
        <> int_to_string(project_id)
        <> "/members/"
        <> int_to_string(admin_id)
        <> "/release-all-tasks",
    )
    |> fixtures.with_auth(fixture_session(member_session, member_csrf))

  let res = handler(req)
  expect.expect_status(res, 403)
  string.contains(simulate.read_body(res), "FORBIDDEN") |> expect.is_true
}

pub fn release_all_tasks_for_member_self_release_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let #(session, csrf) = login_session(handler, "admin@example.com")
  let project_id = create_project(handler, session, csrf, "Bulk Release Self")

  let admin_id =
    single_int(db, "select id from users where email = 'admin@example.com'", [])

  let req =
    simulate.request(
      http.Post,
      "/api/v1/projects/"
        <> int_to_string(project_id)
        <> "/members/"
        <> int_to_string(admin_id)
        <> "/release-all-tasks",
    )
    |> fixtures.with_auth(fixture_session(session, csrf))

  let res = handler(req)
  expect.expect_status(res, 400)
  string.contains(simulate.read_body(res), "SELF_RELEASE") |> expect.is_true
}

pub fn release_all_tasks_for_member_not_found_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: _db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let #(session, csrf) = login_session(handler, "admin@example.com")

  let req =
    simulate.request(
      http.Post,
      "/api/v1/projects/99999/members/99999/release-all-tasks",
    )
    |> fixtures.with_auth(fixture_session(session, csrf))

  let res = handler(req)
  expect.expect_status(res, 404)
  string.contains(simulate.read_body(res), "NOT_FOUND") |> expect.is_true
}

pub fn task_dependencies_reject_circular_dependency_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: _db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let #(session, csrf) = login_session(handler, "admin@example.com")
  let project_id = create_project(handler, session, csrf, "Deps")
  let type_id =
    create_task_type(handler, session, csrf, project_id, "Bug", "bug-ant", 0)

  let task_a =
    create_task(handler, session, csrf, project_id, "Task A", "", 1, type_id)
  let task_b =
    create_task(handler, session, csrf, project_id, "Task B", "", 1, type_id)

  let dep_req =
    simulate.request(
      http.Post,
      "/api/v1/tasks/" <> int_to_string(task_a) <> "/dependencies",
    )
    |> fixtures.with_auth(fixture_session(session, csrf))
    |> simulate.json_body(
      json.object([#("depends_on_task_id", json.int(task_b))]),
    )

  let dep_res = handler(dep_req)
  expect.expect_status(dep_res, 200)

  let circular_req =
    simulate.request(
      http.Post,
      "/api/v1/tasks/" <> int_to_string(task_b) <> "/dependencies",
    )
    |> fixtures.with_auth(fixture_session(session, csrf))
    |> simulate.json_body(
      json.object([#("depends_on_task_id", json.int(task_a))]),
    )

  let circular_res = handler(circular_req)
  expect.expect_status(circular_res, 422)
  simulate.read_body(circular_res)
  |> string.contains("Circular dependency detected")
  |> expect.is_true
}

pub fn task_dependencies_reject_cross_project_dependency_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: _db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let #(session, csrf) = login_session(handler, "admin@example.com")

  let project_one_id = create_project(handler, session, csrf, "Deps One")
  let project_two_id = create_project(handler, session, csrf, "Deps Two")

  let type_one_id =
    create_task_type(
      handler,
      session,
      csrf,
      project_one_id,
      "Bug",
      "bug-ant",
      0,
    )
  let type_two_id =
    create_task_type(
      handler,
      session,
      csrf,
      project_two_id,
      "Bug",
      "bug-ant",
      0,
    )

  let task_one =
    create_task(
      handler,
      session,
      csrf,
      project_one_id,
      "Task One",
      "",
      1,
      type_one_id,
    )
  let task_two =
    create_task(
      handler,
      session,
      csrf,
      project_two_id,
      "Task Two",
      "",
      1,
      type_two_id,
    )

  let cross_req =
    simulate.request(
      http.Post,
      "/api/v1/tasks/" <> int_to_string(task_one) <> "/dependencies",
    )
    |> fixtures.with_auth(fixture_session(session, csrf))
    |> simulate.json_body(
      json.object([#("depends_on_task_id", json.int(task_two))]),
    )

  let cross_res = handler(cross_req)
  expect.expect_status(cross_res, 422)
  simulate.read_body(cross_res)
  |> string.contains("Dependency must be in same project")
  |> expect.is_true
}

pub fn task_dependencies_reject_closed_dependency_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let #(session, csrf) = login_session(handler, "admin@example.com")
  let project_id = create_project(handler, session, csrf, "Deps Closed")
  let type_id =
    create_task_type(handler, session, csrf, project_id, "Bug", "bug-ant", 0)

  let task_blocked =
    create_task(
      handler,
      session,
      csrf,
      project_id,
      "Task Blocked",
      "",
      1,
      type_id,
    )
  let task_closed =
    create_task(
      handler,
      session,
      csrf,
      project_id,
      "Task Closed",
      "",
      1,
      type_id,
    )

  let claim_status =
    claim_task(
      handler,
      session,
      csrf,
      task_closed,
      task_version(db, task_closed),
    )
  claim_status |> expect.equal(200)

  let close_status =
    close_task(
      handler,
      session,
      csrf,
      task_closed,
      task_version(db, task_closed),
    )
  close_status |> expect.equal(200)

  let closed_req =
    simulate.request(
      http.Post,
      "/api/v1/tasks/" <> int_to_string(task_blocked) <> "/dependencies",
    )
    |> fixtures.with_auth(fixture_session(session, csrf))
    |> simulate.json_body(
      json.object([#("depends_on_task_id", json.int(task_closed))]),
    )

  let closed_res = handler(closed_req)
  expect.expect_status(closed_res, 422)
  simulate.read_body(closed_res)
  |> string.contains("Dependency task is already closed")
  |> expect.is_true
}

pub fn blocked_task_claim_returns_conflict_blocked_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let #(session, csrf) = login_session(handler, "admin@example.com")
  let project_id = create_project(handler, session, csrf, "Blocked Claim")
  let type_id =
    create_task_type(handler, session, csrf, project_id, "Bug", "bug-ant", 0)

  let task_blocked =
    create_task(handler, session, csrf, project_id, "Blocked", "", 1, type_id)
  let task_blocker =
    create_task(handler, session, csrf, project_id, "Blocker", "", 1, type_id)

  create_dependency(handler, session, csrf, task_blocked, task_blocker)
  |> expect.equal(200)

  let claim_res =
    claim_task_response(
      handler,
      session,
      csrf,
      task_blocked,
      task_version(db, task_blocked),
    )

  expect.expect_status(claim_res, 409)
  simulate.read_body(claim_res)
  |> string.contains("CONFLICT_BLOCKED")
  |> expect.is_true
  task_claimed_by(db, task_blocked) |> expect.equal(0)
}

pub fn blocked_task_claim_succeeds_after_dependency_closed_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let #(session, csrf) = login_session(handler, "admin@example.com")
  let project_id =
    create_project(handler, session, csrf, "Blocked Claim Closed")
  let type_id =
    create_task_type(handler, session, csrf, project_id, "Bug", "bug-ant", 0)

  let task_blocked =
    create_task(handler, session, csrf, project_id, "Blocked", "", 1, type_id)
  let task_blocker =
    create_task(handler, session, csrf, project_id, "Blocker", "", 1, type_id)

  create_dependency(handler, session, csrf, task_blocked, task_blocker)
  |> expect.equal(200)
  claim_task(
    handler,
    session,
    csrf,
    task_blocker,
    task_version(db, task_blocker),
  )
  |> expect.equal(200)
  close_task(
    handler,
    session,
    csrf,
    task_blocker,
    task_version(db, task_blocker),
  )
  |> expect.equal(200)

  claim_task(
    handler,
    session,
    csrf,
    task_blocked,
    task_version(db, task_blocked),
  )
  |> expect.equal(200)
}

pub fn blocked_task_claim_succeeds_after_dependency_removed_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let #(session, csrf) = login_session(handler, "admin@example.com")
  let project_id =
    create_project(handler, session, csrf, "Blocked Claim Removed")
  let type_id =
    create_task_type(handler, session, csrf, project_id, "Bug", "bug-ant", 0)

  let task_blocked =
    create_task(handler, session, csrf, project_id, "Blocked", "", 1, type_id)
  let task_blocker =
    create_task(handler, session, csrf, project_id, "Blocker", "", 1, type_id)

  create_dependency(handler, session, csrf, task_blocked, task_blocker)
  |> expect.equal(200)
  delete_dependency(handler, session, csrf, task_blocked, task_blocker)
  |> expect.equal(204)

  claim_task(
    handler,
    session,
    csrf,
    task_blocked,
    task_version(db, task_blocked),
  )
  |> expect.equal(200)
}

pub fn task_dependencies_schema_indices_present_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app

  let columns_count =
    single_int(
      db,
      "select count(*) from information_schema.columns where table_name = 'task_dependencies' and column_name in ('task_id', 'depends_on_task_id', 'created_at', 'created_by')",
      [],
    )
  columns_count |> expect.equal(4)

  let index_count =
    single_int(
      db,
      "select count(*) from pg_indexes where tablename = 'task_dependencies' and indexname in ('idx_task_dependencies_task_id', 'idx_task_dependencies_depends_on_task_id')",
      [],
    )
  index_count |> expect.equal(2)
}

pub fn pool_includes_available_active_card_task_test() {
  let #(_, handler, session, csrf, project_id, type_id) =
    ht08_project("HT08 Active Card Pool")

  create_task(
    handler,
    session,
    csrf,
    project_id,
    "Active card task",
    "",
    3,
    type_id,
  )

  let res = list_project_tasks(handler, session, csrf, project_id, "")
  expect.expect_status(res, 200)
  decode_task_titles(simulate.read_body(res))
  |> expect.equal(["Active card task"])
}

pub fn pool_excludes_task_under_draft_card_test() {
  let #(db, handler, session, csrf, project_id, type_id) =
    ht08_project("HT08 Draft Card")
  let draft_card = insert_card_state(db, project_id, "Draft", "draft")

  create_task_with_card(
    handler,
    session,
    csrf,
    project_id,
    "Draft task",
    "",
    3,
    type_id,
    draft_card,
  )

  let res = list_project_tasks(handler, session, csrf, project_id, "")
  expect.expect_status(res, 200)
  decode_task_titles(simulate.read_body(res)) |> expect.equal([])
}

pub fn pool_includes_task_under_active_card_test() {
  let #(db, handler, session, csrf, project_id, type_id) =
    ht08_project("HT08 Active Card")
  let active_card = insert_card_state(db, project_id, "Active", "active")

  create_task_with_card(
    handler,
    session,
    csrf,
    project_id,
    "Active-card task",
    "",
    3,
    type_id,
    active_card,
  )

  let res = list_project_tasks(handler, session, csrf, project_id, "")
  expect.expect_status(res, 200)
  decode_task_titles(simulate.read_body(res))
  |> expect.equal(["Active-card task"])
}

pub fn dependency_blocks_available_and_claimed_tasks_test() {
  let #(db, handler, session, csrf, project_id, type_id) =
    ht08_project("HT08 Blocked")
  let blocked =
    create_task(handler, session, csrf, project_id, "Blocked", "", 3, type_id)
  let blocker =
    create_task(handler, session, csrf, project_id, "Blocker", "", 3, type_id)

  create_dependency(handler, session, csrf, blocked, blocker)
  |> expect.equal(200)

  let blocked_res =
    list_project_tasks(handler, session, csrf, project_id, "blocked=true")
  expect.expect_status(blocked_res, 200)
  decode_task_titles(simulate.read_body(blocked_res))
  |> expect.equal(["Blocked"])

  let claim_blocked =
    claim_task_response(
      handler,
      session,
      csrf,
      blocked,
      task_version(db, blocked),
    )
  expect.expect_status(claim_blocked, 409)
  simulate.read_body(claim_blocked)
  |> string.contains("CONFLICT_BLOCKED")
  |> expect.is_true

  claim_task(handler, session, csrf, blocker, task_version(db, blocker))
  |> expect.equal(200)

  let still_blocked =
    claim_task_response(
      handler,
      session,
      csrf,
      blocked,
      task_version(db, blocked),
    )
  expect.expect_status(still_blocked, 409)
}

pub fn claimed_task_blocked_after_claim_cannot_close_but_can_release_test() {
  let #(db, handler, session, csrf, project_id, type_id) =
    ht08_project("HT08 Claimed Blocked Close")
  let blocked =
    create_task(handler, session, csrf, project_id, "Blocked", "", 3, type_id)
  let blocker =
    create_task(handler, session, csrf, project_id, "Blocker", "", 3, type_id)

  claim_task(handler, session, csrf, blocked, task_version(db, blocked))
  |> expect.equal(200)
  create_dependency(handler, session, csrf, blocked, blocker)
  |> expect.equal(200)

  let close_blocked =
    close_task_response(
      handler,
      session,
      csrf,
      blocked,
      task_version(db, blocked),
    )
  expect.expect_status(close_blocked, 409)
  simulate.read_body(close_blocked)
  |> string.contains("CONFLICT_BLOCKED")
  |> expect.is_true
  task_claimed_by(db, blocked) |> expect.equal(1)

  release_task(handler, session, csrf, blocked, task_version(db, blocked))
  |> expect.equal(200)
  task_claimed_by(db, blocked) |> expect.equal(0)
}

pub fn dependency_unblocks_when_dependency_closed_test() {
  let #(db, handler, session, csrf, project_id, type_id) =
    ht08_project("HT08 Closed Dependency")
  let blocked =
    create_task(handler, session, csrf, project_id, "Blocked", "", 3, type_id)
  let blocker =
    create_task(handler, session, csrf, project_id, "Blocker", "", 3, type_id)

  create_dependency(handler, session, csrf, blocked, blocker)
  |> expect.equal(200)
  claim_task(handler, session, csrf, blocker, task_version(db, blocker))
  |> expect.equal(200)
  close_task(handler, session, csrf, blocker, task_version(db, blocker))
  |> expect.equal(200)

  let unblocked_res =
    list_project_tasks(handler, session, csrf, project_id, "blocked=false")
  expect.expect_status(unblocked_res, 200)
  decode_task_titles(simulate.read_body(unblocked_res))
  |> list.contains("Blocked")
  |> expect.is_true
  claim_task(handler, session, csrf, blocked, task_version(db, blocked))
  |> expect.equal(200)
}

pub fn delete_dependency_target_unblocks_task_test() {
  let #(db, handler, session, csrf, project_id, type_id) =
    ht08_project("HT08 Delete Dependency")
  let blocked =
    create_task(handler, session, csrf, project_id, "Blocked", "", 3, type_id)
  let blocker =
    create_task(handler, session, csrf, project_id, "Blocker", "", 3, type_id)

  create_dependency(handler, session, csrf, blocked, blocker)
  |> expect.equal(200)
  delete_dependency(handler, session, csrf, blocked, blocker)
  |> expect.equal(204)
  claim_task(handler, session, csrf, blocked, task_version(db, blocked))
  |> expect.equal(200)
}

pub fn manual_close_claimed_task_allowed_only_for_owner_test() {
  let #(db, handler, admin_session, admin_csrf, project_id, type_id) =
    ht08_project("HT08 Close Owner")

  create_member_user(handler, db, "owner@example.com", "inv_owner")
  create_member_user(handler, db, "other-owner@example.com", "inv_other_owner")
  let owner_id =
    single_int(db, "select id from users where email = 'owner@example.com'", [])
  let other_id =
    single_int(
      db,
      "select id from users where email = 'other-owner@example.com'",
      [],
    )
  add_member(handler, admin_session, admin_csrf, project_id, owner_id, "member")
  add_member(handler, admin_session, admin_csrf, project_id, other_id, "member")

  let #(owner_session, owner_csrf) = login_session(handler, "owner@example.com")
  let #(other_session, other_csrf) =
    login_session(handler, "other-owner@example.com")

  let task_id =
    create_task(
      handler,
      admin_session,
      admin_csrf,
      project_id,
      "Owned",
      "",
      3,
      type_id,
    )
  claim_task(
    handler,
    owner_session,
    owner_csrf,
    task_id,
    task_version(db, task_id),
  )
  |> expect.equal(200)

  let other_close =
    close_task_response(
      handler,
      other_session,
      other_csrf,
      task_id,
      task_version(db, task_id),
    )
  expect.expect_status(other_close, 403)

  close_task(
    handler,
    owner_session,
    owner_csrf,
    task_id,
    task_version(db, task_id),
  )
  |> expect.equal(200)
}

pub fn dependency_would_create_cycle_is_rejected_test() {
  let #(_, handler, session, csrf, project_id, type_id) =
    ht08_project("HT08 Cycle")
  let task_a =
    create_task(handler, session, csrf, project_id, "Task A", "", 3, type_id)
  let task_b =
    create_task(handler, session, csrf, project_id, "Task B", "", 3, type_id)

  create_dependency(handler, session, csrf, task_a, task_b) |> expect.equal(200)
  create_dependency(handler, session, csrf, task_b, task_a) |> expect.equal(422)
}

pub fn cross_project_dependency_is_rejected_test() {
  let #(_db, handler, session, csrf, project_one_id, type_one_id) =
    ht08_project("HT08 Cross One")
  let project_two_id = create_project(handler, session, csrf, "HT08 Cross Two")
  let type_two_id =
    create_task_type(
      handler,
      session,
      csrf,
      project_two_id,
      "Bug",
      "bug-ant",
      0,
    )

  let task_one =
    create_task(
      handler,
      session,
      csrf,
      project_one_id,
      "Task One",
      "",
      3,
      type_one_id,
    )
  let task_two =
    create_task(
      handler,
      session,
      csrf,
      project_two_id,
      "Task Two",
      "",
      3,
      type_two_id,
    )

  create_dependency(handler, session, csrf, task_one, task_two)
  |> expect.equal(422)
}

pub fn pool_filters_by_user_capabilities_test() {
  let #(db, handler, admin_session, admin_csrf, project_id, _) =
    ht08_project("HT08 Capabilities")
  let frontend = insert_capability(db, project_id, "Frontend")
  let backend = insert_capability(db, project_id, "Backend")
  let frontend_type =
    create_task_type(
      handler,
      admin_session,
      admin_csrf,
      project_id,
      "Frontend Task",
      "bolt",
      frontend,
    )
  let backend_type =
    create_task_type(
      handler,
      admin_session,
      admin_csrf,
      project_id,
      "Backend Task",
      "bug-ant",
      backend,
    )

  create_member_user(handler, db, "cap-user@example.com", "inv_cap")
  let member_id =
    single_int(
      db,
      "select id from users where email = 'cap-user@example.com'",
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
  grant_capability(db, project_id, member_id, frontend)

  create_task(
    handler,
    admin_session,
    admin_csrf,
    project_id,
    "Visible frontend",
    "",
    3,
    frontend_type,
  )
  create_task(
    handler,
    admin_session,
    admin_csrf,
    project_id,
    "Hidden backend",
    "",
    3,
    backend_type,
  )

  let #(member_session, member_csrf) =
    login_session(handler, "cap-user@example.com")

  let res =
    list_project_tasks(handler, member_session, member_csrf, project_id, "")
  expect.expect_status(res, 200)
  decode_task_titles(simulate.read_body(res))
  |> expect.equal(["Visible frontend"])
}

pub fn me_metrics_returns_counts_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: _db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let #(session, csrf) = login_session(handler, "admin@example.com")
  let project_id = create_project(handler, session, csrf, "Core")
  let type_id =
    create_task_type(handler, session, csrf, project_id, "Bug", "bug-ant", 0)

  let task_id =
    create_task(handler, session, csrf, project_id, "Core", "", 3, type_id)

  claim_task(handler, session, csrf, task_id, 1) |> expect.equal(200)
  close_task(handler, session, csrf, task_id, 2) |> expect.equal(200)

  let req =
    simulate.request(http.Get, "/api/v1/me/metrics?window_days=30")
    |> fixtures.with_session_cookies(session, csrf)

  let res = handler(req)
  expect.expect_status(res, 200)

  let body = simulate.read_body(res)
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let metrics_decoder = {
    use claimed_count <- decode.field("claimed_count", decode.int)
    use released_count <- decode.field("released_count", decode.int)
    use closed_count <- decode.field("closed_count", decode.int)
    decode.success(#(claimed_count, released_count, closed_count))
  }

  let data_decoder = {
    use metrics <- decode.field("metrics", metrics_decoder)
    decode.success(metrics)
  }

  let response_decoder = decode.field("data", data_decoder, decode.success)

  let assert Ok(#(claimed, released, closed)) =
    decode.run(dynamic, response_decoder)

  claimed |> expect.equal(1)
  released |> expect.equal(0)
  closed |> expect.equal(1)
}

pub fn org_metrics_overview_requires_org_admin_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let #(admin_session, admin_csrf) = login_session(handler, "admin@example.com")

  create_member_user(handler, db, "member@example.com", "inv_member")

  let #(member_session, member_csrf) =
    login_session(handler, "member@example.com")

  // member is authenticated but not org admin
  let req =
    simulate.request(http.Get, "/api/v1/org/metrics/overview")
    |> fixtures.with_session_cookies(member_session, member_csrf)

  let res = handler(req)
  expect.expect_status(res, 403)

  // admin succeeds
  let admin_req =
    simulate.request(http.Get, "/api/v1/org/metrics/overview")
    |> fixtures.with_session_cookies(admin_session, admin_csrf)

  let admin_res = handler(admin_req)
  expect.expect_status(admin_res, 200)
}

pub fn org_metrics_project_tasks_returns_metrics_shape_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let #(session, csrf) = login_session(handler, "admin@example.com")
  let project_id = create_project(handler, session, csrf, "Core")
  let type_id =
    create_task_type(handler, session, csrf, project_id, "Bug", "bug-ant", 0)

  let task_id =
    create_task(handler, session, csrf, project_id, "Core", "", 3, type_id)

  claim_task(handler, session, csrf, task_id, 1) |> expect.equal(200)
  expect.expect_status(start_work_session(handler, session, csrf, task_id), 200)

  let user_id =
    single_int(db, "select id from users where email = 'admin@example.com'", [])

  let req =
    simulate.request(
      http.Get,
      "/api/v1/org/metrics/projects/" <> int_to_string(project_id) <> "/tasks",
    )
    |> fixtures.with_session_cookies(session, csrf)

  let res = handler(req)
  expect.expect_status(res, 200)

  let body = simulate.read_body(res)
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let task_decoder = {
    use id <- decode.field("id", decode.int)

    // Ensure global Task contract fields exist
    use _task_type <- decode.field("task_type", decode.dynamic)
    use status <- decode.field("status", decode.string)
    use work_state <- decode.field("work_state", decode.string)
    use ongoing_by <- decode.field(
      "ongoing_by",
      decode.optional({
        use user_id <- decode.field("user_id", decode.int)
        decode.success(user_id)
      }),
    )

    use claim_count <- decode.field("claim_count", decode.int)
    use release_count <- decode.field("release_count", decode.int)
    use close_count <- decode.field("close_count", decode.int)
    use first_claim_at <- decode.field(
      "first_claim_at",
      decode.optional(decode.string),
    )

    decode.success(#(
      id,
      status,
      work_state,
      ongoing_by,
      claim_count,
      release_count,
      close_count,
      first_claim_at,
    ))
  }

  let data_decoder = {
    use tasks <- decode.field("tasks", decode.list(task_decoder))
    decode.success(tasks)
  }

  let response_decoder = decode.field("data", data_decoder, decode.success)

  let assert Ok(tasks) = decode.run(dynamic, response_decoder)

  case tasks {
    [
      #(
        id,
        status,
        work_state,
        ongoing_by,
        claim_count,
        release_count,
        close_count,
        first_claim_at,
      ),
      ..
    ] -> {
      id |> expect.equal(task_id)
      status |> expect.equal("claimed")
      work_state |> expect.equal("ongoing")
      ongoing_by |> expect.equal(option.Some(user_id))
      claim_count |> expect.equal(1)
      release_count |> expect.equal(0)
      close_count |> expect.equal(0)
      let _ = first_claim_at |> expect.some
      Nil
    }
    _ -> False |> expect.is_true
  }
}

pub fn org_metrics_users_requires_org_admin_and_returns_shape_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let #(admin_session, admin_csrf) = login_session(handler, "admin@example.com")

  create_member_user(handler, db, "member@example.com", "inv_member")

  let #(member_session, member_csrf) =
    login_session(handler, "member@example.com")

  let member_req =
    simulate.request(http.Get, "/api/v1/org/metrics/users")
    |> fixtures.with_session_cookies(member_session, member_csrf)

  let member_res = handler(member_req)
  expect.expect_status(member_res, 403)

  let admin_req =
    simulate.request(http.Get, "/api/v1/org/metrics/users")
    |> fixtures.with_session_cookies(admin_session, admin_csrf)

  let admin_res = handler(admin_req)
  expect.expect_status(admin_res, 200)

  let body = simulate.read_body(admin_res)
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let user_decoder: decode.Decoder(#(Int, String, Int, Int, Int, Int)) = {
    use user_id <- decode.field("user_id", decode.int)
    use email <- decode.field("email", decode.string)
    use claimed_count <- decode.field("claimed_count", decode.int)
    use released_count <- decode.field("released_count", decode.int)
    use closed_count <- decode.field("closed_count", decode.int)
    use ongoing_count <- decode.field("ongoing_count", decode.int)
    use _last_claim_at <- decode.field(
      "last_claim_at",
      decode.optional(decode.string),
    )
    decode.success(#(
      user_id,
      email,
      claimed_count,
      released_count,
      closed_count,
      ongoing_count,
    ))
  }

  let data_decoder = {
    use users <- decode.field("users", decode.list(user_decoder))
    decode.success(users)
  }

  let response_decoder = decode.field("data", data_decoder, decode.success)

  let assert Ok(users) = decode.run(dynamic, response_decoder)

  case users {
    [#(_user_id, email, _claimed, _released, _closed, _ongoing), ..] -> {
      email |> expect.equal("admin@example.com")
      Nil
    }
    _ -> False |> expect.is_true
  }
}

pub fn org_metrics_users_invalid_window_days_returns_422_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(..) = app
  let handler = scrumbringer_server.handler(app)

  let #(session, csrf) = login_session(handler, "admin@example.com")

  let req =
    simulate.request(http.Get, "/api/v1/org/metrics/users?window_days=999")
    |> fixtures.with_session_cookies(session, csrf)

  let res = handler(req)
  expect.expect_status(res, 422)
}

pub fn tasks_list_requires_membership_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let #(admin_session, admin_csrf) = login_session(handler, "admin@example.com")
  let project_id = create_project(handler, admin_session, admin_csrf, "Core")

  create_member_user(handler, db, "outsider@example.com", "inv_out")
  let #(outsider_session, outsider_csrf) =
    login_session(handler, "outsider@example.com")

  let req =
    simulate.request(
      http.Get,
      "/api/v1/projects/" <> int_to_string(project_id) <> "/tasks",
    )
    |> fixtures.with_session_cookies(outsider_session, outsider_csrf)

  let res = handler(req)
  expect.expect_status(res, 403)
  string.contains(simulate.read_body(res), "FORBIDDEN") |> expect.is_true
}

pub fn task_get_requires_membership_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let #(session, csrf) = login_session(handler, "admin@example.com")
  let project_id = create_project(handler, session, csrf, "Core")
  let type_id =
    create_task_type(handler, session, csrf, project_id, "Bug", "bug-ant", 0)

  let task_id =
    create_task(handler, session, csrf, project_id, "Secret", "", 3, type_id)

  create_member_user(handler, db, "outsider@example.com", "inv_out")
  let #(outsider_session, outsider_csrf) =
    login_session(handler, "outsider@example.com")

  let req =
    simulate.request(http.Get, "/api/v1/tasks/" <> int_to_string(task_id))
    |> fixtures.with_session_cookies(outsider_session, outsider_csrf)

  let res = handler(req)
  expect.expect_status(res, 404)
  string.contains(simulate.read_body(res), "NOT_FOUND") |> expect.is_true
}

// Justification: large function kept intact to preserve cohesive logic.
pub fn tasks_list_filters_status_type_and_invalid_values_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: _db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let #(session, csrf) = login_session(handler, "admin@example.com")
  let project_id = create_project(handler, session, csrf, "Core")

  let bug_type_id =
    create_task_type(handler, session, csrf, project_id, "Bug", "bug-ant", 0)
  let chore_type_id =
    create_task_type(handler, session, csrf, project_id, "Chore", "bolt", 0)

  let available_id =
    create_task(
      handler,
      session,
      csrf,
      project_id,
      "Available",
      "",
      3,
      bug_type_id,
    )

  let claimed_id =
    create_task(
      handler,
      session,
      csrf,
      project_id,
      "Claimed",
      "",
      3,
      chore_type_id,
    )

  let closed_id =
    create_task(
      handler,
      session,
      csrf,
      project_id,
      "Closed",
      "",
      3,
      bug_type_id,
    )

  claim_task(handler, session, csrf, claimed_id, 1) |> expect.equal(200)
  claim_task(handler, session, csrf, closed_id, 1) |> expect.equal(200)
  close_task(handler, session, csrf, closed_id, 2) |> expect.equal(200)

  let available_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/projects/"
          <> int_to_string(project_id)
          <> "/tasks?status=available",
      )
      |> fixtures.with_session_cookies(session, csrf),
    )

  expect.expect_status(available_res, 200)
  decode_task_titles(simulate.read_body(available_res))
  |> expect.equal(["Available"])

  let claimed_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/projects/"
          <> int_to_string(project_id)
          <> "/tasks?status=claimed",
      )
      |> fixtures.with_session_cookies(session, csrf),
    )

  expect.expect_status(claimed_res, 200)
  decode_task_titles(simulate.read_body(claimed_res))
  |> expect.equal(["Claimed"])

  let closed_filter_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/projects/"
          <> int_to_string(project_id)
          <> "/tasks?status=closed",
      )
      |> fixtures.with_session_cookies(session, csrf),
    )

  expect.expect_status(closed_filter_res, 200)
  decode_task_titles(simulate.read_body(closed_filter_res))
  |> expect.equal(["Closed"])

  let type_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/projects/"
          <> int_to_string(project_id)
          <> "/tasks?type_id="
          <> int_to_string(bug_type_id),
      )
      |> fixtures.with_session_cookies(session, csrf),
    )

  expect.expect_status(type_res, 200)
  decode_task_titles(simulate.read_body(type_res))
  |> expect.equal(["Closed", "Available"])

  let invalid_status_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/projects/" <> int_to_string(project_id) <> "/tasks?status=nope",
      )
      |> fixtures.with_session_cookies(session, csrf),
    )

  expect.expect_status(invalid_status_res, 422)
  string.contains(simulate.read_body(invalid_status_res), "VALIDATION_ERROR")
  |> expect.is_true

  let invalid_type_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/projects/" <> int_to_string(project_id) <> "/tasks?type_id=abc",
      )
      |> fixtures.with_session_cookies(session, csrf),
    )

  expect.expect_status(invalid_type_res, 422)
  string.contains(simulate.read_body(invalid_type_res), "VALIDATION_ERROR")
  |> expect.is_true

  let invalid_cap_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/projects/"
          <> int_to_string(project_id)
          <> "/tasks?capability_id=abc",
      )
      |> fixtures.with_session_cookies(session, csrf),
    )

  expect.expect_status(invalid_cap_res, 422)
  string.contains(simulate.read_body(invalid_cap_res), "VALIDATION_ERROR")
  |> expect.is_true

  let _ = available_id
}

// Justification: large function kept intact to preserve cohesive logic.
pub fn patch_ignores_claimed_by_and_non_claimer_forbidden_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let #(admin_session, admin_csrf) = login_session(handler, "admin@example.com")
  let project_id = create_project(handler, admin_session, admin_csrf, "Core")
  let type_id =
    create_task_type(
      handler,
      admin_session,
      admin_csrf,
      project_id,
      "Bug",
      "bug-ant",
      0,
    )

  create_member_user(handler, db, "member@example.com", "inv_member")
  create_member_user(handler, db, "other@example.com", "inv_other")

  let member_id =
    single_int(
      db,
      "select id from users where email = 'member@example.com'",
      [],
    )
  let other_id =
    single_int(db, "select id from users where email = 'other@example.com'", [])

  add_member(
    handler,
    admin_session,
    admin_csrf,
    project_id,
    member_id,
    "member",
  )
  add_member(handler, admin_session, admin_csrf, project_id, other_id, "member")

  let #(member_session, member_csrf) =
    login_session(handler, "member@example.com")

  let #(other_session, other_csrf) = login_session(handler, "other@example.com")

  let task_id =
    create_task(
      handler,
      admin_session,
      admin_csrf,
      project_id,
      "Core",
      "",
      3,
      type_id,
    )

  claim_task(handler, member_session, member_csrf, task_id, 1)
  |> expect.equal(200)

  let patch_ok_res =
    handler(
      simulate.request(http.Patch, "/api/v1/tasks/" <> int_to_string(task_id))
      |> fixtures.with_auth(fixture_session(member_session, member_csrf))
      |> simulate.json_body(
        json.object([
          #("version", json.int(2)),
          #("title", json.string("New")),
          #("claimed_by", json.int(other_id)),
        ]),
      ),
    )

  expect.expect_status(patch_ok_res, 200)

  task_claimed_by(db, task_id) |> expect.equal(member_id)

  let version = task_version(db, task_id)

  let patch_other_res =
    handler(
      simulate.request(http.Patch, "/api/v1/tasks/" <> int_to_string(task_id))
      |> fixtures.with_auth(fixture_session(other_session, other_csrf))
      |> simulate.json_body(
        json.object([
          #("version", json.int(version)),
          #("title", json.string("Other")),
        ]),
      ),
    )

  expect.expect_status(patch_other_res, 403)

  let release_other_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int_to_string(task_id) <> "/release",
      )
      |> fixtures.with_auth(fixture_session(other_session, other_csrf))
      |> simulate.json_body(json.object([#("version", json.int(version))])),
    )

  expect.expect_status(release_other_res, 403)

  let close_other_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int_to_string(task_id) <> "/close",
      )
      |> fixtures.with_auth(fixture_session(other_session, other_csrf))
      |> simulate.json_body(json.object([#("version", json.int(version))])),
    )

  expect.expect_status(close_other_res, 403)
}

pub fn patch_rejects_blank_title_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: _db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let #(session, csrf) = login_session(handler, "admin@example.com")
  let project_id = create_project(handler, session, csrf, "Core")
  let type_id =
    create_task_type(handler, session, csrf, project_id, "Bug", "bug-ant", 0)

  let task_id =
    create_task(handler, session, csrf, project_id, "Core", "", 3, type_id)

  claim_task(handler, session, csrf, task_id, 1) |> expect.equal(200)

  let res =
    handler(
      simulate.request(http.Patch, "/api/v1/tasks/" <> int_to_string(task_id))
      |> fixtures.with_auth(fixture_session(session, csrf))
      |> simulate.json_body(
        json.object([
          #("version", json.int(2)),
          #("title", json.string("   ")),
        ]),
      ),
    )

  expect.expect_status(res, 422)
  string.contains(simulate.read_body(res), "Title is required")
  |> expect.is_true
}

pub fn me_work_session_start_pause_and_persist_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let #(session, csrf) = login_session(handler, "admin@example.com")
  let project_id = create_project(handler, session, csrf, "Core")
  let type_id =
    create_task_type(handler, session, csrf, project_id, "Bug", "bug-ant", 0)

  let task_id =
    create_task(handler, session, csrf, project_id, "Core", "", 3, type_id)

  claim_task(handler, session, csrf, task_id, 1) |> expect.equal(200)

  let start_body =
    simulate.read_body(start_work_session(handler, session, csrf, task_id))

  decode_work_session_task_id(start_body) |> expect.equal(option.Some(task_id))
  is_iso8601_utc(decode_as_of(start_body)) |> expect.equal(True)

  let get_res = get_active_work_sessions(handler, session, csrf)
  expect.expect_status(get_res, 200)
  decode_work_session_task_id(simulate.read_body(get_res))
  |> expect.equal(option.Some(task_id))

  // Simulate ~70s of elapsed time, then pause to flush accumulation.
  let user_id =
    single_int(db, "select id from users where email = 'admin@example.com'", [])

  let _ =
    pog.query(
      "update user_task_work_session set started_at = now() - interval '70 seconds' where user_id = $1 and task_id = $2 and ended_at is null",
    )
    |> pog.parameter(pog.int(user_id))
    |> pog.parameter(pog.int(task_id))
    |> pog.execute(db)

  let pause_res = pause_work_session(handler, session, csrf, task_id)
  expect.expect_status(pause_res, 200)
  decode_work_session_task_id(simulate.read_body(pause_res))
  |> expect.equal(option.None)

  let accumulated_after_pause =
    single_int(
      db,
      "select accumulated_s from user_task_work_total where user_id = $1 and task_id = $2",
      [pog.int(user_id), pog.int(task_id)],
    )

  let _ = expect.is_true(accumulated_after_pause >= 70)

  let resume_body =
    simulate.read_body(start_work_session(handler, session, csrf, task_id))

  decode_work_session_accumulated_s(resume_body)
  |> expect.equal(option.Some(accumulated_after_pause))

  let get_after_pause = get_active_work_sessions(handler, session, csrf)
  expect.expect_status(get_after_pause, 200)
  decode_work_session_task_id(simulate.read_body(get_after_pause))
  |> expect.equal(option.Some(task_id))
}

pub fn me_work_session_heartbeat_updates_last_heartbeat_at_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let #(session, csrf) = login_session(handler, "admin@example.com")
  let project_id = create_project(handler, session, csrf, "Core")
  let type_id =
    create_task_type(handler, session, csrf, project_id, "Bug", "bug-ant", 0)

  let task_id =
    create_task(handler, session, csrf, project_id, "Core", "", 3, type_id)

  claim_task(handler, session, csrf, task_id, 1) |> expect.equal(200)
  expect.expect_status(start_work_session(handler, session, csrf, task_id), 200)

  let user_id =
    single_int(db, "select id from users where email = 'admin@example.com'", [])

  // Set started_at to 65 seconds ago to simulate elapsed time
  let _ =
    pog.query(
      "update user_task_work_session set started_at = now() - interval '65 seconds' where user_id = $1 and task_id = $2 and ended_at is null",
    )
    |> pog.parameter(pog.int(user_id))
    |> pog.parameter(pog.int(task_id))
    |> pog.execute(db)

  // Get last_heartbeat_at before heartbeat (as epoch integer)
  let heartbeat_before =
    single_int(
      db,
      "select extract(epoch from last_heartbeat_at)::int from user_task_work_session where user_id = $1 and task_id = $2 and ended_at is null",
      [pog.int(user_id), pog.int(task_id)],
    )

  let heartbeat_res = heartbeat_work_session(handler, session, csrf, task_id)
  expect.expect_status(heartbeat_res, 200)

  // Get last_heartbeat_at after heartbeat
  let heartbeat_after =
    single_int(
      db,
      "select extract(epoch from last_heartbeat_at)::int from user_task_work_session where user_id = $1 and task_id = $2 and ended_at is null",
      [pog.int(user_id), pog.int(task_id)],
    )

  // last_heartbeat_at should have been updated (>= before, allows for same-second update)
  let _ = expect.is_true(heartbeat_after >= heartbeat_before)
  // Note: In the new multi-session model, accumulated_s is flushed to
  // user_task_work_total only when the session is paused/closed, not on heartbeat.
  // The API returns accumulated_s from user_task_work_total (previous sessions)
  // while elapsed time from active session is computed client-side from started_at.
}

pub fn me_work_sessions_supports_multiple_concurrent_sessions_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let #(session, csrf) = login_session(handler, "admin@example.com")
  let project_id = create_project(handler, session, csrf, "Core")
  let type_id =
    create_task_type(handler, session, csrf, project_id, "Bug", "bug-ant", 0)

  let t1 = create_task(handler, session, csrf, project_id, "T1", "", 3, type_id)
  let t2 = create_task(handler, session, csrf, project_id, "T2", "", 3, type_id)

  claim_task(handler, session, csrf, t1, 1) |> expect.equal(200)
  claim_task(handler, session, csrf, t2, 1) |> expect.equal(200)

  // Start sessions on both tasks - multi-session model supports this
  expect.expect_status(start_work_session(handler, session, csrf, t1), 200)
  let res = start_work_session(handler, session, csrf, t2)
  expect.expect_status(res, 200)

  // Verify both sessions exist
  let user_id =
    single_int(db, "select id from users where email = 'admin@example.com'", [])
  let session_count =
    single_int(
      db,
      "select count(*)::int from user_task_work_session where user_id = $1 and ended_at is null",
      [pog.int(user_id)],
    )
  session_count |> expect.equal(2)
}

pub fn me_work_session_start_returns_409_when_not_claimed_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: _db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let #(session, csrf) = login_session(handler, "admin@example.com")
  let project_id = create_project(handler, session, csrf, "Core")
  let type_id =
    create_task_type(handler, session, csrf, project_id, "Bug", "bug-ant", 0)

  let task_id =
    create_task(handler, session, csrf, project_id, "Core", "", 3, type_id)

  let res = start_work_session(handler, session, csrf, task_id)
  expect.expect_status(res, 409)
  string.contains(simulate.read_body(res), "CONFLICT_CLAIMED")
  |> expect.equal(True)
}

pub fn me_work_session_clears_before_release_and_close_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let #(session, csrf) = login_session(handler, "admin@example.com")
  let project_id = create_project(handler, session, csrf, "Core")
  let type_id =
    create_task_type(handler, session, csrf, project_id, "Bug", "bug-ant", 0)

  let task_id =
    create_task(handler, session, csrf, project_id, "Core", "", 3, type_id)

  claim_task(handler, session, csrf, task_id, 1) |> expect.equal(200)
  expect.expect_status(start_work_session(handler, session, csrf, task_id), 200)

  let version = task_version(db, task_id)

  let release_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int_to_string(task_id) <> "/release",
      )
      |> fixtures.with_auth(fixture_session(session, csrf))
      |> simulate.json_body(json.object([#("version", json.int(version))])),
    )

  expect.expect_status(release_res, 200)

  let active_after_release = get_active_work_sessions(handler, session, csrf)
  decode_work_session_task_id(simulate.read_body(active_after_release))
  |> expect.equal(option.None)

  // Re-claim + start, then close.
  let version = task_version(db, task_id)
  claim_task(handler, session, csrf, task_id, version) |> expect.equal(200)
  expect.expect_status(start_work_session(handler, session, csrf, task_id), 200)

  let version = task_version(db, task_id)
  close_task(handler, session, csrf, task_id, version) |> expect.equal(200)

  let active_after_close = get_active_work_sessions(handler, session, csrf)
  decode_work_session_task_id(simulate.read_body(active_after_close))
  |> expect.equal(option.None)
}

fn get_active_work_sessions(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
) -> wisp.Response {
  handler(
    simulate.request(http.Get, "/api/v1/me/work-sessions/active")
    |> fixtures.with_session_cookies(session, csrf),
  )
}

fn start_work_session(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  task_id: Int,
) -> wisp.Response {
  handler(
    simulate.request(http.Post, "/api/v1/me/work-sessions/start")
    |> fixtures.with_auth(fixture_session(session, csrf))
    |> simulate.json_body(json.object([#("task_id", json.int(task_id))])),
  )
}

fn pause_work_session(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  task_id: Int,
) -> wisp.Response {
  handler(
    simulate.request(http.Post, "/api/v1/me/work-sessions/pause")
    |> fixtures.with_auth(fixture_session(session, csrf))
    |> simulate.json_body(json.object([#("task_id", json.int(task_id))])),
  )
}

fn heartbeat_work_session(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  task_id: Int,
) -> wisp.Response {
  handler(
    simulate.request(http.Post, "/api/v1/me/work-sessions/heartbeat")
    |> fixtures.with_auth(fixture_session(session, csrf))
    |> simulate.json_body(json.object([#("task_id", json.int(task_id))])),
  )
}

fn decode_work_session(body: String) -> #(option.Option(Int), String, Int) {
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let session_decoder = {
    use task_id <- decode.field("task_id", decode.int)
    use accumulated_s <- decode.field("accumulated_s", decode.int)
    decode.success(#(task_id, accumulated_s))
  }

  let data_decoder = {
    use sessions <- decode.field(
      "active_sessions",
      decode.list(session_decoder),
    )
    use as_of <- decode.field("as_of", decode.string)

    let #(active_task_id, accumulated_s) = case sessions {
      [#(task_id, accumulated), ..] -> #(option.Some(task_id), accumulated)
      [] -> #(option.None, 0)
    }

    decode.success(#(active_task_id, as_of, accumulated_s))
  }

  let response_decoder = decode.field("data", data_decoder, decode.success)

  let assert Ok(payload) = decode.run(dynamic, response_decoder)
  payload
}

fn decode_work_session_task_id(body: String) -> option.Option(Int) {
  let #(active_task_id, _, _) = decode_work_session(body)
  active_task_id
}

fn decode_work_session_accumulated_s(body: String) -> option.Option(Int) {
  let #(active_task_id, _, accumulated_s) = decode_work_session(body)

  case active_task_id {
    option.Some(_) -> option.Some(accumulated_s)
    option.None -> option.None
  }
}

fn decode_as_of(body: String) -> String {
  let #(_, as_of, _) = decode_work_session(body)
  as_of
}

fn is_iso8601_utc(value: String) -> Bool {
  string.contains(value, "T") && string.ends_with(value, "Z")
}

fn task_claimed_by(db: pog.Connection, task_id: Int) -> Int {
  single_int(db, "select coalesce(claimed_by, 0) from tasks where id = $1", [
    pog.int(task_id),
  ])
}

fn task_version(db: pog.Connection, task_id: Int) -> Int {
  single_int(db, "select version from tasks where id = $1", [pog.int(task_id)])
}

fn count_audit_events(
  db: pog.Connection,
  task_id: Int,
  event_type: String,
) -> Int {
  single_int(
    db,
    "select count(*) from audit_events where task_id = $1 and event_type = $2",
    [pog.int(task_id), pog.text(event_type)],
  )
}

fn count_audit_events_for_task(db: pog.Connection, task_id: Int) -> Int {
  single_int(db, "select count(*) from audit_events where task_id = $1", [
    pog.int(task_id),
  ])
}

fn count_audit_events_for_actor(
  db: pog.Connection,
  task_id: Int,
  actor_user_id: Int,
  event_type: String,
) -> Int {
  single_int(
    db,
    "select count(*) from audit_events where task_id = $1 and actor_user_id = $2 and event_type = $3",
    [pog.int(task_id), pog.int(actor_user_id), pog.text(event_type)],
  )
}

fn count_task_rows(db: pog.Connection, task_id: Int) -> Int {
  single_int(db, "select count(*) from tasks where id = $1", [
    pog.int(task_id),
  ])
}

fn delete_task(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  task_id: Int,
) -> Int {
  let res = delete_task_response(handler, session, csrf, task_id)
  res.status
}

fn delete_task_response(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  task_id: Int,
) -> wisp.Response {
  handler(
    simulate.request(http.Delete, "/api/v1/tasks/" <> int_to_string(task_id))
    |> fixtures.with_auth(fixture_session(session, csrf)),
  )
}

fn create_task_note(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  task_id: Int,
  content: String,
) -> Int {
  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int_to_string(task_id) <> "/notes",
      )
      |> fixtures.with_auth(fixture_session(session, csrf))
      |> simulate.json_body(json.object([#("content", json.string(content))])),
    )

  res.status
}

fn claim_task(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  task_id: Int,
  version: Int,
) -> Int {
  let res = claim_task_response(handler, session, csrf, task_id, version)
  res.status
}

fn claim_task_response(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  task_id: Int,
  version: Int,
) -> wisp.Response {
  handler(
    simulate.request(
      http.Post,
      "/api/v1/tasks/" <> int_to_string(task_id) <> "/claim",
    )
    |> fixtures.with_auth(fixture_session(session, csrf))
    |> simulate.json_body(json.object([#("version", json.int(version))])),
  )
}

fn create_dependency(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  task_id: Int,
  depends_on_task_id: Int,
) -> Int {
  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int_to_string(task_id) <> "/dependencies",
      )
      |> fixtures.with_auth(fixture_session(session, csrf))
      |> simulate.json_body(
        json.object([#("depends_on_task_id", json.int(depends_on_task_id))]),
      ),
    )

  res.status
}

fn delete_dependency(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  task_id: Int,
  depends_on_task_id: Int,
) -> Int {
  let res =
    handler(
      simulate.request(
        http.Delete,
        "/api/v1/tasks/"
          <> int_to_string(task_id)
          <> "/dependencies/"
          <> int_to_string(depends_on_task_id),
      )
      |> fixtures.with_auth(fixture_session(session, csrf)),
    )

  res.status
}

fn release_task(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  task_id: Int,
  version: Int,
) -> Int {
  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int_to_string(task_id) <> "/release",
      )
      |> fixtures.with_auth(fixture_session(session, csrf))
      |> simulate.json_body(json.object([#("version", json.int(version))])),
    )

  res.status
}

fn close_task(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  task_id: Int,
  version: Int,
) -> Int {
  let res = close_task_response(handler, session, csrf, task_id, version)
  res.status
}

fn close_task_response(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  task_id: Int,
  version: Int,
) -> wisp.Response {
  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int_to_string(task_id) <> "/close",
      )
      |> fixtures.with_auth(fixture_session(session, csrf))
      |> simulate.json_body(json.object([#("version", json.int(version))])),
    )

  res
}

fn decode_task_titles(body: String) -> List(String) {
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let task_decoder = {
    use title <- decode.field("title", decode.string)
    decode.success(title)
  }

  let data_decoder = {
    use tasks <- decode.field("tasks", decode.list(task_decoder))
    decode.success(tasks)
  }

  let response_decoder = {
    use tasks <- decode.field("data", data_decoder)
    decode.success(tasks)
  }

  let assert Ok(tasks) = decode.run(dynamic, response_decoder)
  tasks
}

fn list_project_tasks(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  project_id: Int,
  query: String,
) -> wisp.Response {
  let url =
    "/api/v1/projects/"
    <> int_to_string(project_id)
    <> "/tasks"
    <> case query {
      "" -> ""
      value -> "?" <> value
    }

  handler(
    simulate.request(http.Get, url)
    |> fixtures.with_session_cookies(session, csrf),
  )
}

fn create_project(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  name: String,
) -> Int {
  fixtures.create_project(handler, fixture_session(session, csrf), name)
  |> expect.ok
}

fn create_task_type(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  project_id: Int,
  name: String,
  icon: String,
  capability_id: Int,
) -> Int {
  let body = case capability_id {
    0 ->
      json.object([
        #("name", json.string(name)),
        #("icon", json.string(icon)),
      ])
    id ->
      json.object([
        #("name", json.string(name)),
        #("icon", json.string(icon)),
        #("capability_id", json.int(id)),
      ])
  }

  let req =
    simulate.request(
      http.Post,
      "/api/v1/projects/" <> int_to_string(project_id) <> "/task-types",
    )
    |> fixtures.with_auth(fixture_session(session, csrf))
    |> simulate.json_body(body)

  let res = handler(req)
  expect.expect_status(res, 200)
  fixtures.decode_entity_id(simulate.read_body(res), fixtures.TaskType)
  |> expect.ok
}

fn create_task(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  project_id: Int,
  title: String,
  description: String,
  priority: Int,
  type_id: Int,
) -> Int {
  let card_id = create_active_card(handler, session, csrf, project_id, title)
  create_task_with_card(
    handler,
    session,
    csrf,
    project_id,
    title,
    description,
    priority,
    type_id,
    card_id,
  )
}

fn create_active_card(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  project_id: Int,
  title: String,
) -> Int {
  let card_id =
    create_card(handler, session, csrf, project_id, title <> " card")
  try_activate_card(handler, session, csrf, card_id)
  card_id
}

fn create_card(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  project_id: Int,
  title: String,
) -> Int {
  fixtures.create_card(
    handler,
    fixture_session(session, csrf),
    project_id,
    title,
  )
  |> expect.ok
}

fn try_activate_card(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  card_id: Int,
) {
  let req =
    simulate.request(
      http.Post,
      "/api/v1/cards/" <> int_to_string(card_id) <> "/activate",
    )
    |> fixtures.with_auth(fixture_session(session, csrf))
    |> simulate.json_body(json.object([]))

  let res = handler(req)
  case res.status {
    200 | 403 -> Nil
    _ -> expect.expect_status(res, 200)
  }
}

fn create_task_with_card(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  project_id: Int,
  title: String,
  description: String,
  priority: Int,
  type_id: Int,
  card_id: Int,
) -> Int {
  fixtures.create_task_with_card_full(
    handler,
    fixture_session(session, csrf),
    project_id,
    title,
    description,
    priority,
    type_id,
    card_id,
  )
  |> expect.ok
}

fn add_member(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  project_id: Int,
  user_id: Int,
  role: String,
) {
  fixtures.add_member(
    handler,
    fixture_session(session, csrf),
    project_id,
    user_id,
    role,
  )
  |> expect.ok
}

fn set_task_created_at(db: pog.Connection, task_id: Int, created_at: String) {
  let sql =
    "update tasks set created_at = timestamptz '"
    <> created_at
    <> "' where id = $1"

  let assert Ok(_) =
    pog.query(sql)
    |> pog.parameter(pog.int(task_id))
    |> pog.execute(db)

  Nil
}

fn insert_capability(db: pog.Connection, project_id: Int, name: String) -> Int {
  let assert Ok(pog.Returned(rows: [id, ..], ..)) =
    pog.query(
      "insert into capabilities (project_id, name) values ($1, $2) returning id",
    )
    |> pog.parameter(pog.int(project_id))
    |> pog.parameter(pog.text(name))
    |> pog.returning({
      use id <- decode.field(0, decode.int)
      decode.success(id)
    })
    |> pog.execute(db)

  id
}

fn grant_capability(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
  capability_id: Int,
) {
  let assert Ok(_) =
    pog.query(
      "insert into project_member_capabilities (project_id, user_id, capability_id) values ($1, $2, $3)",
    )
    |> pog.parameter(pog.int(project_id))
    |> pog.parameter(pog.int(user_id))
    |> pog.parameter(pog.int(capability_id))
    |> pog.execute(db)

  Nil
}

fn insert_card_state(
  db: pog.Connection,
  project_id: Int,
  title: String,
  execution_state: String,
) -> Int {
  let assert Ok(pog.Returned(rows: [id, ..], ..)) =
    pog.query(
      "insert into cards (project_id, title, description, created_by, execution_state) values ($1, $2, '', 1, $3) returning id",
    )
    |> pog.parameter(pog.int(project_id))
    |> pog.parameter(pog.text(title))
    |> pog.parameter(pog.text(execution_state))
    |> pog.returning({
      use id <- decode.field(0, decode.int)
      decode.success(id)
    })
    |> pog.execute(db)

  id
}

fn ht08_project(name: String) {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let #(session, csrf) = login_session(handler, "admin@example.com")

  let project_id = create_project(handler, session, csrf, name)
  let type_id =
    create_task_type(handler, session, csrf, project_id, "Bug", "bug-ant", 0)

  #(db, handler, session, csrf, project_id, type_id)
}

fn create_member_user(
  handler: fn(wisp.Request) -> wisp.Response,
  db: pog.Connection,
  email: String,
  invite_code: String,
) {
  fixtures.create_member_user(handler, db, email, invite_code)
  |> expect.ok
  |> fn(_) { Nil }
}

fn bootstrap_app() -> scrumbringer_server.App {
  let #(app, _, _) = fixtures.bootstrap() |> expect.ok
  app
}

fn single_int(db: pog.Connection, sql: String, params: List(pog.Value)) -> Int {
  fixtures.query_int(db, sql, params)
  |> expect.ok
}

fn int_to_string(value: Int) -> String {
  value |> int_to_string_unsafe
}

@external(erlang, "erlang", "integer_to_binary")
fn int_to_string_unsafe(value: Int) -> String
