import fixtures
import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/json
import gleam/list
import gleam/string
import gleam/time/timestamp
import gleeunit
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

type ResourceViewFixture {
  ResourceViewFixture(
    handler: fn(wisp.Request) -> wisp.Response,
    db: pog.Connection,
    session: String,
    csrf: String,
    card_id: Int,
    task_id: Int,
  )
}

pub fn main() {
  gleeunit.main()
}

// Justification: large function kept intact to preserve cohesive logic.
pub fn task_notes_create_and_available_task_patch_allow_project_member_test() {
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
    )

  let member1_id =
    create_member_user(handler, db, "member1@example.com", "inv_member1")
  let member2_id =
    create_member_user(handler, db, "member2@example.com", "inv_member2")

  add_member(handler, admin_session, admin_csrf, project_id, member1_id)
  add_member(handler, admin_session, admin_csrf, project_id, member2_id)

  let #(member1_session, member1_csrf) =
    login_session(handler, "member1@example.com")

  let #(member2_session, member2_csrf) =
    login_session(handler, "member2@example.com")

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

  let note_req =
    simulate.request(
      http.Post,
      "/api/v1/tasks/" <> int_to_string(task_id) <> "/notes",
    )
    |> fixtures.with_auth(fixture_session(member2_session, member2_csrf))
    |> simulate.json_body(
      json.object([
        #("content", json.string("Investigating")),
        #("url", json.string("https://example.com/task-note")),
      ]),
    )

  let note_res = handler(note_req)
  expect.expect_status(note_res, 200)
  decode_note_content(simulate.read_body(note_res))
  |> expect.equal("Investigating")
  decode_created_note_contract(simulate.read_body(note_res))
  |> expect.equal(#("https://example.com/task-note", False, True))
  let note_id = decode_note_id(simulate.read_body(note_res))

  let pin_by_non_author =
    simulate.request(
      http.Post,
      "/api/v1/tasks/"
        <> int_to_string(task_id)
        <> "/notes/"
        <> int_to_string(note_id)
        <> "/pin",
    )
    |> fixtures.with_auth(fixture_session(member1_session, member1_csrf))

  expect.expect_status(handler(pin_by_non_author), 403)

  let pin_by_author =
    simulate.request(
      http.Post,
      "/api/v1/tasks/"
        <> int_to_string(task_id)
        <> "/notes/"
        <> int_to_string(note_id)
        <> "/pin",
    )
    |> fixtures.with_auth(fixture_session(member2_session, member2_csrf))

  let pin_res = handler(pin_by_author)
  expect.expect_status(pin_res, 200)
  decode_note_pinned(simulate.read_body(pin_res)) |> expect.equal(True)

  let unpin_by_author =
    simulate.request(
      http.Delete,
      "/api/v1/tasks/"
        <> int_to_string(task_id)
        <> "/notes/"
        <> int_to_string(note_id)
        <> "/pin",
    )
    |> fixtures.with_auth(fixture_session(member2_session, member2_csrf))

  let unpin_res = handler(unpin_by_author)
  expect.expect_status(unpin_res, 200)
  decode_note_pinned(simulate.read_body(unpin_res)) |> expect.equal(False)

  let patch_req =
    simulate.request(http.Patch, "/api/v1/tasks/" <> int_to_string(task_id))
    |> fixtures.with_auth(fixture_session(member2_session, member2_csrf))
    |> simulate.json_body(
      json.object([
        #("version", json.int(1)),
        #("title", json.string("New")),
      ]),
    )

  let patch_res = handler(patch_req)
  expect.expect_status(patch_res, 200)

  let _ = member1_csrf
}

