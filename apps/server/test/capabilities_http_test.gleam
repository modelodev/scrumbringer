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

pub fn capabilities_list_is_org_scoped_and_sorted_by_name_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_login_res =
    login_as(handler, "admin@example.com", "passwordpassword")
  let admin_session = find_cookie_value(admin_login_res.headers, "sb_session")
  let admin_csrf = find_cookie_value(admin_login_res.headers, "sb_csrf")

  create_capability(handler, admin_session, admin_csrf, "Zulu")
  create_capability(handler, admin_session, admin_csrf, "Alpha")

  create_member_user(handler, db)
  let member_login_res =
    login_as(handler, "member@example.com", "passwordpassword")
  let member_session = find_cookie_value(member_login_res.headers, "sb_session")
  let member_csrf = find_cookie_value(member_login_res.headers, "sb_csrf")

  insert_other_org_capability(db, 2, 200)

  let req =
    simulate.request(http.Get, "/api/v1/capabilities")
    |> request.set_cookie("sb_session", member_session)
    |> request.set_cookie("sb_csrf", member_csrf)

  let res = handler(req)
  res.status |> should.equal(200)

  let names = decode_capability_names(simulate.read_body(res))
  names |> should.equal(["Alpha", "Zulu"])
}

pub fn non_org_admin_cannot_create_capability_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  create_member_user(handler, db)

  let member_login_res =
    login_as(handler, "member@example.com", "passwordpassword")
  let session = find_cookie_value(member_login_res.headers, "sb_session")
  let csrf = find_cookie_value(member_login_res.headers, "sb_csrf")

  let req =
    simulate.request(http.Post, "/api/v1/capabilities")
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> request.set_header("X-CSRF", csrf)
    |> simulate.json_body(json.object([#("name", json.string("Nope"))]))

  let res = handler(req)
  res.status |> should.equal(403)
  string.contains(simulate.read_body(res), "FORBIDDEN") |> should.be_true
}

pub fn duplicate_capability_name_in_same_org_is_rejected_test() {
  let app = bootstrap_app()
  let handler = scrumbringer_server.handler(app)

  let admin_login_res =
    login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(admin_login_res.headers, "sb_session")
  let csrf = find_cookie_value(admin_login_res.headers, "sb_csrf")

  let first_req =
    simulate.request(http.Post, "/api/v1/capabilities")
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> request.set_header("X-CSRF", csrf)
    |> simulate.json_body(json.object([#("name", json.string("UX"))]))

  let first_res = handler(first_req)
  first_res.status |> should.equal(200)

  let second_req =
    simulate.request(http.Post, "/api/v1/capabilities")
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> request.set_header("X-CSRF", csrf)
    |> simulate.json_body(json.object([#("name", json.string("UX"))]))

  let second_res = handler(second_req)
  second_res.status |> should.equal(422)
  string.contains(simulate.read_body(second_res), "VALIDATION_ERROR")
  |> should.be_true
}

pub fn me_capabilities_put_replaces_selection_and_supports_clearing_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_login_res =
    login_as(handler, "admin@example.com", "passwordpassword")
  let admin_session = find_cookie_value(admin_login_res.headers, "sb_session")
  let admin_csrf = find_cookie_value(admin_login_res.headers, "sb_csrf")

  create_capability(handler, admin_session, admin_csrf, "Dev")
  create_capability(handler, admin_session, admin_csrf, "PM")

  let dev_id =
    single_int(db, "select id from capabilities where name = 'Dev'", [])
  let pm_id =
    single_int(db, "select id from capabilities where name = 'PM'", [])

  create_member_user(handler, db)
  let login_res = login_as(handler, "member@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  let put_1 = put_me_capabilities(handler, session, csrf, [dev_id])
  put_1 |> should.equal([dev_id])

  let put_2 = put_me_capabilities(handler, session, csrf, [pm_id])
  put_2 |> should.equal([pm_id])

  let put_3 = put_me_capabilities(handler, session, csrf, [])
  put_3 |> should.equal([])

  let get_ids = get_me_capabilities(handler, session, csrf)
  get_ids |> should.equal([])
}

pub fn me_capabilities_cannot_select_capability_from_other_org_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_login_res =
    login_as(handler, "admin@example.com", "passwordpassword")
  let admin_session = find_cookie_value(admin_login_res.headers, "sb_session")
  let admin_csrf = find_cookie_value(admin_login_res.headers, "sb_csrf")

  create_capability(handler, admin_session, admin_csrf, "Dev")
  let dev_id =
    single_int(db, "select id from capabilities where name = 'Dev'", [])

  create_member_user(handler, db)
  let login_res = login_as(handler, "member@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  put_me_capabilities(handler, session, csrf, [dev_id])
  |> should.equal([dev_id])

  insert_other_org_capability(db, 2, 200)

  let invalid_req =
    simulate.request(http.Put, "/api/v1/me/capabilities")
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> request.set_header("X-CSRF", csrf)
    |> simulate.json_body(
      json.object([
        #("capability_ids", json.array([200], of: json.int)),
      ]),
    )

  let invalid_res = handler(invalid_req)
  invalid_res.status |> should.equal(422)

  let still_selected = get_me_capabilities(handler, session, csrf)
  still_selected |> should.equal([dev_id])
}

fn create_capability(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  name: String,
) {
  let req =
    simulate.request(http.Post, "/api/v1/capabilities")
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> request.set_header("X-CSRF", csrf)
    |> simulate.json_body(json.object([#("name", json.string(name))]))

  let res = handler(req)
  res.status |> should.equal(200)
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

fn put_me_capabilities(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  ids: List(Int),
) -> List(Int) {
  let req =
    simulate.request(http.Put, "/api/v1/me/capabilities")
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> request.set_header("X-CSRF", csrf)
    |> simulate.json_body(
      json.object([
        #("capability_ids", json.array(ids, of: json.int)),
      ]),
    )

  let res = handler(req)
  res.status |> should.equal(200)

  decode_me_capabilities(simulate.read_body(res))
}

fn get_me_capabilities(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
) -> List(Int) {
  let req =
    simulate.request(http.Get, "/api/v1/me/capabilities")
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)

  let res = handler(req)
  res.status |> should.equal(200)

  decode_me_capabilities(simulate.read_body(res))
}

fn decode_me_capabilities(body: String) -> List(Int) {
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

fn create_member_user(
  handler: fn(wisp.Request) -> wisp.Response,
  db: pog.Connection,
) {
  insert_invite_link_active(db, "il_member", "member@example.com")

  let req =
    simulate.request(http.Post, "/api/v1/auth/register")
    |> simulate.json_body(
      json.object([
        #("password", json.string("passwordpassword")),
        #("invite_token", json.string("il_member")),
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

fn insert_other_org_capability(db: pog.Connection, org_id: Int, cap_id: Int) {
  let assert Ok(_) =
    pog.query("insert into organizations (id, name) values ($1, 'Other')")
    |> pog.parameter(pog.int(org_id))
    |> pog.execute(db)

  let assert Ok(_) =
    pog.query(
      "insert into capabilities (id, name, org_id) values ($1, 'OtherCap', $2)",
    )
    |> pog.parameter(pog.int(cap_id))
    |> pog.parameter(pog.int(org_id))
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

fn getenv(key: String, default: String) -> String {
  getenv_charlist(charlist.from_string(key), charlist.from_string(default))
  |> charlist.to_string
}

@external(erlang, "os", "getenv")
fn getenv_charlist(
  key: charlist.Charlist,
  default: charlist.Charlist,
) -> charlist.Charlist
