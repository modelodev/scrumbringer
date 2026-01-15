import gleam/dynamic/decode
import gleam/erlang/charlist
import gleam/http
import gleam/http/request
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleeunit/should
import pog
import scrumbringer_server
import wisp
import wisp/simulate

const secret = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

pub fn task_types_list_sorted_by_name_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  create_project(handler, session, csrf, "Core")
  let project_id =
    single_int(db, "select id from projects where name = 'Core'", [])

  create_task_type(handler, session, csrf, project_id, "Zulu", "bug-ant", 0)
  create_task_type(handler, session, csrf, project_id, "Alpha", "bolt", 0)

  let req =
    simulate.request(
      http.Get,
      "/api/v1/projects/" <> int_to_string(project_id) <> "/task-types",
    )
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)

  let res = handler(req)
  res.status |> should.equal(200)

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
  task_types |> should.equal(["Alpha", "Zulu"])
}

pub fn task_types_create_requires_project_admin_and_csrf_test() {
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

  let member_req =
    simulate.request(
      http.Post,
      "/api/v1/projects/" <> int_to_string(project_id) <> "/task-types",
    )
    |> request.set_cookie("sb_session", member_session)
    |> request.set_cookie("sb_csrf", member_csrf)
    |> request.set_header("X-CSRF", member_csrf)
    |> simulate.json_body(
      json.object([
        #("name", json.string("Bug")),
        #("icon", json.string("bug-ant")),
      ]),
    )

  let member_res = handler(member_req)
  member_res.status |> should.equal(403)

  let no_csrf_req =
    simulate.request(
      http.Post,
      "/api/v1/projects/" <> int_to_string(project_id) <> "/task-types",
    )
    |> request.set_cookie("sb_session", admin_session)
    |> request.set_cookie("sb_csrf", admin_csrf)
    |> simulate.json_body(
      json.object([
        #("name", json.string("Bug")),
        #("icon", json.string("bug-ant")),
      ]),
    )

  let no_csrf_res = handler(no_csrf_req)
  no_csrf_res.status |> should.equal(403)
}

pub fn tasks_list_filters_sorting_and_q_search_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  create_project(handler, session, csrf, "Core")
  let project_id =
    single_int(db, "select id from projects where name = 'Core'", [])

  let cap1 = insert_capability(db, 1, "Frontend")
  let cap2 = insert_capability(db, 1, "Backend")

  create_task_type(
    handler,
    session,
    csrf,
    project_id,
    "NeedleType",
    "bug-ant",
    cap1,
  )
  create_task_type(
    handler,
    session,
    csrf,
    project_id,
    "OtherType",
    "bolt",
    cap2,
  )

  let needle_type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'NeedleType'",
      [pog.int(project_id)],
    )

  let other_type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'OtherType'",
      [pog.int(project_id)],
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
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf),
    )

  list_res.status |> should.equal(200)
  let list_titles = decode_task_titles(simulate.read_body(list_res))
  list_titles |> should.equal(["needle in title", "Unrelated", "Old"])

  let q_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/projects/" <> int_to_string(project_id) <> "/tasks?q=needle",
      )
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf),
    )

  q_res.status |> should.equal(200)
  let q_titles = decode_task_titles(simulate.read_body(q_res))
  q_titles |> should.equal(["needle in title"])

  let cap_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/projects/"
          <> int_to_string(project_id)
          <> "/tasks?capability_id="
          <> int_to_string(cap1),
      )
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf),
    )

  cap_res.status |> should.equal(200)
  let cap_titles = decode_task_titles(simulate.read_body(cap_res))
  cap_titles |> should.equal(["Unrelated"])

  let multi_cap_req =
    simulate.request(
      http.Get,
      "/api/v1/projects/"
        <> int_to_string(project_id)
        <> "/tasks?capability_id=1,2",
    )
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)

  let multi_cap_res = handler(multi_cap_req)
  multi_cap_res.status |> should.equal(422)
  string.contains(simulate.read_body(multi_cap_res), "VALIDATION_ERROR")
  |> should.be_true
}

