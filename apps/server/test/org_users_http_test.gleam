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

pub fn org_users_requires_admin_or_project_admin_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_login_res =
    login_as(handler, "admin@example.com", "passwordpassword")
  let admin_session = find_cookie_value(admin_login_res.headers, "sb_session")

  let member_email = "member@example.com"
  create_user_via_invite(handler, db, member_email, "il_member", 1)

  let member_login_res = login_as(handler, member_email, "passwordpassword")
  let member_session = find_cookie_value(member_login_res.headers, "sb_session")

  let member_req =
    simulate.request(http.Get, "/api/v1/org/users")
    |> request.set_cookie("sb_session", member_session)

  let member_res = handler(member_req)
  member_res.status |> should.equal(403)

  let admin_req =
    simulate.request(http.Get, "/api/v1/org/users")
    |> request.set_cookie("sb_session", admin_session)

  let admin_res = handler(admin_req)
  admin_res.status |> should.equal(200)
}

pub fn org_users_sorted_search_and_empty_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")

  create_user_via_invite(handler, db, "z@example.com", "il_z", 1)
  create_user_via_invite(handler, db, "aaa@example.com", "il_a", 1)

  let res =
    handler(
      simulate.request(http.Get, "/api/v1/org/users")
      |> request.set_cookie("sb_session", session),
    )

  res.status |> should.equal(200)
  decode_user_emails(simulate.read_body(res))
  |> should.equal(["aaa@example.com", "admin@example.com", "z@example.com"])

  let search_res =
    handler(
      simulate.request(http.Get, "/api/v1/org/users?q=z@")
      |> request.set_cookie("sb_session", session),
    )

  search_res.status |> should.equal(200)
  decode_user_emails(simulate.read_body(search_res))
  |> should.equal(["z@example.com"])

  let empty_res =
    handler(
      simulate.request(http.Get, "/api/v1/org/users?q=nomatch")
      |> request.set_cookie("sb_session", session),
    )

  empty_res.status |> should.equal(200)
  decode_user_emails(simulate.read_body(empty_res)) |> should.equal([])

  let empty_q_res =
    handler(
      simulate.request(http.Get, "/api/v1/org/users?q=")
      |> request.set_cookie("sb_session", session),
    )

  empty_q_res.status |> should.equal(200)
  decode_user_emails(simulate.read_body(empty_q_res))
  |> should.equal(["aaa@example.com", "admin@example.com", "z@example.com"])
}

pub fn org_users_allows_project_admin_and_scopes_org_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let org2_id = insert_org(db, "Org2")

  create_user_via_invite(handler, db, "b@org2.com", "il_b", org2_id)
  create_user_via_invite(handler, db, "a@org2.com", "il_a2", org2_id)

  let user2_id =
    single_int(db, "select id from users where email = 'b@org2.com'", [])

  let project2_id = insert_project(db, org2_id, "P2")
  insert_project_member(db, project2_id, user2_id, "manager")

  let user2_login_res = login_as(handler, "b@org2.com", "passwordpassword")
  let user2_session = find_cookie_value(user2_login_res.headers, "sb_session")

  let user2_res =
    handler(
      simulate.request(http.Get, "/api/v1/org/users")
      |> request.set_cookie("sb_session", user2_session),
    )

  user2_res.status |> should.equal(200)
  decode_user_emails(simulate.read_body(user2_res))
  |> should.equal(["a@org2.com", "b@org2.com"])

  let admin_login_res =
    login_as(handler, "admin@example.com", "passwordpassword")
  let admin_session = find_cookie_value(admin_login_res.headers, "sb_session")

  let admin_res =
    handler(
      simulate.request(http.Get, "/api/v1/org/users")
      |> request.set_cookie("sb_session", admin_session),
    )

  admin_res.status |> should.equal(200)
  decode_user_emails(simulate.read_body(admin_res))
  |> should.equal(["admin@example.com"])
}

