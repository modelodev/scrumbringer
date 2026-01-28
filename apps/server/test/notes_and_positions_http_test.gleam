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

// Justification: large function kept intact to preserve cohesive logic.
pub fn task_notes_create_does_not_require_claim_and_task_patch_still_requires_claim_test() {
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
  )
  let type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Bug'",
      [pog.int(project_id)],
    )

  create_member_user(handler, db, "member1@example.com", "inv_member1")
  create_member_user(handler, db, "member2@example.com", "inv_member2")

  let member1_id =
    single_int(
      db,
      "select id from users where email = 'member1@example.com'",
      [],
    )
  let member2_id =
    single_int(
      db,
      "select id from users where email = 'member2@example.com'",
      [],
    )

  add_member(handler, admin_session, admin_csrf, project_id, member1_id)
  add_member(handler, admin_session, admin_csrf, project_id, member2_id)

  let member1_login_res =
    login_as(handler, "member1@example.com", "passwordpassword")
  let member1_session =
    find_cookie_value(member1_login_res.headers, "sb_session")
  let member1_csrf = find_cookie_value(member1_login_res.headers, "sb_csrf")

  let member2_login_res =
    login_as(handler, "member2@example.com", "passwordpassword")
  let member2_session =
    find_cookie_value(member2_login_res.headers, "sb_session")
  let member2_csrf = find_cookie_value(member2_login_res.headers, "sb_csrf")

  let task_id =
    create_task(
      handler,
      member1_session,
      member1_csrf,
      project_id,
      "Core",
      "",
      3,
      type_id,
    )

  let note_req =
    simulate.request(
      http.Post,
      "/api/v1/tasks/" <> int_to_string(task_id) <> "/notes",
    )
    |> request.set_cookie("sb_session", member2_session)
    |> request.set_cookie("sb_csrf", member2_csrf)
    |> request.set_header("X-CSRF", member2_csrf)
    |> simulate.json_body(
      json.object([#("content", json.string("Investigating"))]),
    )

  let note_res = handler(note_req)
  note_res.status |> should.equal(200)
  decode_note_content(simulate.read_body(note_res))
  |> should.equal("Investigating")

  let patch_req =
    simulate.request(http.Patch, "/api/v1/tasks/" <> int_to_string(task_id))
    |> request.set_cookie("sb_session", member2_session)
    |> request.set_cookie("sb_csrf", member2_csrf)
    |> request.set_header("X-CSRF", member2_csrf)
    |> simulate.json_body(
      json.object([
        #("version", json.int(1)),
        #("title", json.string("New")),
      ]),
    )

  let patch_res = handler(patch_req)
  patch_res.status |> should.equal(403)

  let _ = member1_csrf
}

// Justification: large function kept intact to preserve cohesive logic.
pub fn task_notes_list_requires_task_membership_test() {
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
  )
  let type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Bug'",
      [pog.int(project_id)],
    )

  create_member_user(handler, db, "member@example.com", "inv_member")
  create_member_user(handler, db, "outsider@example.com", "inv_out")

  let member_id =
    single_int(
      db,
      "select id from users where email = 'member@example.com'",
      [],
    )

  add_member(handler, admin_session, admin_csrf, project_id, member_id)

  let member_login_res =
    login_as(handler, "member@example.com", "passwordpassword")
  let member_session = find_cookie_value(member_login_res.headers, "sb_session")
  let member_csrf = find_cookie_value(member_login_res.headers, "sb_csrf")

  let outsider_login_res =
    login_as(handler, "outsider@example.com", "passwordpassword")
  let outsider_session =
    find_cookie_value(outsider_login_res.headers, "sb_session")
  let outsider_csrf = find_cookie_value(outsider_login_res.headers, "sb_csrf")

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

  let _ =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int_to_string(task_id) <> "/notes",
      )
      |> request.set_cookie("sb_session", member_session)
      |> request.set_cookie("sb_csrf", member_csrf)
      |> request.set_header("X-CSRF", member_csrf)
      |> simulate.json_body(json.object([#("content", json.string("One"))])),
    )

  let member_list_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/tasks/" <> int_to_string(task_id) <> "/notes",
      )
      |> request.set_cookie("sb_session", member_session)
      |> request.set_cookie("sb_csrf", member_csrf),
    )

  member_list_res.status |> should.equal(200)
  decode_note_list_contents(simulate.read_body(member_list_res))
  |> should.equal(["One"])

  let outsider_req =
    simulate.request(
      http.Get,
      "/api/v1/tasks/" <> int_to_string(task_id) <> "/notes",
    )
    |> request.set_cookie("sb_session", outsider_session)
    |> request.set_cookie("sb_csrf", outsider_csrf)

  let outsider_res = handler(outsider_req)
  outsider_res.status |> should.equal(404)
  string.contains(simulate.read_body(outsider_res), "NOT_FOUND")
  |> should.be_true
}