pub fn claim_conflict_version_conflict_and_state_machine_test() {
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
    "Bug",
    "bug-ant",
    0,
  )
  let type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Bug'",
      [pog.int(project_id)],
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

  let member_login_res =
    login_as(handler, "member@example.com", "passwordpassword")
  let member_session = find_cookie_value(member_login_res.headers, "sb_session")
  let member_csrf = find_cookie_value(member_login_res.headers, "sb_csrf")

  let other_login_res =
    login_as(handler, "other@example.com", "passwordpassword")
  let other_session = find_cookie_value(other_login_res.headers, "sb_session")
  let other_csrf = find_cookie_value(other_login_res.headers, "sb_csrf")

  let task_id =
    create_task(
      handler,
      member_session,
      member_csrf,
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
    |> request.set_cookie("sb_session", member_session)
    |> request.set_cookie("sb_csrf", member_csrf)
    |> request.set_header("X-CSRF", member_csrf)
    |> simulate.json_body(json.object([#("version", json.int(1))]))

  let claim_res = handler(claim_req)
  claim_res.status |> should.equal(200)

  let claim2_req =
    simulate.request(
      http.Post,
      "/api/v1/tasks/" <> int_to_string(task_id) <> "/claim",
    )
    |> request.set_cookie("sb_session", other_session)
    |> request.set_cookie("sb_csrf", other_csrf)
    |> request.set_header("X-CSRF", other_csrf)
    |> simulate.json_body(json.object([#("version", json.int(1))]))

  let claim2_res = handler(claim2_req)
  claim2_res.status |> should.equal(409)
  string.contains(simulate.read_body(claim2_res), "CONFLICT_CLAIMED")
  |> should.be_true

  let patch_req =
    simulate.request(http.Patch, "/api/v1/tasks/" <> int_to_string(task_id))
    |> request.set_cookie("sb_session", member_session)
    |> request.set_cookie("sb_csrf", member_csrf)
    |> request.set_header("X-CSRF", member_csrf)
    |> simulate.json_body(
      json.object([
        #("version", json.int(1)),
        #("title", json.string("New")),
        #("claimed_by", json.int(999)),
      ]),
    )

  let patch_res = handler(patch_req)
  patch_res.status |> should.equal(409)
  string.contains(simulate.read_body(patch_res), "CONFLICT_VERSION")
  |> should.be_true

  let release_bad_req =
    simulate.request(
      http.Post,
      "/api/v1/tasks/" <> int_to_string(task_id) <> "/release",
    )
    |> request.set_cookie("sb_session", member_session)
    |> request.set_cookie("sb_csrf", member_csrf)
    |> request.set_header("X-CSRF", member_csrf)
    |> simulate.json_body(json.object([#("version", json.int(1))]))

  let release_bad_res = handler(release_bad_req)
  release_bad_res.status |> should.equal(409)
  string.contains(simulate.read_body(release_bad_res), "CONFLICT_VERSION")
  |> should.be_true

  let release_ok_req =
    simulate.request(
      http.Post,
      "/api/v1/tasks/" <> int_to_string(task_id) <> "/release",
    )
    |> request.set_cookie("sb_session", member_session)
    |> request.set_cookie("sb_csrf", member_csrf)
    |> request.set_header("X-CSRF", member_csrf)
    |> simulate.json_body(json.object([#("version", json.int(2))]))

  let release_ok_res = handler(release_ok_req)
  release_ok_res.status |> should.equal(200)

  let complete_bad_req =
    simulate.request(
      http.Post,
      "/api/v1/tasks/" <> int_to_string(task_id) <> "/complete",
    )
    |> request.set_cookie("sb_session", member_session)
    |> request.set_cookie("sb_csrf", member_csrf)
    |> request.set_header("X-CSRF", member_csrf)
    |> simulate.json_body(json.object([#("version", json.int(3))]))

  let complete_bad_res = handler(complete_bad_req)
  complete_bad_res.status |> should.equal(422)
  string.contains(simulate.read_body(complete_bad_res), "VALIDATION_ERROR")
  |> should.be_true
}

pub fn tasks_list_requires_membership_test() {
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

  create_member_user(handler, db, "outsider@example.com", "inv_out")
  let outsider_login_res =
    login_as(handler, "outsider@example.com", "passwordpassword")
  let outsider_session =
    find_cookie_value(outsider_login_res.headers, "sb_session")
  let outsider_csrf = find_cookie_value(outsider_login_res.headers, "sb_csrf")

  let req =
    simulate.request(
      http.Get,
      "/api/v1/projects/" <> int_to_string(project_id) <> "/tasks",
    )
    |> request.set_cookie("sb_session", outsider_session)
    |> request.set_cookie("sb_csrf", outsider_csrf)

  let res = handler(req)
  res.status |> should.equal(403)
  string.contains(simulate.read_body(res), "FORBIDDEN") |> should.be_true
}

pub fn task_get_requires_membership_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  create_project(handler, session, csrf, "Core")
  let project_id =
    single_int(db, "select id from projects where name = 'Core'", [])

  create_task_type(handler, session, csrf, project_id, "Bug", "bug-ant", 0)
  let type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Bug'",
      [pog.int(project_id)],
    )

  let task_id =
    create_task(handler, session, csrf, project_id, "Secret", "", 3, type_id)

  create_member_user(handler, db, "outsider@example.com", "inv_out")
  let outsider_login_res =
    login_as(handler, "outsider@example.com", "passwordpassword")
  let outsider_session =
    find_cookie_value(outsider_login_res.headers, "sb_session")
  let outsider_csrf = find_cookie_value(outsider_login_res.headers, "sb_csrf")

  let req =
    simulate.request(http.Get, "/api/v1/tasks/" <> int_to_string(task_id))
    |> request.set_cookie("sb_session", outsider_session)
    |> request.set_cookie("sb_csrf", outsider_csrf)

  let res = handler(req)
  res.status |> should.equal(404)
  string.contains(simulate.read_body(res), "NOT_FOUND") |> should.be_true
}

pub fn tasks_list_filters_status_type_and_invalid_values_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  create_project(handler, session, csrf, "Core")
  let project_id =
    single_int(db, "select id from projects where name = 'Core'", [])

  create_task_type(handler, session, csrf, project_id, "Bug", "bug-ant", 0)
  create_task_type(handler, session, csrf, project_id, "Chore", "bolt", 0)

  let bug_type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Bug'",
      [pog.int(project_id)],
    )

  let chore_type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Chore'",
      [pog.int(project_id)],
    )

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

  let completed_id =
    create_task(
      handler,
      session,
      csrf,
      project_id,
      "Completed",
      "",
      3,
      bug_type_id,
    )

  claim_task(handler, session, csrf, claimed_id, 1) |> should.equal(200)
  claim_task(handler, session, csrf, completed_id, 1) |> should.equal(200)
  complete_task(handler, session, csrf, completed_id, 2) |> should.equal(200)

  let available_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/projects/"
          <> int_to_string(project_id)
          <> "/tasks?status=available",
      )
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf),
    )

  available_res.status |> should.equal(200)
  decode_task_titles(simulate.read_body(available_res))
  |> should.equal(["Available"])

  let claimed_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/projects/"
          <> int_to_string(project_id)
          <> "/tasks?status=claimed",
      )
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf),
    )

  claimed_res.status |> should.equal(200)
  decode_task_titles(simulate.read_body(claimed_res))
  |> should.equal(["Claimed"])

  let completed_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/projects/"
          <> int_to_string(project_id)
          <> "/tasks?status=completed",
      )
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf),
    )

  completed_res.status |> should.equal(200)
  decode_task_titles(simulate.read_body(completed_res))
  |> should.equal(["Completed"])

  let type_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/projects/"
          <> int_to_string(project_id)
          <> "/tasks?type_id="
          <> int_to_string(bug_type_id),
      )
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf),
    )

  type_res.status |> should.equal(200)
  decode_task_titles(simulate.read_body(type_res))
  |> should.equal(["Completed", "Available"])

  let invalid_status_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/projects/" <> int_to_string(project_id) <> "/tasks?status=nope",
      )
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf),
    )

  invalid_status_res.status |> should.equal(422)
  string.contains(simulate.read_body(invalid_status_res), "VALIDATION_ERROR")
  |> should.be_true

  let invalid_type_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/projects/" <> int_to_string(project_id) <> "/tasks?type_id=abc",
      )
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf),
    )

  invalid_type_res.status |> should.equal(422)
  string.contains(simulate.read_body(invalid_type_res), "VALIDATION_ERROR")
  |> should.be_true

  let invalid_cap_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/projects/"
          <> int_to_string(project_id)
          <> "/tasks?capability_id=abc",
      )
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf),
    )

  invalid_cap_res.status |> should.equal(422)
  string.contains(simulate.read_body(invalid_cap_res), "VALIDATION_ERROR")
  |> should.be_true

  let _ = available_id
}

