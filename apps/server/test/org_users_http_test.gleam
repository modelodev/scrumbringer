import fixtures
import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/list
import gleam/string
import pog
import scrumbringer_server
import support/assertions as expect
import wisp
import wisp/simulate

pub fn org_users_requires_admin_or_project_admin_test() {
  let #(app, handler, admin_session) = fixtures.bootstrap() |> expect.ok
  let scrumbringer_server.App(db: db, ..) = app

  let member_email = "member@example.com"
  create_user_via_invite(handler, db, member_email, "il_member", 1)

  let member_session =
    fixtures.login(handler, member_email, "passwordpassword")
    |> expect.ok

  let member_req =
    simulate.request(http.Get, "/api/v1/org/users")
    |> fixtures.with_auth(member_session)

  let member_res = handler(member_req)
  expect.expect_status(member_res, 403)

  let admin_req =
    simulate.request(http.Get, "/api/v1/org/users")
    |> fixtures.with_auth(admin_session)

  let admin_res = handler(admin_req)
  expect.expect_status(admin_res, 200)
}

pub fn org_users_sorted_search_and_empty_test() {
  let #(app, handler, session) = fixtures.bootstrap() |> expect.ok
  let scrumbringer_server.App(db: db, ..) = app

  create_user_via_invite(handler, db, "z@example.com", "il_z", 1)
  create_user_via_invite(handler, db, "aaa@example.com", "il_a", 1)

  let res =
    handler(
      simulate.request(http.Get, "/api/v1/org/users")
      |> fixtures.with_auth(session),
    )

  expect.expect_status(res, 200)
  decode_user_emails(simulate.read_body(res))
  |> expect.equal(["aaa@example.com", "admin@example.com", "z@example.com"])

  let search_res =
    handler(
      simulate.request(http.Get, "/api/v1/org/users?q=z@")
      |> fixtures.with_auth(session),
    )

  expect.expect_status(search_res, 200)
  decode_user_emails(simulate.read_body(search_res))
  |> expect.equal(["z@example.com"])

  let empty_res =
    handler(
      simulate.request(http.Get, "/api/v1/org/users?q=nomatch")
      |> fixtures.with_auth(session),
    )

  expect.expect_status(empty_res, 200)
  decode_user_emails(simulate.read_body(empty_res)) |> expect.equal([])

  let empty_q_res =
    handler(
      simulate.request(http.Get, "/api/v1/org/users?q=")
      |> fixtures.with_auth(session),
    )

  expect.expect_status(empty_q_res, 200)
  decode_user_emails(simulate.read_body(empty_q_res))
  |> expect.equal(["aaa@example.com", "admin@example.com", "z@example.com"])
}

pub fn org_users_allows_project_admin_and_scopes_org_test() {
  let #(app, handler, admin_session) = fixtures.bootstrap() |> expect.ok
  let scrumbringer_server.App(db: db, ..) = app

  let org2_id = insert_org(db, "Org2")

  create_user_via_invite(handler, db, "b@org2.com", "il_b", org2_id)
  create_user_via_invite(handler, db, "a@org2.com", "il_a2", org2_id)

  let user2_id =
    fixtures.user_id_by_email(db, "b@org2.com")
    |> expect.ok

  let project2_id = insert_project(db, org2_id, "P2")
  insert_project_member(db, project2_id, user2_id, "manager")

  let user2_session =
    fixtures.login(handler, "b@org2.com", "passwordpassword")
    |> expect.ok

  let user2_res =
    handler(
      simulate.request(http.Get, "/api/v1/org/users")
      |> fixtures.with_auth(user2_session),
    )

  expect.expect_status(user2_res, 200)
  decode_user_emails(simulate.read_body(user2_res))
  |> expect.equal(["a@org2.com", "b@org2.com"])

  let admin_res =
    handler(
      simulate.request(http.Get, "/api/v1/org/users")
      |> fixtures.with_auth(admin_session),
    )

  expect.expect_status(admin_res, 200)
  decode_user_emails(simulate.read_body(admin_res))
  |> expect.equal(["admin@example.com"])
}

