import gleam/dynamic/decode
import gleam/erlang/charlist
import gleam/http
import gleam/http/request
import gleam/int
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

pub fn capabilities_list_is_project_scoped_and_sorted_by_name_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let project_id = get_default_project_id(db)

  let admin_login_res =
    login_as(handler, "admin@example.com", "passwordpassword")
  let admin_session = find_cookie_value(admin_login_res.headers, "sb_session")
  let admin_csrf = find_cookie_value(admin_login_res.headers, "sb_csrf")

  create_capability(handler, admin_session, admin_csrf, project_id, "Zulu")
  create_capability(handler, admin_session, admin_csrf, project_id, "Alpha")

  let req =
    simulate.request(
      http.Get,
      "/api/v1/projects/" <> int.to_string(project_id) <> "/capabilities",
    )
    |> request.set_cookie("sb_session", admin_session)
    |> request.set_cookie("sb_csrf", admin_csrf)

  let res = handler(req)
  res.status |> should.equal(200)

  let names = decode_capability_names(simulate.read_body(res))
  names |> should.equal(["Alpha", "Zulu"])
}

pub fn non_project_manager_cannot_create_capability_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let project_id = get_default_project_id(db)

  create_member_user(handler, db)
  add_member_to_project(db, project_id, get_member_user_id(db), "member")

  let member_login_res =
    login_as(handler, "member@example.com", "passwordpassword")
  let session = find_cookie_value(member_login_res.headers, "sb_session")
  let csrf = find_cookie_value(member_login_res.headers, "sb_csrf")

  let req =
    simulate.request(
      http.Post,
      "/api/v1/projects/" <> int.to_string(project_id) <> "/capabilities",
    )
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> request.set_header("X-CSRF", csrf)
    |> simulate.json_body(json.object([#("name", json.string("Nope"))]))

  let res = handler(req)
  res.status |> should.equal(403)
  string.contains(simulate.read_body(res), "FORBIDDEN") |> should.be_true
}

pub fn duplicate_capability_name_in_same_project_is_rejected_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let project_id = get_default_project_id(db)

  let admin_login_res =
    login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(admin_login_res.headers, "sb_session")
  let csrf = find_cookie_value(admin_login_res.headers, "sb_csrf")

  let first_req =
    simulate.request(
      http.Post,
      "/api/v1/projects/" <> int.to_string(project_id) <> "/capabilities",
    )
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> request.set_header("X-CSRF", csrf)
    |> simulate.json_body(json.object([#("name", json.string("UX"))]))

  let first_res = handler(first_req)
  first_res.status |> should.equal(200)

  let second_req =
    simulate.request(
      http.Post,
      "/api/v1/projects/" <> int.to_string(project_id) <> "/capabilities",
    )
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> request.set_header("X-CSRF", csrf)
    |> simulate.json_body(json.object([#("name", json.string("UX"))]))

  let second_res = handler(second_req)
  second_res.status |> should.equal(422)
  string.contains(simulate.read_body(second_res), "VALIDATION_ERROR")
  |> should.be_true
}

pub fn member_capabilities_put_replaces_selection_and_supports_clearing_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let project_id = get_default_project_id(db)

  let admin_login_res =
    login_as(handler, "admin@example.com", "passwordpassword")
  let admin_session = find_cookie_value(admin_login_res.headers, "sb_session")
  let admin_csrf = find_cookie_value(admin_login_res.headers, "sb_csrf")

  create_capability(handler, admin_session, admin_csrf, project_id, "Dev")
  create_capability(handler, admin_session, admin_csrf, project_id, "PM")

  let dev_id =
    single_int(db, "select id from capabilities where name = 'Dev'", [])
  let pm_id =
    single_int(db, "select id from capabilities where name = 'PM'", [])

  create_member_user(handler, db)
  let member_id = get_member_user_id(db)
  add_member_to_project(db, project_id, member_id, "member")

  // Admin can set member capabilities
  let put_1 =
    put_member_capabilities(
      handler,
      admin_session,
      admin_csrf,
      project_id,
      member_id,
      [dev_id],
    )
  put_1 |> should.equal([dev_id])

  let put_2 =
    put_member_capabilities(
      handler,
      admin_session,
      admin_csrf,
      project_id,
      member_id,
      [pm_id],
    )
  put_2 |> should.equal([pm_id])

  let put_3 =
    put_member_capabilities(
      handler,
      admin_session,
      admin_csrf,
      project_id,
      member_id,
      [],
    )
  put_3 |> should.equal([])

  let get_ids =
    get_member_capabilities(
      handler,
      admin_session,
      admin_csrf,
      project_id,
      member_id,
    )
  get_ids |> should.equal([])
}

pub fn member_capabilities_cannot_select_capability_from_other_project_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let project_id = get_default_project_id(db)

  let admin_login_res =
    login_as(handler, "admin@example.com", "passwordpassword")
  let admin_session = find_cookie_value(admin_login_res.headers, "sb_session")
  let admin_csrf = find_cookie_value(admin_login_res.headers, "sb_csrf")

  create_capability(handler, admin_session, admin_csrf, project_id, "Dev")
  let dev_id =
    single_int(db, "select id from capabilities where name = 'Dev'", [])

  create_member_user(handler, db)
  let member_id = get_member_user_id(db)
  add_member_to_project(db, project_id, member_id, "member")

  put_member_capabilities(
    handler,
    admin_session,
    admin_csrf,
    project_id,
    member_id,
    [dev_id],
  )
  |> should.equal([dev_id])

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
    |> request.set_cookie("sb_session", admin_session)
    |> request.set_cookie("sb_csrf", admin_csrf)
    |> request.set_header("X-CSRF", admin_csrf)
    |> simulate.json_body(
      json.object([
        #("capability_ids", json.array([200], of: json.int)),
      ]),
    )

  let invalid_res = handler(invalid_req)
  invalid_res.status |> should.equal(422)

  let still_selected =
    get_member_capabilities(
      handler,
      admin_session,
      admin_csrf,
      project_id,
      member_id,
    )
  still_selected |> should.equal([dev_id])
}

fn create_capability(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
  project_id: Int,
  name: String,
) {
  let req =
    simulate.request(
      http.Post,
      "/api/v1/projects/" <> int.to_string(project_id) <> "/capabilities",
    )
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

fn put_member_capabilities(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
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

  decode_member_capabilities(simulate.read_body(res))
}

fn get_member_capabilities(
  handler: fn(wisp.Request) -> wisp.Response,
  session: String,
  csrf: String,
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
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)

  let res = handler(req)
  res.status |> should.equal(200)

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
      "TRUNCATE project_member_capabilities, capabilities, project_members, org_invite_links, org_invites, users, projects, organizations RESTART IDENTITY CASCADE",
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

fn get_default_project_id(db: pog.Connection) -> Int {
  single_int(db, "select id from projects where org_id = 1 limit 1", [])
}

fn get_member_user_id(db: pog.Connection) -> Int {
  single_int(
    db,
    "select id from users where email = 'member@example.com'",
    [],
  )
}

fn add_member_to_project(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
  role: String,
) {
  let assert Ok(_) =
    pog.query(
      "insert into project_members (project_id, user_id, role) values ($1, $2, $3)",
    )
    |> pog.parameter(pog.int(project_id))
    |> pog.parameter(pog.int(user_id))
    |> pog.parameter(pog.text(role))
    |> pog.execute(db)

  Nil
}

fn insert_project(db: pog.Connection, org_id: Int, name: String) -> Int {
  single_int(
    db,
    "insert into projects (org_id, name) values ($1, $2) returning id",
    [pog.int(org_id), pog.text(name)],
  )
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
