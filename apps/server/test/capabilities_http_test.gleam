import fixtures
import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/string
import pog
import scrumbringer_server
import support/assertions as expect
import wisp
import wisp/simulate

pub fn capabilities_list_is_project_scoped_and_sorted_by_name_test() {
  let #(app, handler, admin_session) = fixtures.bootstrap() |> expect.ok
  let scrumbringer_server.App(db: db, ..) = app

  let project_id = fixtures.default_project_id(db) |> expect.ok

  create_capability(handler, admin_session, project_id, "Zulu")
  create_capability(handler, admin_session, project_id, "Alpha")

  let req =
    simulate.request(
      http.Get,
      "/api/v1/projects/" <> int.to_string(project_id) <> "/capabilities",
    )
    |> fixtures.with_auth(admin_session)

  let res = handler(req)
  expect.expect_status(res, 200)

  let names = decode_capability_names(simulate.read_body(res))
  names |> expect.equal(["Alpha", "Zulu"])
}

pub fn non_project_manager_cannot_create_capability_test() {
  let #(app, handler, admin_session) = fixtures.bootstrap() |> expect.ok
  let scrumbringer_server.App(db: db, ..) = app

  let project_id = fixtures.default_project_id(db) |> expect.ok

  let member_id =
    fixtures.create_member_user(handler, db, "member@example.com", "il_member")
    |> expect.ok
  fixtures.add_member(handler, admin_session, project_id, member_id, "member")
  |> expect.ok

  let member_session =
    fixtures.login(handler, "member@example.com", "passwordpassword")
    |> expect.ok

  let req =
    simulate.request(
      http.Post,
      "/api/v1/projects/" <> int.to_string(project_id) <> "/capabilities",
    )
    |> fixtures.with_auth(member_session)
    |> simulate.json_body(json.object([#("name", json.string("Nope"))]))

  let res = handler(req)
  expect.expect_status(res, 403)
  string.contains(simulate.read_body(res), "FORBIDDEN") |> expect.is_true
}

pub fn duplicate_capability_name_in_same_project_is_rejected_test() {
  let #(app, handler, session) = fixtures.bootstrap() |> expect.ok
  let scrumbringer_server.App(db: db, ..) = app

  let project_id = fixtures.default_project_id(db) |> expect.ok

  let first_req =
    simulate.request(
      http.Post,
      "/api/v1/projects/" <> int.to_string(project_id) <> "/capabilities",
    )
    |> fixtures.with_auth(session)
    |> simulate.json_body(json.object([#("name", json.string("UX"))]))

  let first_res = handler(first_req)
  expect.expect_status(first_res, 200)

  let second_req =
    simulate.request(
      http.Post,
      "/api/v1/projects/" <> int.to_string(project_id) <> "/capabilities",
    )
    |> fixtures.with_auth(session)
    |> simulate.json_body(json.object([#("name", json.string("UX"))]))

  let second_res = handler(second_req)
  expect.expect_status(second_res, 422)
  string.contains(simulate.read_body(second_res), "VALIDATION_ERROR")
  |> expect.is_true
}

pub fn member_capabilities_put_replaces_selection_and_supports_clearing_test() {
  let #(app, handler, admin_session) = fixtures.bootstrap() |> expect.ok
  let scrumbringer_server.App(db: db, ..) = app

  let project_id = fixtures.default_project_id(db) |> expect.ok

  create_capability(handler, admin_session, project_id, "Dev")
  create_capability(handler, admin_session, project_id, "PM")

  let dev_id =
    fixtures.query_int(db, "select id from capabilities where name = 'Dev'", [])
    |> expect.ok
  let pm_id =
    fixtures.query_int(db, "select id from capabilities where name = 'PM'", [])
    |> expect.ok

  let member_id =
    fixtures.create_member_user(handler, db, "member@example.com", "il_member")
    |> expect.ok
  fixtures.add_member(handler, admin_session, project_id, member_id, "member")
  |> expect.ok

  // Admin can set member capabilities
  let put_1 =
    put_member_capabilities(handler, admin_session, project_id, member_id, [
      dev_id,
    ])
  put_1 |> expect.equal([dev_id])

  let put_2 =
    put_member_capabilities(handler, admin_session, project_id, member_id, [
      pm_id,
    ])
  put_2 |> expect.equal([pm_id])

  let put_3 =
    put_member_capabilities(handler, admin_session, project_id, member_id, [])
  put_3 |> expect.equal([])

  let get_ids =
    get_member_capabilities(handler, admin_session, project_id, member_id)
  get_ids |> expect.equal([])
}

pub fn member_capabilities_cannot_select_capability_from_other_project_test() {
  let #(app, handler, admin_session) = fixtures.bootstrap() |> expect.ok
  let scrumbringer_server.App(db: db, ..) = app

  let project_id = fixtures.default_project_id(db) |> expect.ok

  create_capability(handler, admin_session, project_id, "Dev")
  let dev_id =
    fixtures.query_int(db, "select id from capabilities where name = 'Dev'", [])
    |> expect.ok

  let member_id =
    fixtures.create_member_user(handler, db, "member@example.com", "il_member")
    |> expect.ok
  fixtures.add_member(handler, admin_session, project_id, member_id, "member")
  |> expect.ok

  put_member_capabilities(handler, admin_session, project_id, member_id, [
    dev_id,
  ])
  |> expect.equal([dev_id])

  // Create another project with a capability
  let project2_id = insert_project(db, 1, "Project2")
  insert_capability_direct(db, project2_id, 200, "OtherCap")

  let invalid_req =
    simulate.request(
      http.Put,
      "/api/v1/projects/"
        <> int.to_string(project_id)
        <> "/members/"
        <> int.to_string(member_id)
        <> "/capabilities",
    )
    |> fixtures.with_auth(admin_session)
    |> simulate.json_body(
      json.object([
        #("capability_ids", json.array([200], of: json.int)),
      ]),
    )

  let invalid_res = handler(invalid_req)
  expect.expect_status(invalid_res, 422)

  let still_selected =
    get_member_capabilities(handler, admin_session, project_id, member_id)
  still_selected |> expect.equal([dev_id])
}

fn create_capability(
  handler: fn(wisp.Request) -> wisp.Response,
  session: fixtures.Session,
  project_id: Int,
  name: String,
) {
  let req =
    simulate.request(
      http.Post,
      "/api/v1/projects/" <> int.to_string(project_id) <> "/capabilities",
    )
    |> fixtures.with_auth(session)
    |> simulate.json_body(json.object([#("name", json.string(name))]))

  let res = handler(req)
  expect.expect_status(res, 200)
}

fn decode_capability_names(body: String) -> List(String) {
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let capability_decoder = {
    use name <- decode.field("name", decode.string)
    decode.success(name)
  }

  let data_decoder = {
    use capabilities <- decode.field(
      "capabilities",
      decode.list(capability_decoder),
    )
    decode.success(capabilities)
  }

  let response_decoder = {
    use capabilities <- decode.field("data", data_decoder)
    decode.success(capabilities)
  }

  let assert Ok(names) = decode.run(dynamic, response_decoder)
  names
}

fn put_member_capabilities(
  handler: fn(wisp.Request) -> wisp.Response,
  session: fixtures.Session,
  project_id: Int,
  user_id: Int,
  ids: List(Int),
) -> List(Int) {
  let req =
    simulate.request(
      http.Put,
      "/api/v1/projects/"
        <> int.to_string(project_id)
        <> "/members/"
        <> int.to_string(user_id)
        <> "/capabilities",
    )
    |> fixtures.with_auth(session)
    |> simulate.json_body(
      json.object([
        #("capability_ids", json.array(ids, of: json.int)),
      ]),
    )

  let res = handler(req)
  expect.expect_status(res, 200)

  decode_member_capabilities(simulate.read_body(res))
}

fn get_member_capabilities(
  handler: fn(wisp.Request) -> wisp.Response,
  session: fixtures.Session,
  project_id: Int,
  user_id: Int,
) -> List(Int) {
  let req =
    simulate.request(
      http.Get,
      "/api/v1/projects/"
        <> int.to_string(project_id)
        <> "/members/"
        <> int.to_string(user_id)
        <> "/capabilities",
    )
    |> fixtures.with_auth(session)

  let res = handler(req)
  expect.expect_status(res, 200)

  decode_member_capabilities(simulate.read_body(res))
}

fn decode_member_capabilities(body: String) -> List(Int) {
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let data_decoder = {
    use ids <- decode.field("capability_ids", decode.list(decode.int))
    decode.success(ids)
  }

  let response_decoder = {
    use ids <- decode.field("data", data_decoder)
    decode.success(ids)
  }

  let assert Ok(ids) = decode.run(dynamic, response_decoder)
  ids
}

fn insert_project(db: pog.Connection, org_id: Int, name: String) -> Int {
  fixtures.query_int(
    db,
    "insert into projects (org_id, name) values ($1, $2) returning id",
    [pog.int(org_id), pog.text(name)],
  )
  |> expect.ok
}

fn insert_capability_direct(
  db: pog.Connection,
  project_id: Int,
  cap_id: Int,
  name: String,
) {
  let assert Ok(_) =
    pog.query(
      "insert into capabilities (id, name, project_id) values ($1, $2, $3)",
    )
    |> pog.parameter(pog.int(cap_id))
    |> pog.parameter(pog.text(name))
    |> pog.parameter(pog.int(project_id))
    |> pog.execute(db)

  Nil
}