// Justification: large function kept intact to preserve cohesive logic.
pub fn task_notes_list_requires_task_membership_test() {
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
    )

  let member_id =
    create_member_user(handler, db, "member@example.com", "inv_member")
  create_member_user(handler, db, "outsider@example.com", "inv_out")

  add_member(handler, admin_session, admin_csrf, project_id, member_id)

  let #(member_session, member_csrf) =
    login_session(handler, "member@example.com")

  let #(outsider_session, outsider_csrf) =
    login_session(handler, "outsider@example.com")

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

  let _ =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int_to_string(task_id) <> "/notes",
      )
      |> fixtures.with_auth(fixture_session(member_session, member_csrf))
      |> simulate.json_body(json.object([#("content", json.string("One"))])),
    )

  let member_list_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/tasks/" <> int_to_string(task_id) <> "/notes",
      )
      |> fixtures.with_session_cookies(member_session, member_csrf),
    )

  expect.expect_status(member_list_res, 200)
  decode_note_list_contents(simulate.read_body(member_list_res))
  |> expect.equal(["One"])

  let outsider_req =
    simulate.request(
      http.Get,
      "/api/v1/tasks/" <> int_to_string(task_id) <> "/notes",
    )
    |> fixtures.with_session_cookies(outsider_session, outsider_csrf)

  let outsider_res = handler(outsider_req)
  expect.expect_status(outsider_res, 404)
  string.contains(simulate.read_body(outsider_res), "NOT_FOUND")
  |> expect.is_true
}

// Justification: large function kept intact to preserve cohesive logic.
pub fn task_notes_can_be_deleted_by_author_and_patch_item_is_not_allowed_test() {
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
    )

  let member_id =
    create_member_user(handler, db, "member@example.com", "inv_member")

  add_member(handler, admin_session, admin_csrf, project_id, member_id)

  let #(member_session, member_csrf) =
    login_session(handler, "member@example.com")

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

  let delete_collection_res =
    handler(
      simulate.request(
        http.Delete,
        "/api/v1/tasks/" <> int_to_string(task_id) <> "/notes",
      )
      |> fixtures.with_session_cookies(member_session, member_csrf),
    )

  expect.expect_status(delete_collection_res, 405)

  let patch_collection_res =
    handler(
      simulate.request(
        http.Patch,
        "/api/v1/tasks/" <> int_to_string(task_id) <> "/notes",
      )
      |> fixtures.with_auth(fixture_session(member_session, member_csrf)),
    )

  expect.expect_status(patch_collection_res, 405)

  let note_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/tasks/" <> int_to_string(task_id) <> "/notes",
      )
      |> fixtures.with_auth(fixture_session(member_session, member_csrf))
      |> simulate.json_body(
        json.object([#("content", json.string("Remove me"))]),
      ),
    )
  expect.expect_status(note_res, 200)
  let note_id = decode_note_id(simulate.read_body(note_res))

  let delete_item_res =
    handler(
      simulate.request(
        http.Delete,
        "/api/v1/tasks/"
          <> int_to_string(task_id)
          <> "/notes/"
          <> int_to_string(note_id),
      )
      |> fixtures.with_auth(fixture_session(member_session, member_csrf)),
    )

  expect.expect_status(delete_item_res, 204)

  let list_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/tasks/" <> int_to_string(task_id) <> "/notes",
      )
      |> request.set_cookie("sb_session", member_session),
    )

  expect.expect_status(list_res, 200)
  decode_note_list_contents(simulate.read_body(list_res))
  |> expect.equal([])

  let patch_item_res =
    handler(
      simulate.request(
        http.Patch,
        "/api/v1/tasks/" <> int_to_string(task_id) <> "/notes/1",
      )
      |> fixtures.with_auth(fixture_session(member_session, member_csrf)),
    )

  expect.expect_status(patch_item_res, 405)
}