pub fn patch_ignores_claimed_by_and_non_claimer_forbidden_test() {
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
    "Bug",
    "bug-ant",
    0,
  )
  let type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Bug'",
      [pog.int(project_id)],
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

  let member_login_res =
    login_as(handler, "member@example.com", "passwordpassword")
  let member_session = find_cookie_value(member_login_res.headers, "sb_session")
  let member_csrf = find_cookie_value(member_login_res.headers, "sb_csrf")

  let other_login_res =
    login_as(handler, "other@example.com", "passwordpassword")
  let other_session = find_cookie_value(other_login_res.headers, "sb_session")
  let other_csrf = find_cookie_value(other_login_res.headers, "sb_csrf")

  let task_id =
    create_task(
      handler,
      member_session,
      member_csrf,
      project_id,
      "Core",
      "",
      3,
      type_id,
    )

  claim_task(handler, member_session, member_csrf, task_id, 1)
  |> should.equal(200)

  let patch_ok_res =
    handler(
      simulate.request(http.Patch, "/api/v1/tasks/" <> int_to_string(task_id))
      |> request.set_cookie("sb_session", member_session)
      |> request.set_cookie("sb_csrf", member_csrf)
      |> request.set_header("X-CSRF", member_csrf)
      |> simulate.json_body(
        json.object([
          #("version", json.int(2)),
          #("title", json.string("New")),
          #("claimed_by", json.int(other_id)),
        ]),
      ),
    )

  patch_ok_res.status |> should.equal(200)

  task_claimed_by(db, task_id) |> should.equal(member_id)

  let version = task_version(db, task_id)

  let patch_other_res =
    handler(
      simulate.request(http.Patch, "/api/v1/tasks/" <> int_to_string(task_id))
      |> request.set_cookie("sb_session", other_session)
      |> request.set_cookie("sb_csrf", other_csrf)
      |> request.set_header("X-CSRF", other_csrf)
      |> simulate.json_body(
        json.object([
          #("version", json.int(version)),
          #("title", json.string("Other")),
        ]),
      ),
    )

  patch_other_res.status |> should.equal(403)

  let release_other_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int_to_string(task_id) <> "/release",
      )
      |> request.set_cookie("sb_session", other_session)
      |> request.set_cookie("sb_csrf", other_csrf)
      |> request.set_header("X-CSRF", other_csrf)
      |> simulate.json_body(json.object([#("version", json.int(version))])),
    )

  release_other_res.status |> should.equal(403)

  let complete_other_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int_to_string(task_id) <> "/complete",
      )
      |> request.set_cookie("sb_session", other_session)
      |> request.set_cookie("sb_csrf", other_csrf)
      |> request.set_header("X-CSRF", other_csrf)
      |> simulate.json_body(json.object([#("version", json.int(version))])),
    )

  complete_other_res.status |> should.equal(403)
}

pub fn me_active_task_start_pause_and_persist_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  create_project(handler, session, csrf, "Core")
  let project_id =
    single_int(db, "select id from projects where name = 'Core'", [])

  create_task_type(handler, session, csrf, project_id, "Bug", "bug-ant", 0)
  let type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Bug'",
      [pog.int(project_id)],
    )

  let task_id =
    create_task(handler, session, csrf, project_id, "Core", "", 3, type_id)

  claim_task(handler, session, csrf, task_id, 1) |> should.equal(200)

  let start_body =
    simulate.read_body(start_active_task(handler, session, csrf, task_id))

  decode_active_task_id(start_body) |> should.equal(option.Some(task_id))
  is_iso8601_utc(decode_as_of(start_body)) |> should.equal(True)

  let get_res = get_active_task(handler, session, csrf)
  get_res.status |> should.equal(200)
  decode_active_task_id(simulate.read_body(get_res))
  |> should.equal(option.Some(task_id))

  let pause_res = pause_active_task(handler, session, csrf)
  pause_res.status |> should.equal(200)
  decode_active_task_id(simulate.read_body(pause_res))
  |> should.equal(option.None)

  let get_after_pause = get_active_task(handler, session, csrf)
  get_after_pause.status |> should.equal(200)
  decode_active_task_id(simulate.read_body(get_after_pause))
  |> should.equal(option.None)
}