pub fn patch_org_user_role_requires_org_admin_test() {
  let #(app, handler, admin_session) = fixtures.bootstrap() |> expect.ok
  let scrumbringer_server.App(db: db, ..) = app

  let member_email = "member@example.com"
  create_user_via_invite(handler, db, member_email, "il_member", 1)

  let member_session =
    fixtures.login(handler, member_email, "passwordpassword")
    |> expect.ok

  let member_id =
    fixtures.user_id_by_email(db, member_email)
    |> expect.ok

  let member_req =
    simulate.request(
      http.Patch,
      "/api/v1/org/users/" <> int.to_string(member_id),
    )
    |> fixtures.with_auth(member_session)
    |> simulate.json_body(json.object([#("org_role", json.string("admin"))]))

  let member_res = handler(member_req)
  expect.expect_status(member_res, 403)

  let admin_req =
    simulate.request(
      http.Patch,
      "/api/v1/org/users/" <> int.to_string(member_id),
    )
    |> fixtures.with_auth(admin_session)
    |> simulate.json_body(json.object([#("org_role", json.string("admin"))]))

  let admin_res = handler(admin_req)
  expect.expect_status(admin_res, 200)
}

pub fn patch_org_user_role_rejects_demoting_last_org_admin_test() {
  let #(_, handler, session) = fixtures.bootstrap() |> expect.ok

  let req =
    simulate.request(http.Patch, "/api/v1/org/users/1")
    |> fixtures.with_auth(session)
    |> simulate.json_body(json.object([#("org_role", json.string("member"))]))

  let res = handler(req)
  expect.expect_status(res, 409)
  string.contains(simulate.read_body(res), "CONFLICT_LAST_ORG_ADMIN")
  |> expect.is_true
}

pub fn delete_org_user_requires_admin_test() {
  let #(app, handler, admin_session) = fixtures.bootstrap() |> expect.ok
  let scrumbringer_server.App(db: db, ..) = app

  let member_email = "member_delete@example.com"
  create_user_via_invite(handler, db, member_email, "il_member_delete", 1)
  let member_id =
    fixtures.user_id_by_email(db, member_email)
    |> expect.ok

  let member_session =
    fixtures.login(handler, member_email, "passwordpassword")
    |> expect.ok

  let member_req =
    simulate.request(
      http.Delete,
      "/api/v1/org/users/" <> int.to_string(member_id),
    )
    |> fixtures.with_auth(member_session)

  let member_res = handler(member_req)
  expect.expect_status(member_res, 403)

  let admin_req =
    simulate.request(
      http.Delete,
      "/api/v1/org/users/" <> int.to_string(member_id),
    )
    |> fixtures.with_auth(admin_session)

  let admin_res = handler(admin_req)
  expect.expect_status(admin_res, 204)
}

pub fn delete_org_user_removes_from_listing_test() {
  let #(app, handler, session) = fixtures.bootstrap() |> expect.ok
  let scrumbringer_server.App(db: db, ..) = app

  let member_email = "member_delete_list@example.com"
  create_user_via_invite(handler, db, member_email, "il_member_delete_list", 1)
  let member_id =
    fixtures.user_id_by_email(db, member_email)
    |> expect.ok

  let delete_req =
    simulate.request(
      http.Delete,
      "/api/v1/org/users/" <> int.to_string(member_id),
    )
    |> fixtures.with_auth(session)

  let delete_res = handler(delete_req)
  expect.expect_status(delete_res, 204)

  let list_res =
    handler(
      simulate.request(http.Get, "/api/v1/org/users")
      |> fixtures.with_auth(session),
    )

  expect.expect_status(list_res, 200)
  decode_user_emails(simulate.read_body(list_res))
  |> list.contains(member_email)
  |> expect.is_false
}

pub fn delete_org_user_rejects_self_delete_test() {
  let #(_, handler, session) = fixtures.bootstrap() |> expect.ok

  let req =
    simulate.request(http.Delete, "/api/v1/org/users/1")
    |> fixtures.with_auth(session)

  let res = handler(req)
  expect.expect_status(res, 409)
  string.contains(simulate.read_body(res), "CONFLICT_SELF_DELETE")
  |> expect.is_true
}

// =============================================================================
// Story 4.3 Tests: User Project Role Management
// =============================================================================

/// AC13: POST accepts optional role parameter
pub fn add_user_to_project_with_role_test() {
  let #(app, handler, session) = fixtures.bootstrap() |> expect.ok
  let scrumbringer_server.App(db: db, ..) = app

  // Create a member user
  create_user_via_invite(handler, db, "member@example.com", "il_member", 1)
  let member_id =
    fixtures.user_id_by_email(db, "member@example.com")
    |> expect.ok

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
    |> fixtures.with_auth(session)
    |> simulate.json_body(
      json.object([
        #("project_id", json.int(project_id)),
        #("role", json.string("manager")),
      ]),
    )

  let res = handler(req)
  expect.expect_status(res, 200)

  // Verify role in response
  let body = simulate.read_body(res)
  string.contains(body, "\"role\":\"manager\"") |> expect.is_true
}

/// AC13: POST defaults to member if role not provided
pub fn add_user_to_project_defaults_to_member_test() {
  let #(app, handler, session) = fixtures.bootstrap() |> expect.ok
  let scrumbringer_server.App(db: db, ..) = app

  // Create a member user
  create_user_via_invite(handler, db, "member2@example.com", "il_member2", 1)
  let member_id =
    fixtures.user_id_by_email(db, "member2@example.com")
    |> expect.ok

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
    |> fixtures.with_auth(session)
    |> simulate.json_body(
      json.object([
        #("project_id", json.int(project_id)),
      ]),
    )

  let res = handler(req)
  expect.expect_status(res, 200)

  // Verify role defaults to member
  let body = simulate.read_body(res)
  string.contains(body, "\"role\":\"member\"") |> expect.is_true
}

/// AC14: PATCH changes user's role in a project
pub fn update_user_project_role_test() {
  let #(app, handler, session) = fixtures.bootstrap() |> expect.ok
  let scrumbringer_server.App(db: db, ..) = app

  // Create a member user
  create_user_via_invite(handler, db, "pmember@example.com", "il_pmember", 1)
  let member_id =
    fixtures.user_id_by_email(db, "pmember@example.com")
    |> expect.ok

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
    |> fixtures.with_auth(session)
    |> simulate.json_body(json.object([#("role", json.string("manager"))]))

  let res = handler(req)
  expect.expect_status(res, 200)

  // Verify role change in response
  let body = simulate.read_body(res)
  string.contains(body, "\"role\":\"manager\"") |> expect.is_true
  string.contains(body, "\"previous_role\":\"member\"") |> expect.is_true
}

/// AC15: PATCH returns 422 when trying to demote last manager
pub fn update_user_project_role_last_manager_test() {
  let #(app, handler, session) = fixtures.bootstrap() |> expect.ok
  let scrumbringer_server.App(db: db, ..) = app

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
    |> fixtures.with_auth(session)
    |> simulate.json_body(json.object([#("role", json.string("member"))]))

  let res = handler(req)
  expect.expect_status(res, 422)

  // Verify error message
  let body = simulate.read_body(res)
  string.contains(body, "LAST_MANAGER") |> expect.is_true
}

/// AC14: PATCH returns 404 when user is not a member
pub fn update_user_project_role_not_member_test() {
  let #(app, handler, session) = fixtures.bootstrap() |> expect.ok
  let scrumbringer_server.App(db: db, ..) = app

  // Create a member user (NOT in the project)
  create_user_via_invite(
    handler,
    db,
    "notmember@example.com",
    "il_notmember",
    1,
  )
  let member_id =
    fixtures.user_id_by_email(db, "notmember@example.com")
    |> expect.ok

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
    |> fixtures.with_auth(session)
    |> simulate.json_body(json.object([#("role", json.string("manager"))]))

  let res = handler(req)
  expect.expect_status(res, 404)

  // Verify error message
  let body = simulate.read_body(res)
  string.contains(body, "NOT_FOUND") |> expect.is_true
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
  expect.expect_status(res, 200)
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
  fixtures.query_int(
    db,
    "insert into organizations (name) values ($1) returning id",
    [pog.text(name)],
  )
  |> expect.ok
}

fn insert_project(db: pog.Connection, org_id: Int, name: String) -> Int {
  fixtures.query_int(
    db,
    "insert into projects (org_id, name) values ($1, $2) returning id",
    [pog.int(org_id), pog.text(name)],
  )
  |> expect.ok
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