pub fn task_notes_create_requires_csrf_test() {
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
    )

  let member_id =
    create_member_user(handler, db, "member@example.com", "inv_member")

  add_member(handler, admin_session, admin_csrf, project_id, member_id)

  let #(member_session, member_csrf) =
    login_session(handler, "member@example.com")

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

  let note_req =
    simulate.request(
      http.Post,
      "/api/v1/tasks/" <> int_to_string(task_id) <> "/notes",
    )
    |> fixtures.with_session_cookies(member_session, member_csrf)
    |> simulate.json_body(json.object([#("content", json.string("One"))]))

  let note_res = handler(note_req)
  expect.expect_status(note_res, 403)
}

// Justification: large function kept intact to preserve cohesive logic.
pub fn card_notes_list_requires_card_membership_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let #(admin_session, admin_csrf) = login_session(handler, "admin@example.com")
  let project_id = create_project(handler, admin_session, admin_csrf, "Core")

  let member_id =
    create_member_user(handler, db, "member@example.com", "inv_member")
  create_member_user(handler, db, "outsider@example.com", "inv_out")

  add_member(handler, admin_session, admin_csrf, project_id, member_id)

  let #(member_session, member_csrf) =
    login_session(handler, "member@example.com")

  let #(outsider_session, outsider_csrf) =
    login_session(handler, "outsider@example.com")

  let card_id =
    create_card(handler, admin_session, admin_csrf, project_id, "Card")

  let _ =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/cards/" <> int_to_string(card_id) <> "/notes",
      )
      |> fixtures.with_auth(fixture_session(member_session, member_csrf))
      |> simulate.json_body(json.object([#("content", json.string("One"))])),
    )

  let member_list_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/cards/" <> int_to_string(card_id) <> "/notes",
      )
      |> fixtures.with_session_cookies(member_session, member_csrf),
    )

  expect.expect_status(member_list_res, 200)
  decode_note_list_contents(simulate.read_body(member_list_res))
  |> expect.equal(["One"])

  let outsider_req =
    simulate.request(
      http.Get,
      "/api/v1/cards/" <> int_to_string(card_id) <> "/notes",
    )
    |> fixtures.with_session_cookies(outsider_session, outsider_csrf)

  let outsider_res = handler(outsider_req)
  expect.expect_status(outsider_res, 404)
  string.contains(simulate.read_body(outsider_res), "NOT_FOUND")
  |> expect.is_true
}

pub fn card_notes_list_orders_by_created_at_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let #(admin_session, admin_csrf) = login_session(handler, "admin@example.com")
  let project_id = create_project(handler, admin_session, admin_csrf, "Core")

  let card_id =
    create_card(handler, admin_session, admin_csrf, project_id, "Card")

  let admin_id =
    single_int(db, "select id from users where email = 'admin@example.com'", [])

  insert_note_with_created_at(
    db,
    card_id,
    admin_id,
    "First",
    "2026-02-01T10:00:00Z",
  )

  insert_note_with_created_at(
    db,
    card_id,
    admin_id,
    "Second",
    "2026-02-01T11:00:00Z",
  )

  let list_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/cards/" <> int_to_string(card_id) <> "/notes",
      )
      |> fixtures.with_session_cookies(admin_session, admin_csrf),
    )

  expect.expect_status(list_res, 200)
  decode_note_list_contents(simulate.read_body(list_res))
  |> expect.equal(["First", "Second"])
}