// Justification: large function kept intact to preserve cohesive logic.
pub fn task_notes_are_append_only_and_no_edit_delete_routes_exist_test() {
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
  )
  let type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Bug'",
      [pog.int(project_id)],
    )

  create_member_user(handler, db, "member@example.com", "inv_member")

  let member_id =
    single_int(
      db,
      "select id from users where email = 'member@example.com'",
      [],
    )

  add_member(handler, admin_session, admin_csrf, project_id, member_id)

  let member_login_res =
    login_as(handler, "member@example.com", "passwordpassword")
  let member_session = find_cookie_value(member_login_res.headers, "sb_session")
  let member_csrf = find_cookie_value(member_login_res.headers, "sb_csrf")

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

  let delete_collection_res =
    handler(
      simulate.request(
        http.Delete,
        "/api/v1/tasks/" <> int_to_string(task_id) <> "/notes",
      )
      |> request.set_cookie("sb_session", member_session)
      |> request.set_cookie("sb_csrf", member_csrf),
    )

  delete_collection_res.status |> should.equal(405)

  let patch_collection_res =
    handler(
      simulate.request(
        http.Patch,
        "/api/v1/tasks/" <> int_to_string(task_id) <> "/notes",
      )
      |> request.set_cookie("sb_session", member_session)
      |> request.set_cookie("sb_csrf", member_csrf)
      |> request.set_header("X-CSRF", member_csrf),
    )

  patch_collection_res.status |> should.equal(405)

  let delete_item_res =
    handler(
      simulate.request(
        http.Delete,
        "/api/v1/tasks/" <> int_to_string(task_id) <> "/notes/1",
      )
      |> request.set_cookie("sb_session", member_session)
      |> request.set_cookie("sb_csrf", member_csrf),
    )

  delete_item_res.status |> should.equal(404)

  let patch_item_res =
    handler(
      simulate.request(
        http.Patch,
        "/api/v1/tasks/" <> int_to_string(task_id) <> "/notes/1",
      )
      |> request.set_cookie("sb_session", member_session)
      |> request.set_cookie("sb_csrf", member_csrf)
      |> request.set_header("X-CSRF", member_csrf),
    )

  patch_item_res.status |> should.equal(404)
}