pub fn patch_org_user_role_requires_org_admin_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_login_res =
    login_as(handler, "admin@example.com", "passwordpassword")

  let admin_session = find_cookie_value(admin_login_res.headers, "sb_session")
  let admin_csrf = find_cookie_value(admin_login_res.headers, "sb_csrf")

  let member_email = "member@example.com"
  create_user_via_invite(handler, db, member_email, "il_member", 1)

  let member_login_res = login_as(handler, member_email, "passwordpassword")
  let member_session = find_cookie_value(member_login_res.headers, "sb_session")
  let member_csrf = find_cookie_value(member_login_res.headers, "sb_csrf")

  let member_id =
    single_int(db, "select id from users where email = $1", [
      pog.text(member_email),
    ])

  let member_req =
    simulate.request(
      http.Patch,
      "/api/v1/org/users/" <> int.to_string(member_id),
    )
    |> request.set_cookie("sb_session", member_session)
    |> request.set_cookie("sb_csrf", member_csrf)
    |> request.set_header("X-CSRF", member_csrf)
    |> simulate.json_body(json.object([#("org_role", json.string("admin"))]))

  let member_res = handler(member_req)
  member_res.status |> should.equal(403)

  let admin_req =
    simulate.request(
      http.Patch,
      "/api/v1/org/users/" <> int.to_string(member_id),
    )
    |> request.set_cookie("sb_session", admin_session)
    |> request.set_cookie("sb_csrf", admin_csrf)
    |> request.set_header("X-CSRF", admin_csrf)
    |> simulate.json_body(json.object([#("org_role", json.string("admin"))]))

  let admin_res = handler(admin_req)
  admin_res.status |> should.equal(200)
}

pub fn patch_org_user_role_rejects_demoting_last_org_admin_test() {
  let app = bootstrap_app()
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  let req =
    simulate.request(http.Patch, "/api/v1/org/users/1")
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> request.set_header("X-CSRF", csrf)
    |> simulate.json_body(json.object([#("org_role", json.string("member"))]))

  let res = handler(req)
  res.status |> should.equal(409)
  string.contains(simulate.read_body(res), "CONFLICT_LAST_ORG_ADMIN")
  |> should.be_true
}

pub fn delete_org_user_requires_admin_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_login_res =
    login_as(handler, "admin@example.com", "passwordpassword")
  let admin_session = find_cookie_value(admin_login_res.headers, "sb_session")
  let admin_csrf = find_cookie_value(admin_login_res.headers, "sb_csrf")

  let member_email = "member_delete@example.com"
  create_user_via_invite(handler, db, member_email, "il_member_delete", 1)
  let member_id =
    single_int(db, "select id from users where email = $1", [
      pog.text(member_email),
    ])

  let member_login_res = login_as(handler, member_email, "passwordpassword")
  let member_session = find_cookie_value(member_login_res.headers, "sb_session")
  let member_csrf = find_cookie_value(member_login_res.headers, "sb_csrf")

  let member_req =
    simulate.request(
      http.Delete,
      "/api/v1/org/users/" <> int.to_string(member_id),
    )
    |> request.set_cookie("sb_session", member_session)
    |> request.set_cookie("sb_csrf", member_csrf)
    |> request.set_header("X-CSRF", member_csrf)

  let member_res = handler(member_req)
  member_res.status |> should.equal(403)

  let admin_req =
    simulate.request(
      http.Delete,
      "/api/v1/org/users/" <> int.to_string(member_id),
    )
    |> request.set_cookie("sb_session", admin_session)
    |> request.set_cookie("sb_csrf", admin_csrf)
    |> request.set_header("X-CSRF", admin_csrf)

  let admin_res = handler(admin_req)
  admin_res.status |> should.equal(204)
}

pub fn delete_org_user_removes_from_listing_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  let member_email = "member_delete_list@example.com"
  create_user_via_invite(handler, db, member_email, "il_member_delete_list", 1)
  let member_id =
    single_int(db, "select id from users where email = $1", [
      pog.text(member_email),
    ])

  let delete_req =
    simulate.request(
      http.Delete,
      "/api/v1/org/users/" <> int.to_string(member_id),
    )
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> request.set_header("X-CSRF", csrf)

  let delete_res = handler(delete_req)
  delete_res.status |> should.equal(204)

  let list_res =
    handler(
      simulate.request(http.Get, "/api/v1/org/users")
      |> request.set_cookie("sb_session", session),
    )

  list_res.status |> should.equal(200)
  decode_user_emails(simulate.read_body(list_res))
  |> list.contains(member_email)
  |> should.be_false
}

pub fn delete_org_user_rejects_self_delete_test() {
  let app = bootstrap_app()
  let handler = scrumbringer_server.handler(app)

  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  let req =
    simulate.request(http.Delete, "/api/v1/org/users/1")
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> request.set_header("X-CSRF", csrf)

  let res = handler(req)
  res.status |> should.equal(409)
  string.contains(simulate.read_body(res), "CONFLICT_SELF_DELETE")
  |> should.be_true
}

// =============================================================================
// Story 4.3 Tests: User Project Role Management
// =============================================================================

/// AC13: POST accepts optional role parameter
pub fn add_user_to_project_with_role_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  // Login as admin
  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  // Create a member user
  create_user_via_invite(handler, db, "member@example.com", "il_member", 1)
  let member_id =
    single_int(
      db,
      "select id from users where email = 'member@example.com'",
      [],
    )

  // Create a project
  let project_id = insert_project(db, 1, "Test Project")
  insert_project_member(db, project_id, 1, "manager")
  // admin is manager

  // Add user to project as manager
  let req =
    simulate.request(
      http.Post,
      "/api/v1/org/users/" <> int.to_string(member_id) <> "/projects",
    )
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> request.set_header("X-CSRF", csrf)
    |> simulate.json_body(
      json.object([
        #("project_id", json.int(project_id)),
        #("role", json.string("manager")),
      ]),
    )

  let res = handler(req)
  res.status |> should.equal(200)

  // Verify role in response
  let body = simulate.read_body(res)
  string.contains(body, "\"role\":\"manager\"") |> should.be_true
}

/// AC13: POST defaults to member if role not provided
pub fn add_user_to_project_defaults_to_member_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  // Login as admin
  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  // Create a member user
  create_user_via_invite(handler, db, "member2@example.com", "il_member2", 1)
  let member_id =
    single_int(
      db,
      "select id from users where email = 'member2@example.com'",
      [],
    )

  // Create a project
  let project_id = insert_project(db, 1, "Test Project 2")
  insert_project_member(db, project_id, 1, "manager")
  // admin is manager

  // Add user to project without specifying role
  let req =
    simulate.request(
      http.Post,
      "/api/v1/org/users/" <> int.to_string(member_id) <> "/projects",
    )
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> request.set_header("X-CSRF", csrf)
    |> simulate.json_body(
      json.object([
        #("project_id", json.int(project_id)),
      ]),
    )

  let res = handler(req)
  res.status |> should.equal(200)

  // Verify role defaults to member
  let body = simulate.read_body(res)
  string.contains(body, "\"role\":\"member\"") |> should.be_true
}

/// AC14: PATCH changes user's role in a project
pub fn update_user_project_role_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  // Login as admin
  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  // Create a member user
  create_user_via_invite(handler, db, "pmember@example.com", "il_pmember", 1)
  let member_id =
    single_int(
      db,
      "select id from users where email = 'pmember@example.com'",
      [],
    )

  // Create a project with admin as manager and member user as member
  let project_id = insert_project(db, 1, "Test Project 3")
  insert_project_member(db, project_id, 1, "manager")
  // admin is manager
  insert_project_member(db, project_id, member_id, "member")

  // Change member to manager
  let req =
    simulate.request(
      http.Patch,
      "/api/v1/org/users/"
        <> int.to_string(member_id)
        <> "/projects/"
        <> int.to_string(project_id),
    )
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> request.set_header("X-CSRF", csrf)
    |> simulate.json_body(json.object([#("role", json.string("manager"))]))

  let res = handler(req)
  res.status |> should.equal(200)

  // Verify role change in response
  let body = simulate.read_body(res)
  string.contains(body, "\"role\":\"manager\"") |> should.be_true
  string.contains(body, "\"previous_role\":\"member\"") |> should.be_true
}

/// AC15: PATCH returns 422 when trying to demote last manager
pub fn update_user_project_role_last_manager_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  // Login as admin
  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  // Create a project with admin as the only manager
  let project_id = insert_project(db, 1, "Test Project 4")
  insert_project_member(db, project_id, 1, "manager")
  // admin is only manager

  // Try to demote admin (last manager)
  let req =
    simulate.request(
      http.Patch,
      "/api/v1/org/users/1/projects/" <> int.to_string(project_id),
    )
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> request.set_header("X-CSRF", csrf)
    |> simulate.json_body(json.object([#("role", json.string("member"))]))

  let res = handler(req)
  res.status |> should.equal(422)

  // Verify error message
  let body = simulate.read_body(res)
  string.contains(body, "LAST_MANAGER") |> should.be_true
}

/// AC14: PATCH returns 404 when user is not a member
pub fn update_user_project_role_not_member_test() {
  let app = bootstrap_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  // Login as admin
  let login_res = login_as(handler, "admin@example.com", "passwordpassword")
  let session = find_cookie_value(login_res.headers, "sb_session")
  let csrf = find_cookie_value(login_res.headers, "sb_csrf")

  // Create a member user (NOT in the project)
  create_user_via_invite(
    handler,
    db,
    "notmember@example.com",
    "il_notmember",
    1,
  )
  let member_id =
    single_int(
      db,
      "select id from users where email = 'notmember@example.com'",
      [],
    )

  // Create a project
  let project_id = insert_project(db, 1, "Test Project 5")
  insert_project_member(db, project_id, 1, "manager")
  // admin is manager

  // Try to change role for non-member
  let req =
    simulate.request(
      http.Patch,
      "/api/v1/org/users/"
        <> int.to_string(member_id)
        <> "/projects/"
        <> int.to_string(project_id),
    )
    |> request.set_cookie("sb_session", session)
    |> request.set_cookie("sb_csrf", csrf)
    |> request.set_header("X-CSRF", csrf)
    |> simulate.json_body(json.object([#("role", json.string("manager"))]))

  let res = handler(req)
  res.status |> should.equal(404)

  // Verify error message
  let body = simulate.read_body(res)
  string.contains(body, "NOT_FOUND") |> should.be_true
}

fn decode_user_emails(body: String) -> List(String) {
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let user_decoder = {
    use email <- decode.field("email", decode.string)
    decode.success(email)
  }

  let data_decoder = {
    use users <- decode.field("users", decode.list(user_decoder))
    decode.success(users)
  }

  let response_decoder = {
    use users <- decode.field("data", data_decoder)
    decode.success(users)
  }

  let assert Ok(users) = decode.run(dynamic, response_decoder)
  users
}

fn create_user_via_invite(
  handler: fn(wisp.Request) -> wisp.Response,
  db: pog.Connection,
  email: String,
  invite_token: String,
  org_id: Int,
) {
  insert_invite_link_active(db, invite_token, email, org_id)

  let req =
    simulate.request(http.Post, "/api/v1/auth/register")
    |> simulate.json_body(
      json.object([
        #("password", json.string("passwordpassword")),
        #("invite_token", json.string(invite_token)),
      ]),
    )

  let res = handler(req)
  res.status |> should.equal(200)
}

fn insert_invite_link_active(
  db: pog.Connection,
  token: String,
  email: String,
  org_id: Int,
) {
  let assert Ok(_) =
    pog.query(
      "insert into org_invite_links (org_id, email, token, created_by) values ($1, $2, $3, 1)",
    )
    |> pog.parameter(pog.int(org_id))
    |> pog.parameter(pog.text(email))
    |> pog.parameter(pog.text(token))
    |> pog.execute(db)

  Nil
}

fn insert_org(db: pog.Connection, name: String) -> Int {
  let decoder = {
    use id <- decode.field(0, decode.int)
    decode.success(id)
  }

  let assert Ok(pog.Returned(rows: [id, ..], ..)) =
    pog.query("insert into organizations (name) values ($1) returning id")
    |> pog.parameter(pog.text(name))
    |> pog.returning(decoder)
    |> pog.execute(db)

  id
}

fn insert_project(db: pog.Connection, org_id: Int, name: String) -> Int {
  let decoder = {
    use id <- decode.field(0, decode.int)
    decode.success(id)
  }

  let assert Ok(pog.Returned(rows: [id, ..], ..)) =
    pog.query(
      "insert into projects (org_id, name) values ($1, $2) returning id",
    )
    |> pog.parameter(pog.int(org_id))
    |> pog.parameter(pog.text(name))
    |> pog.returning(decoder)
    |> pog.execute(db)

  id
}

fn insert_project_member(
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
    handler(
      simulate.request(http.Post, "/api/v1/auth/register")
      |> simulate.json_body(
        json.object([
          #("email", json.string("admin@example.com")),
          #("password", json.string("passwordpassword")),
          #("org_name", json.string("Acme")),
        ]),
      ),
    )

  res.status |> should.equal(200)

  app
}

fn new_test_app() -> scrumbringer_server.App {
  let database_url = require_database_url()
  let assert Ok(app) = scrumbringer_server.new_app(secret, database_url)
  app
}

fn reset_db(db: pog.Connection) {
  let assert Ok(_) =
    pog.query(
      "TRUNCATE project_members, org_invite_links, org_invites, users, projects, organizations RESTART IDENTITY CASCADE",
    )
    |> pog.execute(db)

  Nil
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