pub fn me_active_task_replaces_previous_on_start_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  create_project(handler, session, csrf, "Core")
  let project_id =
    single_int(db, "select id from projects where name = 'Core'", [])

  create_task_type(handler, session, csrf, project_id, "Bug", "bug-ant", 0)
  let type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Bug'",
      [pog.int(project_id)],
    )

  let t1 = create_task(handler, session, csrf, project_id, "T1", "", 3, type_id)
  let t2 = create_task(handler, session, csrf, project_id, "T2", "", 3, type_id)

  claim_task(handler, session, csrf, t1, 1) |> should.equal(200)
  claim_task(handler, session, csrf, t2, 1) |> should.equal(200)

  start_active_task(handler, session, csrf, t1).status |> should.equal(200)
  let res = start_active_task(handler, session, csrf, t2)
  res.status |> should.equal(200)

  decode_active_task_id(simulate.read_body(res))
  |> should.equal(option.Some(t2))
}

pub fn me_active_task_start_returns_409_when_not_claimed_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  create_project(handler, session, csrf, "Core")
  let project_id =
    single_int(db, "select id from projects where name = 'Core'", [])

  create_task_type(handler, session, csrf, project_id, "Bug", "bug-ant", 0)
  let type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Bug'",
      [pog.int(project_id)],
    )

  let task_id =
    create_task(handler, session, csrf, project_id, "Core", "", 3, type_id)

  let res = start_active_task(handler, session, csrf, task_id)
  res.status |> should.equal(409)
  string.contains(simulate.read_body(res), "CONFLICT_CLAIMED")
  |> should.equal(True)
}