pub fn task_notes_create_requires_csrf_test() {
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
  )
  let type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Bug'",
      [pog.int(project_id)],
    )

  create_member_user(handler, db, "member@example.com", "inv_member")

  let member_id =
    single_int(
      db,
      "select id from users where email = 'member@example.com'",
      [],
    )

  add_member(handler, admin_session, admin_csrf, project_id, member_id)

  let member_login_res =
    login_as(handler, "member@example.com", "passwordpassword")
  let member_session = find_cookie_value(member_login_res.headers, "sb_session")
  let member_csrf = find_cookie_value(member_login_res.headers, "sb_csrf")

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

  let note_req =
    simulate.request(
      http.Post,
      "/api/v1/tasks/" <> int_to_string(task_id) <> "/notes",
    )
    |> request.set_cookie("sb_session", member_session)
    |> request.set_cookie("sb_csrf", member_csrf)
    |> simulate.json_body(json.object([#("content", json.string("One"))]))

  let note_res = handler(note_req)
  note_res.status |> should.equal(403)
}

// Justification: large function kept intact to preserve cohesive logic.
pub fn card_notes_list_requires_card_membership_test() {
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
  create_member_user(handler, db, "outsider@example.com", "inv_out")

  let member_id =
    single_int(
      db,
      "select id from users where email = 'member@example.com'",
      [],
    )

  add_member(handler, admin_session, admin_csrf, project_id, member_id)

  let member_login_res =
    login_as(handler, "member@example.com", "passwordpassword")
  let member_session = find_cookie_value(member_login_res.headers, "sb_session")
  let member_csrf = find_cookie_value(member_login_res.headers, "sb_csrf")

  let outsider_login_res =
    login_as(handler, "outsider@example.com", "passwordpassword")
  let outsider_session =
    find_cookie_value(outsider_login_res.headers, "sb_session")
  let outsider_csrf = find_cookie_value(outsider_login_res.headers, "sb_csrf")

  let card_id =
    create_card(handler, admin_session, admin_csrf, project_id, "Card")

  let _ =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/cards/" <> int_to_string(card_id) <> "/notes",
      )
      |> request.set_cookie("sb_session", member_session)
      |> request.set_cookie("sb_csrf", member_csrf)
      |> request.set_header("X-CSRF", member_csrf)
      |> simulate.json_body(json.object([#("content", json.string("One"))])),
    )

  let member_list_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/cards/" <> int_to_string(card_id) <> "/notes",
      )
      |> request.set_cookie("sb_session", member_session)
      |> request.set_cookie("sb_csrf", member_csrf),
    )

  member_list_res.status |> should.equal(200)
  decode_note_list_contents(simulate.read_body(member_list_res))
  |> should.equal(["One"])

  let outsider_req =
    simulate.request(
      http.Get,
      "/api/v1/cards/" <> int_to_string(card_id) <> "/notes",
    )
    |> request.set_cookie("sb_session", outsider_session)
    |> request.set_cookie("sb_csrf", outsider_csrf)

  let outsider_res = handler(outsider_req)
  outsider_res.status |> should.equal(404)
  string.contains(simulate.read_body(outsider_res), "NOT_FOUND")
  |> should.be_true
}

// Justification: large function kept intact to preserve cohesive logic.
pub fn card_notes_create_and_delete_permissions_test() {
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

  create_member_user(handler, db, "member1@example.com", "inv_member1")
  create_member_user(handler, db, "member2@example.com", "inv_member2")

  let member1_id =
    single_int(
      db,
      "select id from users where email = 'member1@example.com'",
      [],
    )
  let member2_id =
    single_int(
      db,
      "select id from users where email = 'member2@example.com'",
      [],
    )

  add_member(handler, admin_session, admin_csrf, project_id, member1_id)
  add_member(handler, admin_session, admin_csrf, project_id, member2_id)

  let member1_login_res =
    login_as(handler, "member1@example.com", "passwordpassword")
  let member1_session =
    find_cookie_value(member1_login_res.headers, "sb_session")
  let member1_csrf = find_cookie_value(member1_login_res.headers, "sb_csrf")

  let member2_login_res =
    login_as(handler, "member2@example.com", "passwordpassword")
  let member2_session =
    find_cookie_value(member2_login_res.headers, "sb_session")
  let member2_csrf = find_cookie_value(member2_login_res.headers, "sb_csrf")

  let card_id =
    create_card(handler, admin_session, admin_csrf, project_id, "Card")

  let note_req =
    simulate.request(
      http.Post,
      "/api/v1/cards/" <> int_to_string(card_id) <> "/notes",
    )
    |> request.set_cookie("sb_session", member1_session)
    |> request.set_cookie("sb_csrf", member1_csrf)
    |> request.set_header("X-CSRF", member1_csrf)
    |> simulate.json_body(json.object([#("content", json.string("Note"))]))

  let note_res = handler(note_req)
  note_res.status |> should.equal(200)
  let note_id = decode_note_id(simulate.read_body(note_res))

  let delete_forbidden =
    simulate.request(
      http.Delete,
      "/api/v1/cards/"
        <> int_to_string(card_id)
        <> "/notes/"
        <> int_to_string(note_id),
    )
    |> request.set_cookie("sb_session", member2_session)
    |> request.set_cookie("sb_csrf", member2_csrf)
    |> request.set_header("X-CSRF", member2_csrf)

  handler(delete_forbidden).status |> should.equal(403)

  let delete_author =
    simulate.request(
      http.Delete,
      "/api/v1/cards/"
        <> int_to_string(card_id)
        <> "/notes/"
        <> int_to_string(note_id),
    )
    |> request.set_cookie("sb_session", member1_session)
    |> request.set_cookie("sb_csrf", member1_csrf)
    |> request.set_header("X-CSRF", member1_csrf)

  handler(delete_author).status |> should.equal(204)

  let note_res_2 = handler(note_req)
  note_res_2.status |> should.equal(200)
  let note_id_2 = decode_note_id(simulate.read_body(note_res_2))

  let delete_admin =
    simulate.request(
      http.Delete,
      "/api/v1/cards/"
        <> int_to_string(card_id)
        <> "/notes/"
        <> int_to_string(note_id_2),
    )
    |> request.set_cookie("sb_session", admin_session)
    |> request.set_cookie("sb_csrf", admin_csrf)
    |> request.set_header("X-CSRF", admin_csrf)

  handler(delete_admin).status |> should.equal(204)
}

pub fn card_notes_create_requires_csrf_test() {
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

  add_member(handler, admin_session, admin_csrf, project_id, member_id)

  let member_login_res =
    login_as(handler, "member@example.com", "passwordpassword")
  let member_session = find_cookie_value(member_login_res.headers, "sb_session")
  let member_csrf = find_cookie_value(member_login_res.headers, "sb_csrf")

  let card_id =
    create_card(handler, admin_session, admin_csrf, project_id, "Card")

  let note_req =
    simulate.request(
      http.Post,
      "/api/v1/cards/" <> int_to_string(card_id) <> "/notes",
    )
    |> request.set_cookie("sb_session", member_session)
    |> request.set_cookie("sb_csrf", member_csrf)
    |> simulate.json_body(json.object([#("content", json.string("One"))]))

  let note_res = handler(note_req)
  note_res.status |> should.equal(403)
}

// Justification: large function kept intact to preserve cohesive logic.
pub fn card_notes_indicator_updates_after_view_test() {
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

  add_member(handler, admin_session, admin_csrf, project_id, member_id)

  let member_login_res =
    login_as(handler, "member@example.com", "passwordpassword")
  let member_session = find_cookie_value(member_login_res.headers, "sb_session")
  let member_csrf = find_cookie_value(member_login_res.headers, "sb_csrf")

  let card_id =
    create_card(handler, admin_session, admin_csrf, project_id, "Card")

  let note_req =
    simulate.request(
      http.Post,
      "/api/v1/cards/" <> int_to_string(card_id) <> "/notes",
    )
    |> request.set_cookie("sb_session", member_session)
    |> request.set_cookie("sb_csrf", member_csrf)
    |> request.set_header("X-CSRF", member_csrf)
    |> simulate.json_body(json.object([#("content", json.string("Note"))]))

  handler(note_req).status |> should.equal(200)

  let list_req =
    simulate.request(
      http.Get,
      "/api/v1/projects/" <> int_to_string(project_id) <> "/cards",
    )
    |> request.set_cookie("sb_session", member_session)
    |> request.set_cookie("sb_csrf", member_csrf)

  let list_res = handler(list_req)
  list_res.status |> should.equal(200)
  decode_card_has_new_notes(simulate.read_body(list_res), card_id)
  |> should.equal(True)

  let view_req =
    simulate.request(http.Put, "/api/v1/views/cards/" <> int_to_string(card_id))
    |> request.set_cookie("sb_session", member_session)
    |> request.set_cookie("sb_csrf", member_csrf)
    |> request.set_header("X-CSRF", member_csrf)

  handler(view_req).status |> should.equal(204)

  let list_res_2 = handler(list_req)
  list_res_2.status |> should.equal(200)
  decode_card_has_new_notes(simulate.read_body(list_res_2), card_id)
  |> should.equal(False)
}

pub fn task_positions_upsert_requires_csrf_test() {
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
  )
  let type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Bug'",
      [pog.int(project_id)],
    )

  create_member_user(handler, db, "member@example.com", "inv_member")

  let member_id =
    single_int(
      db,
      "select id from users where email = 'member@example.com'",
      [],
    )

  add_member(handler, admin_session, admin_csrf, project_id, member_id)

  let member_login_res =
    login_as(handler, "member@example.com", "passwordpassword")
  let member_session = find_cookie_value(member_login_res.headers, "sb_session")
  let member_csrf = find_cookie_value(member_login_res.headers, "sb_csrf")

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

  let put_req =
    simulate.request(
      http.Put,
      "/api/v1/me/task-positions/" <> int_to_string(task_id),
    )
    |> request.set_cookie("sb_session", member_session)
    |> request.set_cookie("sb_csrf", member_csrf)
    |> simulate.json_body(
      json.object([#("x", json.int(1)), #("y", json.int(2))]),
    )

  let put_res = handler(put_req)
  put_res.status |> should.equal(403)
}

// Justification: large function kept intact to preserve cohesive logic.
pub fn task_positions_are_per_user_and_can_be_filtered_by_project_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_login_res =
    login_as(handler, "admin@example.com", "passwordpassword")
  let admin_session = find_cookie_value(admin_login_res.headers, "sb_session")
  let admin_csrf = find_cookie_value(admin_login_res.headers, "sb_csrf")

  create_project(handler, admin_session, admin_csrf, "Core")
  create_project(handler, admin_session, admin_csrf, "Other")

  let core_id =
    single_int(db, "select id from projects where name = 'Core'", [])
  let other_id =
    single_int(db, "select id from projects where name = 'Other'", [])

  create_task_type(
    handler,
    admin_session,
    admin_csrf,
    core_id,
    "Bug",
    "bug-ant",
  )
  create_task_type(
    handler,
    admin_session,
    admin_csrf,
    other_id,
    "Bug",
    "bug-ant",
  )

  let core_type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Bug'",
      [pog.int(core_id)],
    )
  let other_type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Bug'",
      [pog.int(other_id)],
    )

  create_member_user(handler, db, "member1@example.com", "inv_member1")
  create_member_user(handler, db, "member2@example.com", "inv_member2")

  let member1_id =
    single_int(
      db,
      "select id from users where email = 'member1@example.com'",
      [],
    )
  let member2_id =
    single_int(
      db,
      "select id from users where email = 'member2@example.com'",
      [],
    )

  add_member(handler, admin_session, admin_csrf, core_id, member1_id)
  add_member(handler, admin_session, admin_csrf, core_id, member2_id)
  add_member(handler, admin_session, admin_csrf, other_id, member1_id)
  add_member(handler, admin_session, admin_csrf, other_id, member2_id)

  let member1_login_res =
    login_as(handler, "member1@example.com", "passwordpassword")
  let member1_session =
    find_cookie_value(member1_login_res.headers, "sb_session")
  let member1_csrf = find_cookie_value(member1_login_res.headers, "sb_csrf")

  let member2_login_res =
    login_as(handler, "member2@example.com", "passwordpassword")
  let member2_session =
    find_cookie_value(member2_login_res.headers, "sb_session")
  let member2_csrf = find_cookie_value(member2_login_res.headers, "sb_csrf")

  let core_task_id =
    create_task(
      handler,
      member1_session,
      member1_csrf,
      core_id,
      "Core",
      "",
      3,
      core_type_id,
    )
  let other_task_id =
    create_task(
      handler,
      member1_session,
      member1_csrf,
      other_id,
      "Other",
      "",
      3,
      other_type_id,
    )

  upsert_position(handler, member1_session, member1_csrf, core_task_id, 10, 20)
  |> should.equal(200)

  upsert_position(handler, member1_session, member1_csrf, other_task_id, 1, 2)
  |> should.equal(200)

  upsert_position(handler, member2_session, member2_csrf, core_task_id, 30, 40)
  |> should.equal(200)

  let member1_all_res =
    handler(
      simulate.request(http.Get, "/api/v1/me/task-positions")
      |> request.set_cookie("sb_session", member1_session)
      |> request.set_cookie("sb_csrf", member1_csrf),
    )

  member1_all_res.status |> should.equal(200)

  decode_positions_xy_by_task(simulate.read_body(member1_all_res), core_task_id)
  |> should.equal(#(10, 20))

  let member1_core_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/me/task-positions?project_id=" <> int_to_string(core_id),
      )
      |> request.set_cookie("sb_session", member1_session)
      |> request.set_cookie("sb_csrf", member1_csrf),
    )

  member1_core_res.status |> should.equal(200)
  decode_position_task_ids(simulate.read_body(member1_core_res))
  |> should.equal([core_task_id])

  let member2_all_res =
    handler(
      simulate.request(http.Get, "/api/v1/me/task-positions")
      |> request.set_cookie("sb_session", member2_session)
      |> request.set_cookie("sb_csrf", member2_csrf),
    )

  member2_all_res.status |> should.equal(200)
  decode_positions_xy_by_task(simulate.read_body(member2_all_res), core_task_id)
  |> should.equal(#(30, 40))
}

pub fn task_positions_reject_non_member_task_and_project_filter_test() {
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
  )
  let type_id =
    single_int(
      db,
      "select id from task_types where project_id = $1 and name = 'Bug'",
      [pog.int(project_id)],
    )

  create_member_user(handler, db, "member@example.com", "inv_member")
  create_member_user(handler, db, "outsider@example.com", "inv_out")

  let member_id =
    single_int(
      db,
      "select id from users where email = 'member@example.com'",
      [],
    )

  add_member(handler, admin_session, admin_csrf, project_id, member_id)

  let member_login_res =
    login_as(handler, "member@example.com", "passwordpassword")
  let member_session = find_cookie_value(member_login_res.headers, "sb_session")
  let member_csrf = find_cookie_value(member_login_res.headers, "sb_csrf")

  let outsider_login_res =
    login_as(handler, "outsider@example.com", "passwordpassword")
  let outsider_session =
    find_cookie_value(outsider_login_res.headers, "sb_session")
  let outsider_csrf = find_cookie_value(outsider_login_res.headers, "sb_csrf")

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

  let put_req =
    simulate.request(
      http.Put,
      "/api/v1/me/task-positions/" <> int_to_string(task_id),
    )
    |> request.set_cookie("sb_session", outsider_session)
    |> request.set_cookie("sb_csrf", outsider_csrf)
    |> request.set_header("X-CSRF", outsider_csrf)
    |> simulate.json_body(
      json.object([#("x", json.int(1)), #("y", json.int(2))]),
    )

  let put_res = handler(put_req)
  put_res.status |> should.equal(404)

  let filtered_req =
    simulate.request(
      http.Get,
      "/api/v1/me/task-positions?project_id=" <> int_to_string(project_id),
    )
    |> request.set_cookie("sb_session", outsider_session)
    |> request.set_cookie("sb_csrf", outsider_csrf)

  let filtered_res = handler(filtered_req)
  filtered_res.status |> should.equal(403)
}

fn decode_note_content(body: String) -> String {
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let note_decoder = {
    use content <- decode.field("content", decode.string)
    decode.success(content)
  }

  let data_decoder = {
    use note <- decode.field("note", note_decoder)
    decode.success(note)
  }

  let response_decoder = {
    use note <- decode.field("data", data_decoder)
    decode.success(note)
  }

  let assert Ok(content) = decode.run(dynamic, response_decoder)
  content
}

fn decode_note_list_contents(body: String) -> List(String) {
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let note_decoder = {
    use content <- decode.field("content", decode.string)
    decode.success(content)
  }

  let data_decoder = {
    use notes <- decode.field("notes", decode.list(note_decoder))
    decode.success(notes)
  }

  let response_decoder = {
    use notes <- decode.field("data", data_decoder)
    decode.success(notes)
  }

  let assert Ok(notes) = decode.run(dynamic, response_decoder)
  notes
}

fn decode_note_id(body: String) -> Int {
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let note_decoder = {
    use id <- decode.field("id", decode.int)
    decode.success(id)
  }

  let data_decoder = {
    use note <- decode.field("note", note_decoder)
    decode.success(note)
  }

  let response_decoder = {
    use note_id <- decode.field("data", data_decoder)
    decode.success(note_id)
  }

  let assert Ok(note_id) = decode.run(dynamic, response_decoder)
  note_id
}

fn decode_card_id(body: String) -> Int {
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let card_decoder = {
    use id <- decode.field("id", decode.int)
    decode.success(id)
  }

  let data_decoder = {
    use card <- decode.field("card", card_decoder)
    decode.success(card)
  }

  let response_decoder = {
    use id <- decode.field("data", data_decoder)
    decode.success(id)
  }

  let assert Ok(id) = decode.run(dynamic, response_decoder)
  id
}

fn decode_card_has_new_notes(body: String, card_id: Int) -> Bool {
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let card_decoder = {
    use id <- decode.field("id", decode.int)
    use has_new_notes <- decode.field("has_new_notes", decode.bool)
    decode.success(#(id, has_new_notes))
  }

  let data_decoder = {
    use cards <- decode.field("cards", decode.list(card_decoder))
    decode.success(cards)
  }

  let response_decoder = {
    use cards <- decode.field("data", data_decoder)
    decode.success(cards)
  }

  let assert Ok(cards) = decode.run(dynamic, response_decoder)
  let assert Ok(#(_, has_new_notes)) =
    list.find(cards, fn(card) { card.0 == card_id })

  has_new_notes
}

fn decode_position_task_ids(body: String) -> List(Int) {
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let position_decoder = {
    use task_id <- decode.field("task_id", decode.int)
    decode.success(task_id)
  }

  let data_decoder = {
    use positions <- decode.field("positions", decode.list(position_decoder))
    decode.success(positions)
  }

  let response_decoder = {
    use positions <- decode.field("data", data_decoder)
    decode.success(positions)
  }

  let assert Ok(positions) = decode.run(dynamic, response_decoder)
  positions
}

fn decode_positions_xy_by_task(body: String, task_id: Int) -> #(Int, Int) {
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let position_decoder = {
    use tid <- decode.field("task_id", decode.int)
    use x <- decode.field("x", decode.int)
    use y <- decode.field("y", decode.int)
    decode.success(#(tid, x, y))
  }

  let data_decoder = {
    use positions <- decode.field("positions", decode.list(position_decoder))
    decode.success(positions)
  }

  let response_decoder = {
    use positions <- decode.field("data", data_decoder)
    decode.success(positions)
  }

  let assert Ok(positions) = decode.run(dynamic, response_decoder)

  let assert Ok(#(_, x, y)) =
    positions
    |> list.find(fn(p) { p.0 == task_id })

  #(x, y)
}

fn upsert_position(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  task_id: Int,
  x: Int,
  y: Int,
) -> Int {
  let req =
    simulate.request(
      http.Put,
      "/api/v1/me/task-positions/" <> int_to_string(task_id),
    )
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> request.set_header("X-CSRF", csrf)
    |> simulate.json_body(
      json.object([#("x", json.int(x)), #("y", json.int(y))]),
    )

  handler(req).status
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

  handler(req).status |> should.equal(200)
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
      json.object([#("name", json.string(name)), #("icon", json.string(icon))]),
    )

  handler(req).status |> should.equal(200)
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

fn create_card(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  project_id: Int,
  title: String,
) -> Int {
  let req =
    simulate.request(
      http.Post,
      "/api/v1/projects/" <> int_to_string(project_id) <> "/cards",
    )
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> request.set_header("X-CSRF", csrf)
    |> simulate.json_body(
      json.object([
        #("title", json.string(title)),
        #("description", json.string("")),
      ]),
    )

  let res = handler(req)
  res.status |> should.equal(200)

  decode_card_id(simulate.read_body(res))
}

fn add_member(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  project_id: Int,
  user_id: Int,
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
        #("role", json.string("member")),
      ]),
    )

  handler(req).status |> should.equal(200)
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

  handler(req).status |> should.equal(200)
}

fn login_as(
  handler: fn(wisp.Request) -> wisp.Response,
  email: String,
  password: String,
) -> wisp.Response {
  handler(
    simulate.request(http.Post, "/api/v1/auth/login")
    |> simulate.json_body(
      json.object([
        #("email", json.string(email)),
        #("password", json.string(password)),
      ]),
    ),
  )
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

fn new_test_app() -> scrumbringer_server.App {
  let database_url = require_database_url()
  let assert Ok(app) = scrumbringer_server.new_app(secret, database_url)
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