// Justification: large function kept intact to preserve cohesive logic.
pub fn card_notes_create_and_delete_permissions_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let #(admin_session, admin_csrf) = login_session(handler, "admin@example.com")
  let project_id = create_project(handler, admin_session, admin_csrf, "Core")

  let member1_id =
    create_member_user(handler, db, "member1@example.com", "inv_member1")
  let member2_id =
    create_member_user(handler, db, "member2@example.com", "inv_member2")

  add_member(handler, admin_session, admin_csrf, project_id, member1_id)
  add_member(handler, admin_session, admin_csrf, project_id, member2_id)

  let #(member1_session, member1_csrf) =
    login_session(handler, "member1@example.com")

  let #(member2_session, member2_csrf) =
    login_session(handler, "member2@example.com")

  let card_id =
    create_card(handler, admin_session, admin_csrf, project_id, "Card")

  let note_req =
    simulate.request(
      http.Post,
      "/api/v1/cards/" <> int_to_string(card_id) <> "/notes",
    )
    |> fixtures.with_auth(fixture_session(member1_session, member1_csrf))
    |> simulate.json_body(
      json.object([
        #("content", json.string("Note")),
        #("url", json.string("https://example.com/card-note")),
      ]),
    )

  let note_res = handler(note_req)
  expect.expect_status(note_res, 200)
  decode_created_note_contract(simulate.read_body(note_res))
  |> expect.equal(#("https://example.com/card-note", False, True))
  let note_id = decode_note_id(simulate.read_body(note_res))

  let pin_forbidden =
    simulate.request(
      http.Post,
      "/api/v1/cards/"
        <> int_to_string(card_id)
        <> "/notes/"
        <> int_to_string(note_id)
        <> "/pin",
    )
    |> fixtures.with_auth(fixture_session(member2_session, member2_csrf))

  expect.expect_status(handler(pin_forbidden), 403)

  let pin_by_author =
    simulate.request(
      http.Post,
      "/api/v1/cards/"
        <> int_to_string(card_id)
        <> "/notes/"
        <> int_to_string(note_id)
        <> "/pin",
    )
    |> fixtures.with_auth(fixture_session(member1_session, member1_csrf))

  let pin_res = handler(pin_by_author)
  expect.expect_status(pin_res, 200)
  decode_note_pinned(simulate.read_body(pin_res)) |> expect.equal(True)

  let unpin_by_author =
    simulate.request(
      http.Delete,
      "/api/v1/cards/"
        <> int_to_string(card_id)
        <> "/notes/"
        <> int_to_string(note_id)
        <> "/pin",
    )
    |> fixtures.with_auth(fixture_session(member1_session, member1_csrf))

  let unpin_res = handler(unpin_by_author)
  expect.expect_status(unpin_res, 200)
  decode_note_pinned(simulate.read_body(unpin_res)) |> expect.equal(False)

  let delete_forbidden =
    simulate.request(
      http.Delete,
      "/api/v1/cards/"
        <> int_to_string(card_id)
        <> "/notes/"
        <> int_to_string(note_id),
    )
    |> fixtures.with_auth(fixture_session(member2_session, member2_csrf))

  expect.expect_status(handler(delete_forbidden), 403)

  let delete_author =
    simulate.request(
      http.Delete,
      "/api/v1/cards/"
        <> int_to_string(card_id)
        <> "/notes/"
        <> int_to_string(note_id),
    )
    |> fixtures.with_auth(fixture_session(member1_session, member1_csrf))

  expect.expect_status(handler(delete_author), 204)

  let note_res_2 = handler(note_req)
  expect.expect_status(note_res_2, 200)
  let note_id_2 = decode_note_id(simulate.read_body(note_res_2))

  let pin_by_admin =
    simulate.request(
      http.Post,
      "/api/v1/cards/"
        <> int_to_string(card_id)
        <> "/notes/"
        <> int_to_string(note_id_2)
        <> "/pin",
    )
    |> fixtures.with_auth(fixture_session(admin_session, admin_csrf))

  let admin_pin_res = handler(pin_by_admin)
  expect.expect_status(admin_pin_res, 200)
  decode_note_pinned(simulate.read_body(admin_pin_res)) |> expect.equal(True)

  let delete_admin =
    simulate.request(
      http.Delete,
      "/api/v1/cards/"
        <> int_to_string(card_id)
        <> "/notes/"
        <> int_to_string(note_id_2),
    )
    |> fixtures.with_auth(fixture_session(admin_session, admin_csrf))

  expect.expect_status(handler(delete_admin), 204)
}