pub fn me_active_task_clears_before_release_and_complete_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  create_project(handler, session, csrf, "Core")
  let project_id =
    single_int(db, "select id from projects where name = 'Core'", [])

  create_task_type(handler, session, csrf, project_id, "Bug", "bug-ant", 0)
  let type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Bug'",
      [pog.int(project_id)],
    )

  let task_id =
    create_task(handler, session, csrf, project_id, "Core", "", 3, type_id)

  claim_task(handler, session, csrf, task_id, 1) |> should.equal(200)
  start_active_task(handler, session, csrf, task_id).status |> should.equal(200)

  let version = task_version(db, task_id)

  let release_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int_to_string(task_id) <> "/release",
      )
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf)
      |> request.set_header("X-CSRF", csrf)
      |> simulate.json_body(json.object([#("version", json.int(version))])),
    )

  release_res.status |> should.equal(200)

  let active_after_release = get_active_task(handler, session, csrf)
  decode_active_task_id(simulate.read_body(active_after_release))
  |> should.equal(option.None)

  // Re-claim + start, then complete.
  let version = task_version(db, task_id)
  claim_task(handler, session, csrf, task_id, version) |> should.equal(200)
  start_active_task(handler, session, csrf, task_id).status |> should.equal(200)

  let version = task_version(db, task_id)
  complete_task(handler, session, csrf, task_id, version) |> should.equal(200)

  let active_after_complete = get_active_task(handler, session, csrf)
  decode_active_task_id(simulate.read_body(active_after_complete))
  |> should.equal(option.None)
}

fn get_active_task(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
) -> wisp.Response {
  handler(
    simulate.request(http.Get, "/api/v1/me/active-task")
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf),
  )
}

