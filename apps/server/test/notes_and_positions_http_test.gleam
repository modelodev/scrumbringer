import fixtures as fx
import gleam/dynamic/decode
import gleam/http
import gleam/int
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

type ResourceViewFixture {
  ResourceViewFixture(
    handler: fn(wisp.Request) -> wisp.Response,
    db: pog.Connection,
    session: fx.Session,
    card_id: Int,
    task_id: Int,
  )
}

type NoteTarget {
  TaskNotes(Int)
  CardNotes(Int)
}

pub fn main() {
  gleeunit.main()
}

// Justification: large function kept intact to preserve cohesive logic.
pub fn task_notes_create_and_available_task_patch_allow_project_member_test() {
  let app = fx.require_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_session = fx.require_login_session(handler, "admin@example.com")
  let project_id = fx.require_project(handler, admin_session, "Core")
  let type_id =
    fx.require_task_type(handler, admin_session, project_id, "Bug", "bug-ant")

  let member1_id =
    fx.require_member_user(handler, db, "member1@example.com", "inv_member1")
  let member2_id =
    fx.require_member_user(handler, db, "member2@example.com", "inv_member2")

  fx.require_project_member(handler, admin_session, project_id, member1_id)
  fx.require_project_member(handler, admin_session, project_id, member2_id)

  let member1_session = fx.require_login_session(handler, "member1@example.com")

  let member2_session = fx.require_login_session(handler, "member2@example.com")

  let task_id =
    fx.require_task(handler, admin_session, project_id, "Core", "", 3, type_id)

  let note_res =
    create_note_with_url_response(
      handler,
      member2_session,
      TaskNotes(task_id),
      "Investigating",
      "https://example.com/task-note",
    )

  expect.expect_status(note_res, 200)
  decode_note_content(simulate.read_body(note_res))
  |> expect.equal("Investigating")
  decode_created_note_contract(simulate.read_body(note_res))
  |> expect.equal(#("https://example.com/task-note", False, True))
  let note_id = decode_note_id(simulate.read_body(note_res))

  expect.expect_status(
    pin_note_response(handler, member1_session, TaskNotes(task_id), note_id),
    403,
  )

  let pin_res =
    pin_note_response(handler, member2_session, TaskNotes(task_id), note_id)
  expect.expect_status(pin_res, 200)
  decode_note_pinned(simulate.read_body(pin_res)) |> expect.equal(True)

  let unpin_res =
    unpin_note_response(handler, member2_session, TaskNotes(task_id), note_id)
  expect.expect_status(unpin_res, 200)
  decode_note_pinned(simulate.read_body(unpin_res)) |> expect.equal(False)

  let patch_req =
    simulate.request(http.Patch, "/api/v1/tasks/" <> int.to_string(task_id))
    |> fx.with_auth(member2_session)
    |> simulate.json_body(
      json.object([
        #("version", json.int(1)),
        #("title", json.string("New")),
      ]),
    )

  let patch_res = handler(patch_req)
  expect.expect_status(patch_res, 200)
}

// Justification: large function kept intact to preserve cohesive logic.
pub fn task_notes_list_requires_task_membership_test() {
  let app = fx.require_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_session = fx.require_login_session(handler, "admin@example.com")
  let project_id = fx.require_project(handler, admin_session, "Core")
  let type_id =
    fx.require_task_type(handler, admin_session, project_id, "Bug", "bug-ant")

  let member_id =
    fx.require_member_user(handler, db, "member@example.com", "inv_member")
  fx.require_member_user(handler, db, "outsider@example.com", "inv_out")

  fx.require_project_member(handler, admin_session, project_id, member_id)

  let member_session = fx.require_login_session(handler, "member@example.com")

  let outsider_session =
    fx.require_login_session(handler, "outsider@example.com")

  let task_id =
    fx.require_task(handler, admin_session, project_id, "Core", "", 3, type_id)

  let _ =
    create_note_response(handler, member_session, TaskNotes(task_id), "One")

  let member_list_res =
    list_notes_response(handler, member_session, TaskNotes(task_id))

  expect.expect_status(member_list_res, 200)
  decode_note_list_contents(simulate.read_body(member_list_res))
  |> expect.equal(["One"])

  let outsider_res =
    list_notes_response(handler, outsider_session, TaskNotes(task_id))
  expect.expect_status(outsider_res, 404)
  string.contains(simulate.read_body(outsider_res), "NOT_FOUND")
  |> expect.is_true
}

// Justification: large function kept intact to preserve cohesive logic.
pub fn task_notes_can_be_deleted_by_author_and_patch_item_is_not_allowed_test() {
  let app = fx.require_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_session = fx.require_login_session(handler, "admin@example.com")
  let project_id = fx.require_project(handler, admin_session, "Core")
  let type_id =
    fx.require_task_type(handler, admin_session, project_id, "Bug", "bug-ant")

  let member_id =
    fx.require_member_user(handler, db, "member@example.com", "inv_member")

  fx.require_project_member(handler, admin_session, project_id, member_id)

  let member_session = fx.require_login_session(handler, "member@example.com")

  let task_id =
    fx.require_task(handler, admin_session, project_id, "Core", "", 3, type_id)

  let delete_collection_res =
    handler(
      simulate.request(
        http.Delete,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "/notes",
      )
      |> fx.with_session_cookies(member_session),
    )

  expect.expect_status(delete_collection_res, 405)

  let patch_collection_res =
    handler(
      simulate.request(
        http.Patch,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "/notes",
      )
      |> fx.with_auth(member_session),
    )

  expect.expect_status(patch_collection_res, 405)

  let note_res =
    create_note_response(
      handler,
      member_session,
      TaskNotes(task_id),
      "Remove me",
    )
  expect.expect_status(note_res, 200)
  let note_id = decode_note_id(simulate.read_body(note_res))

  let delete_item_res =
    delete_note_response(handler, member_session, TaskNotes(task_id), note_id)

  expect.expect_status(delete_item_res, 204)

  let list_res =
    list_notes_response(handler, member_session, TaskNotes(task_id))

  expect.expect_status(list_res, 200)
  decode_note_list_contents(simulate.read_body(list_res))
  |> expect.equal([])

  let patch_item_res =
    handler(
      simulate.request(
        http.Patch,
        "/api/v1/tasks/" <> int.to_string(task_id) <> "/notes/1",
      )
      |> fx.with_auth(member_session),
    )

  expect.expect_status(patch_item_res, 405)
}

pub fn task_notes_create_requires_csrf_test() {
  let app = fx.require_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_session = fx.require_login_session(handler, "admin@example.com")
  let project_id = fx.require_project(handler, admin_session, "Core")
  let type_id =
    fx.require_task_type(handler, admin_session, project_id, "Bug", "bug-ant")

  let member_id =
    fx.require_member_user(handler, db, "member@example.com", "inv_member")

  fx.require_project_member(handler, admin_session, project_id, member_id)

  let member_session = fx.require_login_session(handler, "member@example.com")

  let task_id =
    fx.require_task(handler, admin_session, project_id, "Core", "", 3, type_id)

  let note_req =
    simulate.request(
      http.Post,
      "/api/v1/tasks/" <> int.to_string(task_id) <> "/notes",
    )
    |> fx.with_session_cookies(member_session)
    |> simulate.json_body(json.object([#("content", json.string("One"))]))

  let note_res = handler(note_req)
  expect.expect_status(note_res, 403)
}

// Justification: large function kept intact to preserve cohesive logic.
pub fn card_notes_list_requires_card_membership_test() {
  let app = fx.require_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_session = fx.require_login_session(handler, "admin@example.com")
  let project_id = fx.require_project(handler, admin_session, "Core")

  let member_id =
    fx.require_member_user(handler, db, "member@example.com", "inv_member")
  fx.require_member_user(handler, db, "outsider@example.com", "inv_out")

  fx.require_project_member(handler, admin_session, project_id, member_id)

  let member_session = fx.require_login_session(handler, "member@example.com")

  let outsider_session =
    fx.require_login_session(handler, "outsider@example.com")

  let card_id = fx.require_card(handler, admin_session, project_id, "Card")

  let _ =
    create_note_response(handler, member_session, CardNotes(card_id), "One")

  let member_list_res =
    list_notes_response(handler, member_session, CardNotes(card_id))

  expect.expect_status(member_list_res, 200)
  decode_note_list_contents(simulate.read_body(member_list_res))
  |> expect.equal(["One"])

  let outsider_res =
    list_notes_response(handler, outsider_session, CardNotes(card_id))
  expect.expect_status(outsider_res, 404)
  string.contains(simulate.read_body(outsider_res), "NOT_FOUND")
  |> expect.is_true
}

pub fn card_notes_list_orders_by_created_at_test() {
  let app = fx.require_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_session = fx.require_login_session(handler, "admin@example.com")
  let project_id = fx.require_project(handler, admin_session, "Core")

  let card_id = fx.require_card(handler, admin_session, project_id, "Card")

  let admin_id =
    fx.require_query_int(
      db,
      "select id from users where email = 'admin@example.com'",
      [],
    )

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

  let list_res = list_notes_response(handler, admin_session, CardNotes(card_id))

  expect.expect_status(list_res, 200)
  decode_note_list_contents(simulate.read_body(list_res))
  |> expect.equal(["First", "Second"])
}

// Justification: large function kept intact to preserve cohesive logic.
pub fn card_notes_create_and_delete_permissions_test() {
  let app = fx.require_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_session = fx.require_login_session(handler, "admin@example.com")
  let project_id = fx.require_project(handler, admin_session, "Core")

  let member1_id =
    fx.require_member_user(handler, db, "member1@example.com", "inv_member1")
  let member2_id =
    fx.require_member_user(handler, db, "member2@example.com", "inv_member2")

  fx.require_project_member(handler, admin_session, project_id, member1_id)
  fx.require_project_member(handler, admin_session, project_id, member2_id)

  let member1_session = fx.require_login_session(handler, "member1@example.com")

  let member2_session = fx.require_login_session(handler, "member2@example.com")

  let card_id = fx.require_card(handler, admin_session, project_id, "Card")

  let note_res =
    create_note_with_url_response(
      handler,
      member1_session,
      CardNotes(card_id),
      "Note",
      "https://example.com/card-note",
    )

  expect.expect_status(note_res, 200)
  decode_created_note_contract(simulate.read_body(note_res))
  |> expect.equal(#("https://example.com/card-note", False, True))
  let note_id = decode_note_id(simulate.read_body(note_res))

  expect.expect_status(
    pin_note_response(handler, member2_session, CardNotes(card_id), note_id),
    403,
  )

  let pin_res =
    pin_note_response(handler, member1_session, CardNotes(card_id), note_id)
  expect.expect_status(pin_res, 200)
  decode_note_pinned(simulate.read_body(pin_res)) |> expect.equal(True)

  let unpin_res =
    unpin_note_response(handler, member1_session, CardNotes(card_id), note_id)
  expect.expect_status(unpin_res, 200)
  decode_note_pinned(simulate.read_body(unpin_res)) |> expect.equal(False)

  expect.expect_status(
    delete_note_response(handler, member2_session, CardNotes(card_id), note_id),
    403,
  )

  expect.expect_status(
    delete_note_response(handler, member1_session, CardNotes(card_id), note_id),
    204,
  )

  let note_res_2 =
    create_note_with_url_response(
      handler,
      member1_session,
      CardNotes(card_id),
      "Note",
      "https://example.com/card-note",
    )
  expect.expect_status(note_res_2, 200)
  let note_id_2 = decode_note_id(simulate.read_body(note_res_2))

  let admin_pin_res =
    pin_note_response(handler, admin_session, CardNotes(card_id), note_id_2)
  expect.expect_status(admin_pin_res, 200)
  decode_note_pinned(simulate.read_body(admin_pin_res)) |> expect.equal(True)

  expect.expect_status(
    delete_note_response(handler, admin_session, CardNotes(card_id), note_id_2),
    204,
  )
}

pub fn card_notes_create_requires_csrf_test() {
  let app = fx.require_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_session = fx.require_login_session(handler, "admin@example.com")
  let project_id = fx.require_project(handler, admin_session, "Core")

  let member_id =
    fx.require_member_user(handler, db, "member@example.com", "inv_member")

  fx.require_project_member(handler, admin_session, project_id, member_id)

  let member_session = fx.require_login_session(handler, "member@example.com")

  let card_id = fx.require_card(handler, admin_session, project_id, "Card")

  let note_req =
    simulate.request(
      http.Post,
      "/api/v1/cards/" <> int.to_string(card_id) <> "/notes",
    )
    |> fx.with_session_cookies(member_session)
    |> simulate.json_body(json.object([#("content", json.string("One"))]))

  let note_res = handler(note_req)
  expect.expect_status(note_res, 403)
}

// Justification: large function kept intact to preserve cohesive logic.
pub fn card_notes_indicator_updates_after_view_test() {
  let app = fx.require_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_session = fx.require_login_session(handler, "admin@example.com")
  let project_id = fx.require_project(handler, admin_session, "Core")

  let member_id =
    fx.require_member_user(handler, db, "member@example.com", "inv_member")

  fx.require_project_member(handler, admin_session, project_id, member_id)

  let member_session = fx.require_login_session(handler, "member@example.com")

  let card_id = fx.require_card(handler, admin_session, project_id, "Card")

  expect.expect_status(
    create_note_response(handler, member_session, CardNotes(card_id), "Note"),
    200,
  )

  let list_req =
    simulate.request(
      http.Get,
      "/api/v1/projects/" <> int.to_string(project_id) <> "/cards",
    )
    |> fx.with_session_cookies(member_session)

  let list_res = handler(list_req)
  expect.expect_status(list_res, 200)
  decode_card_has_new_notes(simulate.read_body(list_res), card_id)
  |> expect.equal(True)

  let view_req =
    simulate.request(http.Put, "/api/v1/views/cards/" <> int.to_string(card_id))
    |> fx.with_auth(member_session)

  expect.expect_status(handler(view_req), 204)

  let list_res_2 = handler(list_req)
  expect.expect_status(list_res_2, 200)
  decode_card_has_new_notes(simulate.read_body(list_res_2), card_id)
  |> expect.equal(False)
}

// Justification: large function kept intact to mirror the card view contract.
pub fn task_notes_indicator_updates_after_view_test() {
  let app = fx.require_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_session = fx.require_login_session(handler, "admin@example.com")
  let project_id = fx.require_project(handler, admin_session, "Core")
  let type_id =
    fx.require_task_type(handler, admin_session, project_id, "Bug", "bug-ant")

  let member_id =
    fx.require_member_user(handler, db, "member@example.com", "inv_member")

  fx.require_project_member(handler, admin_session, project_id, member_id)

  let member_session = fx.require_login_session(handler, "member@example.com")

  let task_id =
    fx.require_task(handler, admin_session, project_id, "Task", "", 3, type_id)

  expect.expect_status(
    create_note_response(handler, member_session, TaskNotes(task_id), "Note"),
    200,
  )

  let list_res =
    fx.list_project_tasks_response(handler, member_session, project_id, "")
  expect.expect_status(list_res, 200)
  decode_task_has_new_notes(simulate.read_body(list_res), task_id)
  |> expect.equal(True)

  let view_req =
    simulate.request(http.Put, "/api/v1/views/tasks/" <> int.to_string(task_id))
    |> fx.with_auth(member_session)

  expect.expect_status(handler(view_req), 204)

  let list_res_2 =
    fx.list_project_tasks_response(handler, member_session, project_id, "")
  expect.expect_status(list_res_2, 200)
  decode_task_has_new_notes(simulate.read_body(list_res_2), task_id)
  |> expect.equal(False)
}

pub fn resource_views_reject_unsupported_methods_test() {
  let ResourceViewFixture(handler:, session:, card_id:, task_id:, ..) =
    resource_view_fixture()

  let card_req =
    simulate.request(http.Get, "/api/v1/views/cards/" <> int.to_string(card_id))
    |> fx.with_session_cookies(session)

  expect.expect_status(handler(card_req), 405)

  let task_req =
    simulate.request(http.Get, "/api/v1/views/tasks/" <> int.to_string(task_id))
    |> fx.with_session_cookies(session)

  expect.expect_status(handler(task_req), 405)
}

pub fn resource_views_reject_invalid_ids_test() {
  let ResourceViewFixture(handler:, session:, ..) = resource_view_fixture()

  let card_req =
    simulate.request(http.Put, "/api/v1/views/cards/not-a-card-id")
    |> fx.with_auth(session)

  expect.expect_status(handler(card_req), 404)

  let task_req =
    simulate.request(http.Put, "/api/v1/views/tasks/not-a-task-id")
    |> fx.with_auth(session)

  expect.expect_status(handler(task_req), 404)
}

pub fn resource_views_hide_resources_from_non_project_members_test() {
  let ResourceViewFixture(handler:, db:, card_id:, task_id:, ..) =
    resource_view_fixture()

  let outsider_session =
    create_logged_in_user(handler, db, "outsider@example.com", "inv_outsider")

  let card_req =
    simulate.request(http.Put, "/api/v1/views/cards/" <> int.to_string(card_id))
    |> fx.with_auth(outsider_session)

  expect.expect_status(handler(card_req), 404)

  let task_req =
    simulate.request(http.Put, "/api/v1/views/tasks/" <> int.to_string(task_id))
    |> fx.with_auth(outsider_session)

  expect.expect_status(handler(task_req), 404)
}

pub fn task_positions_upsert_requires_csrf_test() {
  let app = fx.require_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_session = fx.require_login_session(handler, "admin@example.com")
  let project_id = fx.require_project(handler, admin_session, "Core")
  let type_id =
    fx.require_task_type(handler, admin_session, project_id, "Bug", "bug-ant")

  let member_id =
    fx.require_member_user(handler, db, "member@example.com", "inv_member")

  fx.require_project_member(handler, admin_session, project_id, member_id)

  let member_session = fx.require_login_session(handler, "member@example.com")

  let task_id =
    fx.require_task(handler, admin_session, project_id, "Core", "", 3, type_id)

  let put_req =
    simulate.request(
      http.Put,
      "/api/v1/me/task-positions/" <> int.to_string(task_id),
    )
    |> fx.with_session_cookies(member_session)
    |> simulate.json_body(
      json.object([#("x", json.int(1)), #("y", json.int(2))]),
    )

  let put_res = handler(put_req)
  expect.expect_status(put_res, 403)
}

// Justification: large function kept intact to preserve cohesive logic.
pub fn task_positions_are_per_user_and_can_be_filtered_by_project_test() {
  let app = fx.require_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_session = fx.require_login_session(handler, "admin@example.com")

  let core_id = fx.require_project(handler, admin_session, "Core")
  let other_id = fx.require_project(handler, admin_session, "Other")

  let core_type_id =
    fx.require_task_type(handler, admin_session, core_id, "Bug", "bug-ant")
  let other_type_id =
    fx.require_task_type(handler, admin_session, other_id, "Bug", "bug-ant")

  let member1_id =
    fx.require_member_user(handler, db, "member1@example.com", "inv_member1")
  let member2_id =
    fx.require_member_user(handler, db, "member2@example.com", "inv_member2")

  fx.require_project_member(handler, admin_session, core_id, member1_id)
  fx.require_project_member(handler, admin_session, core_id, member2_id)
  fx.require_project_member(handler, admin_session, other_id, member1_id)
  fx.require_project_member(handler, admin_session, other_id, member2_id)

  let member1_session = fx.require_login_session(handler, "member1@example.com")

  let member2_session = fx.require_login_session(handler, "member2@example.com")

  let core_task_id =
    fx.require_task(
      handler,
      admin_session,
      core_id,
      "Core",
      "",
      3,
      core_type_id,
    )
  let other_task_id =
    fx.require_task(
      handler,
      admin_session,
      other_id,
      "Other",
      "",
      3,
      other_type_id,
    )

  upsert_position(handler, member1_session, core_task_id, 10, 20)
  |> expect.equal(200)

  upsert_position(handler, member1_session, other_task_id, 1, 2)
  |> expect.equal(200)

  upsert_position(handler, member2_session, core_task_id, 30, 40)
  |> expect.equal(200)

  let member1_all_res =
    handler(
      simulate.request(http.Get, "/api/v1/me/task-positions")
      |> fx.with_session_cookies(member1_session),
    )

  expect.expect_status(member1_all_res, 200)

  decode_positions_xy_by_task(simulate.read_body(member1_all_res), core_task_id)
  |> expect.equal(#(10, 20))

  let member1_core_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/me/task-positions?project_id=" <> int.to_string(core_id),
      )
      |> fx.with_session_cookies(member1_session),
    )

  expect.expect_status(member1_core_res, 200)
  decode_position_task_ids(simulate.read_body(member1_core_res))
  |> expect.equal([core_task_id])

  let member2_all_res =
    handler(
      simulate.request(http.Get, "/api/v1/me/task-positions")
      |> fx.with_session_cookies(member2_session),
    )

  expect.expect_status(member2_all_res, 200)
  decode_positions_xy_by_task(simulate.read_body(member2_all_res), core_task_id)
  |> expect.equal(#(30, 40))
}

pub fn task_positions_reject_non_member_task_and_project_filter_test() {
  let app = fx.require_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_session = fx.require_login_session(handler, "admin@example.com")
  let project_id = fx.require_project(handler, admin_session, "Core")
  let type_id =
    fx.require_task_type(handler, admin_session, project_id, "Bug", "bug-ant")

  let member_id =
    fx.require_member_user(handler, db, "member@example.com", "inv_member")
  fx.require_member_user(handler, db, "outsider@example.com", "inv_out")

  fx.require_project_member(handler, admin_session, project_id, member_id)

  let outsider_session =
    fx.require_login_session(handler, "outsider@example.com")

  let task_id =
    fx.require_task(handler, admin_session, project_id, "Core", "", 3, type_id)

  let put_req =
    simulate.request(
      http.Put,
      "/api/v1/me/task-positions/" <> int.to_string(task_id),
    )
    |> fx.with_auth(outsider_session)
    |> simulate.json_body(
      json.object([#("x", json.int(1)), #("y", json.int(2))]),
    )

  let put_res = handler(put_req)
  expect.expect_status(put_res, 404)

  let filtered_req =
    simulate.request(
      http.Get,
      "/api/v1/me/task-positions?project_id=" <> int.to_string(project_id),
    )
    |> fx.with_session_cookies(outsider_session)

  let filtered_res = handler(filtered_req)
  expect.expect_status(filtered_res, 403)
}

fn decode_note_content(body: String) -> String {
  let note_decoder = {
    use content <- decode.field("content", decode.string)
    decode.success(content)
  }
  fx.require_data(body, decode.field("note", note_decoder, decode.success))
}

fn decode_created_note_contract(body: String) -> #(String, Bool, Bool) {
  let note_decoder = {
    use url <- decode.field("url", decode.string)
    use pinned <- decode.field("pinned", decode.bool)
    use updated_at <- decode.field("updated_at", decode.string)
    decode.success(#(url, pinned, updated_at != ""))
  }
  fx.require_data(body, decode.field("note", note_decoder, decode.success))
}

fn decode_note_pinned(body: String) -> Bool {
  let note_decoder = {
    use pinned <- decode.field("pinned", decode.bool)
    decode.success(pinned)
  }
  fx.require_data(body, decode.field("note", note_decoder, decode.success))
}

fn decode_note_list_contents(body: String) -> List(String) {
  fx.require_data_string_list_field(body, "notes", "content")
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
  fx.require_entity_id(body, fx.NoteEntity)
}

fn create_note_response(
  handler: fn(wisp.Request) -> wisp.Response,
  session: fx.Session,
  target: NoteTarget,
  content: String,
) -> wisp.Response {
  handler(
    simulate.request(http.Post, notes_path(target))
    |> fx.with_auth(session)
    |> simulate.json_body(json.object([#("content", json.string(content))])),
  )
}

fn create_note_with_url_response(
  handler: fn(wisp.Request) -> wisp.Response,
  session: fx.Session,
  target: NoteTarget,
  content: String,
  url: String,
) -> wisp.Response {
  handler(
    simulate.request(http.Post, notes_path(target))
    |> fx.with_auth(session)
    |> simulate.json_body(
      json.object([
        #("content", json.string(content)),
        #("url", json.string(url)),
      ]),
    ),
  )
}

fn list_notes_response(
  handler: fn(wisp.Request) -> wisp.Response,
  session: fx.Session,
  target: NoteTarget,
) -> wisp.Response {
  handler(
    simulate.request(http.Get, notes_path(target))
    |> fx.with_session_cookies(session),
  )
}

fn pin_note_response(
  handler: fn(wisp.Request) -> wisp.Response,
  session: fx.Session,
  target: NoteTarget,
  note_id: Int,
) -> wisp.Response {
  handler(
    simulate.request(http.Post, note_pin_path(target, note_id))
    |> fx.with_auth(session),
  )
}

fn unpin_note_response(
  handler: fn(wisp.Request) -> wisp.Response,
  session: fx.Session,
  target: NoteTarget,
  note_id: Int,
) -> wisp.Response {
  handler(
    simulate.request(http.Delete, note_pin_path(target, note_id))
    |> fx.with_auth(session),
  )
}

fn delete_note_response(
  handler: fn(wisp.Request) -> wisp.Response,
  session: fx.Session,
  target: NoteTarget,
  note_id: Int,
) -> wisp.Response {
  handler(
    simulate.request(http.Delete, note_path(target, note_id))
    |> fx.with_auth(session),
  )
}

fn notes_path(target: NoteTarget) -> String {
  case target {
    TaskNotes(task_id) -> "/api/v1/tasks/" <> int.to_string(task_id) <> "/notes"
    CardNotes(card_id) -> "/api/v1/cards/" <> int.to_string(card_id) <> "/notes"
  }
}

fn note_path(target: NoteTarget, note_id: Int) -> String {
  notes_path(target) <> "/" <> int.to_string(note_id)
}

fn note_pin_path(target: NoteTarget, note_id: Int) -> String {
  note_path(target, note_id) <> "/pin"
}

fn decode_card_has_new_notes(body: String, card_id: Int) -> Bool {
  let card_decoder = {
    use id <- decode.field("id", decode.int)
    use has_new_notes <- decode.field("has_new_notes", decode.bool)
    decode.success(#(id, has_new_notes))
  }
  let cards = fx.require_data_list(body, "cards", card_decoder)
  let assert Ok(#(_, has_new_notes)) =
    list.find(cards, fn(card) { card.0 == card_id })

  has_new_notes
}

fn decode_task_has_new_notes(body: String, task_id: Int) -> Bool {
  let task_decoder = {
    use id <- decode.field("id", decode.int)
    use has_new_notes <- decode.field("has_new_notes", decode.bool)
    decode.success(#(id, has_new_notes))
  }
  let tasks = fx.require_data_list(body, "tasks", task_decoder)
  let assert Ok(#(_, has_new_notes)) =
    list.find(tasks, fn(task) { task.0 == task_id })

  has_new_notes
}

fn decode_position_task_ids(body: String) -> List(Int) {
  fx.require_data_int_list_field(body, "positions", "task_id")
}

fn decode_positions_xy_by_task(body: String, task_id: Int) -> #(Int, Int) {
  let position_decoder = {
    use tid <- decode.field("task_id", decode.int)
    use x <- decode.field("x", decode.int)
    use y <- decode.field("y", decode.int)
    decode.success(#(tid, x, y))
  }
  let positions = fx.require_data_list(body, "positions", position_decoder)

  let assert Ok(#(_, x, y)) =
    positions
    |> list.find(fn(p) { p.0 == task_id })

  #(x, y)
}

fn upsert_position(
  handler: fn(wisp.Request) -> wisp.Response,
  session: fx.Session,
  task_id: Int,
  x: Int,
  y: Int,
) -> Int {
  let req =
    simulate.request(
      http.Put,
      "/api/v1/me/task-positions/" <> int.to_string(task_id),
    )
    |> fx.with_auth(session)
    |> simulate.json_body(
      json.object([#("x", json.int(x)), #("y", json.int(y))]),
    )

  handler(req).status
}

fn resource_view_fixture() -> ResourceViewFixture {
  let app = fx.require_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_session = fx.require_login_session(handler, "admin@example.com")
  let project_id = fx.require_project(handler, admin_session, "Core")
  let type_id =
    fx.require_task_type(handler, admin_session, project_id, "Bug", "bug-ant")

  let card_id = fx.require_card(handler, admin_session, project_id, "Card")

  let task_id =
    fx.require_task(handler, admin_session, project_id, "Task", "", 3, type_id)

  ResourceViewFixture(
    handler: handler,
    db: db,
    session: admin_session,
    card_id: card_id,
    task_id: task_id,
  )
}

fn create_logged_in_user(
  handler: fn(wisp.Request) -> wisp.Response,
  db: pog.Connection,
  email: String,
  invite_code: String,
) -> fx.Session {
  fx.require_member_user(handler, db, email, invite_code)
  fx.require_login_session(handler, email)
}