pub fn card_notes_create_requires_csrf_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let #(admin_session, admin_csrf) = login_session(handler, "admin@example.com")
  let project_id = create_project(handler, admin_session, admin_csrf, "Core")

  let member_id =
    create_member_user(handler, db, "member@example.com", "inv_member")

  add_member(handler, admin_session, admin_csrf, project_id, member_id)

  let #(member_session, member_csrf) =
    login_session(handler, "member@example.com")

  let card_id =
    create_card(handler, admin_session, admin_csrf, project_id, "Card")

  let note_req =
    simulate.request(
      http.Post,
      "/api/v1/cards/" <> int_to_string(card_id) <> "/notes",
    )
    |> fixtures.with_session_cookies(member_session, member_csrf)
    |> simulate.json_body(json.object([#("content", json.string("One"))]))

  let note_res = handler(note_req)
  expect.expect_status(note_res, 403)
}

// Justification: large function kept intact to preserve cohesive logic.
pub fn card_notes_indicator_updates_after_view_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let #(admin_session, admin_csrf) = login_session(handler, "admin@example.com")
  let project_id = create_project(handler, admin_session, admin_csrf, "Core")

  let member_id =
    create_member_user(handler, db, "member@example.com", "inv_member")

  add_member(handler, admin_session, admin_csrf, project_id, member_id)

  let #(member_session, member_csrf) =
    login_session(handler, "member@example.com")

  let card_id =
    create_card(handler, admin_session, admin_csrf, project_id, "Card")

  let note_req =
    simulate.request(
      http.Post,
      "/api/v1/cards/" <> int_to_string(card_id) <> "/notes",
    )
    |> fixtures.with_auth(fixture_session(member_session, member_csrf))
    |> simulate.json_body(json.object([#("content", json.string("Note"))]))

  expect.expect_status(handler(note_req), 200)

  let list_req =
    simulate.request(
      http.Get,
      "/api/v1/projects/" <> int_to_string(project_id) <> "/cards",
    )
    |> fixtures.with_session_cookies(member_session, member_csrf)

  let list_res = handler(list_req)
  expect.expect_status(list_res, 200)
  decode_card_has_new_notes(simulate.read_body(list_res), card_id)
  |> expect.equal(True)

  let view_req =
    simulate.request(http.Put, "/api/v1/views/cards/" <> int_to_string(card_id))
    |> fixtures.with_auth(fixture_session(member_session, member_csrf))

  expect.expect_status(handler(view_req), 204)

  let list_res_2 = handler(list_req)
  expect.expect_status(list_res_2, 200)
  decode_card_has_new_notes(simulate.read_body(list_res_2), card_id)
  |> expect.equal(False)
}

// Justification: large function kept intact to mirror the card view contract.
pub fn task_notes_indicator_updates_after_view_test() {
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
    )

  let member_id =
    create_member_user(handler, db, "member@example.com", "inv_member")

  add_member(handler, admin_session, admin_csrf, project_id, member_id)

  let #(member_session, member_csrf) =
    login_session(handler, "member@example.com")

  let task_id =
    create_task(
      handler,
      admin_session,
      admin_csrf,
      project_id,
      "Task",
      "",
      3,
      type_id,
    )

  let note_req =
    simulate.request(
      http.Post,
      "/api/v1/tasks/" <> int_to_string(task_id) <> "/notes",
    )
    |> fixtures.with_auth(fixture_session(member_session, member_csrf))
    |> simulate.json_body(json.object([#("content", json.string("Note"))]))

  expect.expect_status(handler(note_req), 200)

  let list_req =
    simulate.request(
      http.Get,
      "/api/v1/projects/" <> int_to_string(project_id) <> "/tasks",
    )
    |> fixtures.with_session_cookies(member_session, member_csrf)

  let list_res = handler(list_req)
  expect.expect_status(list_res, 200)
  decode_task_has_new_notes(simulate.read_body(list_res), task_id)
  |> expect.equal(True)

  let view_req =
    simulate.request(http.Put, "/api/v1/views/tasks/" <> int_to_string(task_id))
    |> fixtures.with_auth(fixture_session(member_session, member_csrf))

  expect.expect_status(handler(view_req), 204)

  let list_res_2 = handler(list_req)
  expect.expect_status(list_res_2, 200)
  decode_task_has_new_notes(simulate.read_body(list_res_2), task_id)
  |> expect.equal(False)
}

pub fn resource_views_reject_unsupported_methods_test() {
  let ResourceViewFixture(handler:, session:, csrf:, card_id:, task_id:, ..) =
    resource_view_fixture()

  let card_req =
    simulate.request(http.Get, "/api/v1/views/cards/" <> int_to_string(card_id))
    |> fixtures.with_session_cookies(session, csrf)

  expect.expect_status(handler(card_req), 405)

  let task_req =
    simulate.request(http.Get, "/api/v1/views/tasks/" <> int_to_string(task_id))
    |> fixtures.with_session_cookies(session, csrf)

  expect.expect_status(handler(task_req), 405)
}

pub fn resource_views_reject_invalid_ids_test() {
  let ResourceViewFixture(handler:, session:, csrf:, ..) =
    resource_view_fixture()

  let card_req =
    simulate.request(http.Put, "/api/v1/views/cards/not-a-card-id")
    |> fixtures.with_auth(fixture_session(session, csrf))

  expect.expect_status(handler(card_req), 404)

  let task_req =
    simulate.request(http.Put, "/api/v1/views/tasks/not-a-task-id")
    |> fixtures.with_auth(fixture_session(session, csrf))

  expect.expect_status(handler(task_req), 404)
}

pub fn resource_views_hide_resources_from_non_project_members_test() {
  let ResourceViewFixture(handler:, db:, card_id:, task_id:, ..) =
    resource_view_fixture()

  let #(outsider_session, outsider_csrf) =
    create_logged_in_user(handler, db, "outsider@example.com", "inv_outsider")

  let card_req =
    simulate.request(http.Put, "/api/v1/views/cards/" <> int_to_string(card_id))
    |> fixtures.with_auth(fixture_session(outsider_session, outsider_csrf))

  expect.expect_status(handler(card_req), 404)

  let task_req =
    simulate.request(http.Put, "/api/v1/views/tasks/" <> int_to_string(task_id))
    |> fixtures.with_auth(fixture_session(outsider_session, outsider_csrf))

  expect.expect_status(handler(task_req), 404)
}

pub fn task_positions_upsert_requires_csrf_test() {
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
    )

  let member_id =
    create_member_user(handler, db, "member@example.com", "inv_member")

  add_member(handler, admin_session, admin_csrf, project_id, member_id)

  let #(member_session, member_csrf) =
    login_session(handler, "member@example.com")

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

  let put_req =
    simulate.request(
      http.Put,
      "/api/v1/me/task-positions/" <> int_to_string(task_id),
    )
    |> fixtures.with_session_cookies(member_session, member_csrf)
    |> simulate.json_body(
      json.object([#("x", json.int(1)), #("y", json.int(2))]),
    )

  let put_res = handler(put_req)
  expect.expect_status(put_res, 403)
}

// Justification: large function kept intact to preserve cohesive logic.
pub fn task_positions_are_per_user_and_can_be_filtered_by_project_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let #(admin_session, admin_csrf) = login_session(handler, "admin@example.com")

  let core_id = create_project(handler, admin_session, admin_csrf, "Core")
  let other_id = create_project(handler, admin_session, admin_csrf, "Other")

  let core_type_id =
    create_task_type(
      handler,
      admin_session,
      admin_csrf,
      core_id,
      "Bug",
      "bug-ant",
    )
  let other_type_id =
    create_task_type(
      handler,
      admin_session,
      admin_csrf,
      other_id,
      "Bug",
      "bug-ant",
    )

  let member1_id =
    create_member_user(handler, db, "member1@example.com", "inv_member1")
  let member2_id =
    create_member_user(handler, db, "member2@example.com", "inv_member2")

  add_member(handler, admin_session, admin_csrf, core_id, member1_id)
  add_member(handler, admin_session, admin_csrf, core_id, member2_id)
  add_member(handler, admin_session, admin_csrf, other_id, member1_id)
  add_member(handler, admin_session, admin_csrf, other_id, member2_id)

  let #(member1_session, member1_csrf) =
    login_session(handler, "member1@example.com")

  let #(member2_session, member2_csrf) =
    login_session(handler, "member2@example.com")

  let core_task_id =
    create_task(
      handler,
      admin_session,
      admin_csrf,
      core_id,
      "Core",
      "",
      3,
      core_type_id,
    )
  let other_task_id =
    create_task(
      handler,
      admin_session,
      admin_csrf,
      other_id,
      "Other",
      "",
      3,
      other_type_id,
    )

  upsert_position(handler, member1_session, member1_csrf, core_task_id, 10, 20)
  |> expect.equal(200)

  upsert_position(handler, member1_session, member1_csrf, other_task_id, 1, 2)
  |> expect.equal(200)

  upsert_position(handler, member2_session, member2_csrf, core_task_id, 30, 40)
  |> expect.equal(200)

  let member1_all_res =
    handler(
      simulate.request(http.Get, "/api/v1/me/task-positions")
      |> fixtures.with_session_cookies(member1_session, member1_csrf),
    )

  expect.expect_status(member1_all_res, 200)

  decode_positions_xy_by_task(simulate.read_body(member1_all_res), core_task_id)
  |> expect.equal(#(10, 20))

  let member1_core_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/me/task-positions?project_id=" <> int_to_string(core_id),
      )
      |> fixtures.with_session_cookies(member1_session, member1_csrf),
    )

  expect.expect_status(member1_core_res, 200)
  decode_position_task_ids(simulate.read_body(member1_core_res))
  |> expect.equal([core_task_id])

  let member2_all_res =
    handler(
      simulate.request(http.Get, "/api/v1/me/task-positions")
      |> fixtures.with_session_cookies(member2_session, member2_csrf),
    )

  expect.expect_status(member2_all_res, 200)
  decode_positions_xy_by_task(simulate.read_body(member2_all_res), core_task_id)
  |> expect.equal(#(30, 40))
}

pub fn task_positions_reject_non_member_task_and_project_filter_test() {
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
    )

  let member_id =
    create_member_user(handler, db, "member@example.com", "inv_member")
  create_member_user(handler, db, "outsider@example.com", "inv_out")

  add_member(handler, admin_session, admin_csrf, project_id, member_id)

  let #(outsider_session, outsider_csrf) =
    login_session(handler, "outsider@example.com")

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

  let put_req =
    simulate.request(
      http.Put,
      "/api/v1/me/task-positions/" <> int_to_string(task_id),
    )
    |> fixtures.with_auth(fixture_session(outsider_session, outsider_csrf))
    |> simulate.json_body(
      json.object([#("x", json.int(1)), #("y", json.int(2))]),
    )

  let put_res = handler(put_req)
  expect.expect_status(put_res, 404)

  let filtered_req =
    simulate.request(
      http.Get,
      "/api/v1/me/task-positions?project_id=" <> int_to_string(project_id),
    )
    |> fixtures.with_session_cookies(outsider_session, outsider_csrf)

  let filtered_res = handler(filtered_req)
  expect.expect_status(filtered_res, 403)
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

fn decode_created_note_contract(body: String) -> #(String, Bool, Bool) {
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let note_decoder = {
    use url <- decode.field("url", decode.string)
    use pinned <- decode.field("pinned", decode.bool)
    use updated_at <- decode.field("updated_at", decode.string)
    decode.success(#(url, pinned, updated_at != ""))
  }

  let data_decoder = {
    use note <- decode.field("note", note_decoder)
    decode.success(note)
  }

  let response_decoder = {
    use note <- decode.field("data", data_decoder)
    decode.success(note)
  }

  let assert Ok(contract) = decode.run(dynamic, response_decoder)
  contract
}

fn decode_note_pinned(body: String) -> Bool {
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let note_decoder = {
    use pinned <- decode.field("pinned", decode.bool)
    decode.success(pinned)
  }

  let data_decoder = {
    use note <- decode.field("note", note_decoder)
    decode.success(note)
  }

  let response_decoder = {
    use pinned <- decode.field("data", data_decoder)
    decode.success(pinned)
  }

  let assert Ok(pinned) = decode.run(dynamic, response_decoder)
  pinned
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

fn insert_note_with_created_at(
  db: pog.Connection,
  card_id: Int,
  user_id: Int,
  content: String,
  created_at: String,
) {
  let assert Ok(ts) = timestamp.parse_rfc3339(created_at)
  let assert Ok(_) =
    pog.query(
      "with card_scope as (
         select id, project_id
         from cards
         where id = $1
       ), inserted_note as (
         insert into notes (
           project_id,
           user_id,
           content,
           created_at,
           updated_at
         )
         select project_id, $2, $3, $4, $4
         from card_scope
         returning id
       )
       insert into card_notes (note_id, card_id)
       select inserted_note.id, card_scope.id
       from inserted_note, card_scope",
    )
    |> pog.parameter(pog.int(card_id))
    |> pog.parameter(pog.int(user_id))
    |> pog.parameter(pog.text(content))
    |> pog.parameter(pog.timestamp(ts))
    |> pog.execute(db)

  Nil
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

fn decode_task_has_new_notes(body: String, task_id: Int) -> Bool {
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let task_decoder = {
    use id <- decode.field("id", decode.int)
    use has_new_notes <- decode.field("has_new_notes", decode.bool)
    decode.success(#(id, has_new_notes))
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
  let assert Ok(#(_, has_new_notes)) =
    list.find(tasks, fn(task) { task.0 == task_id })

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
    |> fixtures.with_auth(fixture_session(session, csrf))
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
) -> Int {
  fixtures.create_task_type(
    handler,
    fixture_session(session, csrf),
    project_id,
    name,
    icon,
  )
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
  let card_id =
    create_card(handler, session, csrf, project_id, title <> " card")
  activate_card(handler, session, csrf, card_id)
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
    |> fixtures.with_auth(fixture_session(session, csrf))
    |> simulate.json_body(
      json.object([
        #("title", json.string(title)),
        #("description", json.string("")),
      ]),
    )

  let res = handler(req)
  expect.expect_status(res, 200)

  decode_card_id(simulate.read_body(res))
}

fn activate_card(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  card_id: Int,
) {
  fixtures.activate_card(handler, fixture_session(session, csrf), card_id)
  |> expect.ok
}

fn add_member(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  project_id: Int,
  user_id: Int,
) {
  fixtures.add_member(
    handler,
    fixture_session(session, csrf),
    project_id,
    user_id,
    "member",
  )
  |> expect.ok
}

fn resource_view_fixture() -> ResourceViewFixture {
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
    )

  let card_id =
    create_card(handler, admin_session, admin_csrf, project_id, "Card")

  let task_id =
    create_task(
      handler,
      admin_session,
      admin_csrf,
      project_id,
      "Task",
      "",
      3,
      type_id,
    )

  ResourceViewFixture(
    handler: handler,
    db: db,
    session: admin_session,
    csrf: admin_csrf,
    card_id: card_id,
    task_id: task_id,
  )
}

fn create_logged_in_user(
  handler: fn(wisp.Request) -> wisp.Response,
  db: pog.Connection,
  email: String,
  invite_code: String,
) -> #(String, String) {
  create_member_user(handler, db, email, invite_code)
  login_session(handler, email)
}

fn create_member_user(
  handler: fn(wisp.Request) -> wisp.Response,
  db: pog.Connection,
  email: String,
  invite_code: String,
) -> Int {
  fixtures.create_member_user(handler, db, email, invite_code)
  |> expect.ok
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