fn start_active_task(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  task_id: Int,
) -> wisp.Response {
  handler(
    simulate.request(http.Post, "/api/v1/me/active-task/start")
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> request.set_header("X-CSRF", csrf)
    |> simulate.json_body(json.object([#("task_id", json.int(task_id))])),
  )
}

fn pause_active_task(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
) -> wisp.Response {
  handler(
    simulate.request(http.Post, "/api/v1/me/active-task/pause")
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> request.set_header("X-CSRF", csrf),
  )
}

fn decode_active_task(body: String) -> #(option.Option(Int), String) {
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let active_decoder = decode.field("task_id", decode.int, decode.success)

  let data_decoder = {
    use active_task <- decode.field(
      "active_task",
      decode.optional(active_decoder),
    )
    use as_of <- decode.field("as_of", decode.string)
    decode.success(#(active_task, as_of))
  }

  let response_decoder = decode.field("data", data_decoder, decode.success)

  let assert Ok(payload) = decode.run(dynamic, response_decoder)
  payload
}

fn decode_active_task_id(body: String) -> option.Option(Int) {
  let #(active_task, _) = decode_active_task(body)
  active_task
}

fn decode_as_of(body: String) -> String {
  let #(_, as_of) = decode_active_task(body)
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

fn claim_task(
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
        "/api/v1/tasks/" <> int_to_string(task_id) <> "/claim",
      )
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf)
      |> request.set_header("X-CSRF", csrf)
      |> simulate.json_body(json.object([#("version", json.int(version))])),
    )

  res.status
}

fn complete_task(
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
        "/api/v1/tasks/" <> int_to_string(task_id) <> "/complete",
      )
      |> request.set_cookie("sb_session", session)
      |> request.set_cookie("sb_csrf", csrf)
      |> request.set_header("X-CSRF", csrf)
      |> simulate.json_body(json.object([#("version", json.int(version))])),
    )

  res.status
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
  capability_id: Int,
) {
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
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> request.set_header("X-CSRF", csrf)
    |> simulate.json_body(body)

  let res = handler(req)
  res.status |> should.equal(200)
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
  let req =
    simulate.request(
      http.Post,
      "/api/v1/projects/" <> int_to_string(project_id) <> "/tasks",
    )
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> request.set_header("X-CSRF", csrf)
    |> simulate.json_body(
      json.object([
        #("title", json.string(title)),
        #("description", json.string(description)),
        #("priority", json.int(priority)),
        #("type_id", json.int(type_id)),
      ]),
    )

  let res = handler(req)
  res.status |> should.equal(200)

  let body = simulate.read_body(res)
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let task_decoder = {
    use id <- decode.field("id", decode.int)
    decode.success(id)
  }

  let data_decoder = {
    use task <- decode.field("task", task_decoder)
    decode.success(task)
  }

  let response_decoder = {
    use id <- decode.field("data", data_decoder)
    decode.success(id)
  }

  let assert Ok(id) = decode.run(dynamic, response_decoder)
  id
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
  res.status |> should.equal(200)
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

fn insert_capability(db: pog.Connection, org_id: Int, name: String) -> Int {
  let assert Ok(pog.Returned(rows: [id, ..], ..)) =
    pog.query(
      "insert into capabilities (org_id, name) values ($1, $2) returning id",
    )
    |> pog.parameter(pog.int(org_id))
    |> pog.parameter(pog.text(name))
    |> pog.returning({
      use id <- decode.field(0, decode.int)
      decode.success(id)
    })
    |> pog.execute(db)

  id
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
  res.status |> should.equal(200)
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
  getenv_charlist(charlist.from_string(key), charlist.from_string(default))
  |> charlist.to_string
}

@external(erlang, "os", "getenv")
fn getenv_charlist(
  key: charlist.Charlist,
  default: charlist.Charlist,
) -> charlist.Charlist
