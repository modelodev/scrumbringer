import fixtures
import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import pog
import scrumbringer_server
import support/assertions as expect
import wisp/simulate

pub fn bearer_token_can_list_and_create_tasks_without_csrf_test() {
  let assert Ok(#(app, handler, admin_session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app
  let assert Ok(project_id) =
    fixtures.create_project(handler, admin_session, "Core")
  let assert Ok(type_id) =
    fixtures.create_task_type(
      handler,
      admin_session,
      project_id,
      "Bug",
      "bug-ant",
    )
  let assert Ok(integration_user_id) =
    create_integration_user(handler, admin_session, "ci@example.com")
  let assert Ok(Nil) =
    fixtures.add_member(
      handler,
      admin_session,
      project_id,
      integration_user_id,
      "manager",
    )
  let assert Ok(token) =
    create_api_token(
      handler,
      admin_session,
      "ci@example.com",
      Some(project_id),
      ["tasks:read", "tasks:write"],
    )

  let list_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/tasks",
      )
      |> fixtures.with_bearer(token),
    )
  expect.expect_status(list_res, 200)

  let assert Ok(card_id) =
    create_active_card(handler, admin_session, project_id, "Imported task card")
  let create_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/tasks",
      )
      |> fixtures.with_bearer(token)
      |> simulate.json_body(
        json.object([
          #("title", json.string("Imported task")),
          #("description", json.string("Created by integration")),
          #("type_id", json.int(type_id)),
          #("priority", json.int(3)),
          #("card_id", json.int(card_id)),
        ]),
      ),
    )
  expect.expect_status(create_res, 200)

  let assert Ok(audit_count) =
    fixtures.query_int(
      db,
      "select count(*) from api_token_audit_log where endpoint = $1 and status = 200",
      [
        pog.text("/api/v1/projects/" <> int.to_string(project_id) <> "/tasks"),
      ],
    )
  let assert True = audit_count >= 2
}

pub fn bearer_write_requires_write_scope_test() {
  let assert Ok(#(_app, handler, admin_session)) = fixtures.bootstrap()
  let assert Ok(project_id) =
    fixtures.create_project(handler, admin_session, "Core")
  let assert Ok(type_id) =
    fixtures.create_task_type(
      handler,
      admin_session,
      project_id,
      "Bug",
      "bug-ant",
    )
  let assert Ok(integration_user_id) =
    create_integration_user(handler, admin_session, "reader@example.com")
  let assert Ok(Nil) =
    fixtures.add_member(
      handler,
      admin_session,
      project_id,
      integration_user_id,
      "manager",
    )
  let assert Ok(token) =
    create_api_token(
      handler,
      admin_session,
      "reader@example.com",
      Some(project_id),
      ["tasks:read"],
    )

  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/tasks",
      )
      |> fixtures.with_bearer(token)
      |> simulate.json_body(
        json.object([
          #("title", json.string("Denied task")),
          #("type_id", json.int(type_id)),
          #("priority", json.int(3)),
        ]),
      ),
    )

  expect.expect_status(res, 403)
}

pub fn bearer_project_limit_blocks_other_projects_test() {
  let assert Ok(#(_app, handler, admin_session)) = fixtures.bootstrap()
  let assert Ok(project_a) =
    fixtures.create_project(handler, admin_session, "A")
  let assert Ok(project_b) =
    fixtures.create_project(handler, admin_session, "B")
  let assert Ok(integration_user_id) =
    create_integration_user(handler, admin_session, "limited@example.com")
  let assert Ok(Nil) =
    fixtures.add_member(
      handler,
      admin_session,
      project_a,
      integration_user_id,
      "manager",
    )
  let assert Ok(Nil) =
    fixtures.add_member(
      handler,
      admin_session,
      project_b,
      integration_user_id,
      "manager",
    )
  let assert Ok(token) =
    create_api_token(
      handler,
      admin_session,
      "limited@example.com",
      Some(project_a),
      ["tasks:read"],
    )

  let res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/projects/" <> int.to_string(project_b) <> "/tasks",
      )
      |> fixtures.with_bearer(token),
    )

  expect.expect_status(res, 403)
}

pub fn invalid_bearer_does_not_fallback_to_cookie_test() {
  let assert Ok(#(_app, handler, admin_session)) = fixtures.bootstrap()

  let res =
    handler(
      simulate.request(http.Get, "/api/v1/projects")
      |> fixtures.with_auth(admin_session)
      |> fixtures.with_bearer("sbt_missing_bad"),
    )

  expect.expect_status(res, 401)
}

pub fn integration_user_cannot_login_with_password_test() {
  let assert Ok(#(_app, handler, admin_session)) = fixtures.bootstrap()
  let assert Ok(_integration_user_id) =
    create_integration_user(handler, admin_session, "bot@example.com")

  let res =
    handler(
      simulate.request(http.Post, "/api/v1/auth/login")
      |> simulate.json_body(
        json.object([
          #("email", json.string("bot@example.com")),
          #("password", json.string("passwordpassword")),
        ]),
      ),
    )

  expect.expect_status(res, 403)
}

pub fn bearer_can_operate_cards_and_notes_test() {
  let assert Ok(#(_app, handler, admin_session)) = fixtures.bootstrap()
  let assert Ok(project_id) =
    fixtures.create_project(handler, admin_session, "Core")
  let assert Ok(type_id) =
    fixtures.create_task_type(
      handler,
      admin_session,
      project_id,
      "Bug",
      "bug-ant",
    )
  let assert Ok(task_id) =
    fixtures.create_task(handler, admin_session, project_id, type_id, "Task")
  let assert Ok(card_id) =
    fixtures.create_card(handler, admin_session, project_id, "Card")
  let assert Ok(integration_user_id) =
    create_integration_user(handler, admin_session, "resources@example.com")
  let assert Ok(Nil) =
    fixtures.add_member(
      handler,
      admin_session,
      project_id,
      integration_user_id,
      "manager",
    )
  let assert Ok(token) =
    create_api_token(
      handler,
      admin_session,
      "resources@example.com",
      Some(project_id),
      [
        "cards:read",
        "cards:write",
        "notes:read",
        "notes:write",
      ],
    )

  handler(
    simulate.request(
      http.Get,
      "/api/v1/projects/" <> int.to_string(project_id) <> "/cards",
    )
    |> fixtures.with_bearer(token),
  )
  |> expect.expect_status(200)

  let create_card_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/cards",
      )
      |> fixtures.with_bearer(token)
      |> simulate.json_body(
        json.object([
          #("title", json.string("Imported card")),
          #("description", json.string("Created by integration")),
        ]),
      ),
    )
  expect.expect_status(create_card_res, 200)

  let assert Ok(created_card_id) =
    fixtures.decode_data_entity_id(simulate.read_body(create_card_res), "card")

  handler(
    simulate.request(
      http.Patch,
      "/api/v1/cards/" <> int.to_string(created_card_id),
    )
    |> fixtures.with_bearer(token)
    |> simulate.json_body(
      json.object([
        #("title", json.string("Updated imported card")),
        #("description", json.string("Updated by integration")),
      ]),
    ),
  )
  |> expect.expect_status(200)

  handler(
    simulate.request(http.Get, "/api/v1/cards/" <> int.to_string(card_id))
    |> fixtures.with_bearer(token),
  )
  |> expect.expect_status(200)

  handler(
    simulate.request(
      http.Get,
      "/api/v1/cards/" <> int.to_string(card_id) <> "/notes",
    )
    |> fixtures.with_bearer(token),
  )
  |> expect.expect_status(200)

  let card_note_res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/cards/" <> int.to_string(card_id) <> "/notes",
      )
      |> fixtures.with_bearer(token)
      |> simulate.json_body(
        json.object([
          #("content", json.string("Card note from integration")),
        ]),
      ),
    )
  expect.expect_status(card_note_res, 200)
  let assert Ok(card_note_id) =
    fixtures.decode_data_entity_id(simulate.read_body(card_note_res), "note")

  handler(
    simulate.request(
      http.Delete,
      "/api/v1/cards/"
        <> int.to_string(card_id)
        <> "/notes/"
        <> int.to_string(card_note_id),
    )
    |> fixtures.with_bearer(token),
  )
  |> expect.expect_status(204)

  handler(
    simulate.request(
      http.Get,
      "/api/v1/tasks/" <> int.to_string(task_id) <> "/notes",
    )
    |> fixtures.with_bearer(token),
  )
  |> expect.expect_status(200)

  handler(
    simulate.request(
      http.Post,
      "/api/v1/tasks/" <> int.to_string(task_id) <> "/notes",
    )
    |> fixtures.with_bearer(token)
    |> simulate.json_body(
      json.object([
        #("content", json.string("Task note from integration")),
      ]),
    ),
  )
  |> expect.expect_status(200)
}

pub fn project_api_token_grants_access_without_membership_test() {
  let assert Ok(#(app, handler, admin_session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app
  let assert Ok(project_id) =
    fixtures.create_project(handler, admin_session, "Core")
  let assert Ok(type_id) =
    fixtures.create_task_type(
      handler,
      admin_session,
      project_id,
      "Bug",
      "bug-ant",
    )

  let res =
    create_api_token_response(
      handler,
      admin_session,
      "outside@example.com",
      Some(project_id),
      ["tasks:read", "tasks:write"],
      None,
    )

  expect.expect_status(res, 200)
  let assert Ok(token) = decode_token(simulate.read_body(res))

  let assert Ok(member_count) =
    fixtures.query_int(
      db,
      "\nselect count(*)\nfrom project_members pm\njoin users u on u.id = pm.user_id\nwhere pm.project_id = $1 and u.email = $2 and pm.role = 'manager'\n",
      [pog.int(project_id), pog.text("outside@example.com")],
    )
  expect.equal(member_count, 0)

  handler(
    simulate.request(
      http.Get,
      "/api/v1/projects/" <> int.to_string(project_id) <> "/tasks",
    )
    |> fixtures.with_bearer(token),
  )
  |> expect.expect_status(200)

  let assert Ok(card_id) =
    create_active_card(handler, admin_session, project_id, "Imported task card")
  handler(
    simulate.request(
      http.Post,
      "/api/v1/projects/" <> int.to_string(project_id) <> "/tasks",
    )
    |> fixtures.with_bearer(token)
    |> simulate.json_body(
      json.object([
        #("title", json.string("Imported task")),
        #("description", json.string("Created by integration")),
        #("type_id", json.int(type_id)),
        #("priority", json.int(3)),
        #("card_id", json.int(card_id)),
      ]),
    ),
  )
  |> expect.expect_status(200)
}

pub fn org_wide_api_token_can_list_existing_projects_test() {
  let assert Ok(#(app, handler, admin_session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app
  let assert Ok(project_a) =
    fixtures.create_project(handler, admin_session, "Alpha")
  let assert Ok(project_b) =
    fixtures.create_project(handler, admin_session, "Zulu")
  let assert Ok(integration_user_id) =
    create_integration_user(handler, admin_session, "org-wide@example.com")
  let assert Ok(token) =
    create_api_token(handler, admin_session, "org-wide@example.com", None, [
      "projects:read",
      "tasks:read",
    ])
  let assert Ok(project_c) =
    fixtures.create_project(handler, admin_session, "Future")

  let assert Ok(member_count) =
    fixtures.query_int(
      db,
      "\nselect count(*)\nfrom project_members\nwhere user_id = $1 and role = 'manager' and project_id in ($2, $3, $4)\n",
      [
        pog.int(integration_user_id),
        pog.int(project_a),
        pog.int(project_b),
        pog.int(project_c),
      ],
    )
  expect.equal(member_count, 0)

  let res =
    handler(
      simulate.request(http.Get, "/api/v1/projects")
      |> fixtures.with_bearer(token),
    )

  expect.expect_status(res, 200)
  decode_project_names(simulate.read_body(res))
  |> expect.equal(["Alpha", "Default", "Future", "Zulu"])

  handler(
    simulate.request(
      http.Get,
      "/api/v1/projects/" <> int.to_string(project_c) <> "/tasks",
    )
    |> fixtures.with_bearer(token),
  )
  |> expect.expect_status(200)
}

pub fn api_token_rejects_invalid_expires_at_test() {
  let assert Ok(#(_app, handler, admin_session)) = fixtures.bootstrap()
  let assert Ok(project_id) =
    fixtures.create_project(handler, admin_session, "Core")
  let assert Ok(integration_user_id) =
    create_integration_user(handler, admin_session, "expires@example.com")
  let assert Ok(Nil) =
    fixtures.add_member(
      handler,
      admin_session,
      project_id,
      integration_user_id,
      "manager",
    )

  let res =
    create_api_token_response(
      handler,
      admin_session,
      "expires@example.com",
      Some(project_id),
      ["tasks:read"],
      Some("not-a-date"),
    )

  expect.expect_status(res, 422)
}

pub fn api_token_rejects_project_write_scope_test() {
  let assert Ok(#(_app, handler, admin_session)) = fixtures.bootstrap()
  let assert Ok(project_id) =
    fixtures.create_project(handler, admin_session, "Core")

  let res =
    create_api_token_response(
      handler,
      admin_session,
      "scope@example.com",
      Some(project_id),
      ["projects:write"],
      None,
    )

  expect.expect_status(res, 422)
  expect.expect_json_contains_code(simulate.read_body(res), "VALIDATION_ERROR")
}

pub fn api_token_name_can_be_renamed_without_changing_grant_test() {
  let assert Ok(#(app, handler, admin_session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app
  let assert Ok(project_id) =
    fixtures.create_project(handler, admin_session, "Core")
  let assert Ok(#(token_id, _bearer)) =
    create_api_token_created(
      handler,
      admin_session,
      "rename-token@example.com",
      Some(project_id),
      ["tasks:read"],
    )

  let res =
    handler(
      simulate.request(
        http.Patch,
        "/api/v1/api-tokens/" <> int.to_string(token_id),
      )
      |> fixtures.with_auth(admin_session)
      |> simulate.json_body(json.object([#("name", json.string("docs bot"))])),
    )

  expect.expect_status(res, 200)
  let assert Ok(name) =
    fixtures.query_string(db, "select name from api_tokens where id = $1", [
      pog.int(token_id),
    ])
  expect.equal(name, "docs bot")
  let assert Ok(scope_count) =
    fixtures.query_int(
      db,
      "select count(*)::int from api_token_scopes where token_id = $1 and scope = $2",
      [pog.int(token_id), pog.text("tasks:read")],
    )
  expect.equal(scope_count, 1)
}

pub fn integration_users_report_active_token_count_test() {
  let assert Ok(#(_app, handler, admin_session)) = fixtures.bootstrap()
  let assert Ok(_token) =
    create_api_token(
      handler,
      admin_session,
      "counted-integration@example.com",
      None,
      ["projects:read"],
    )

  let res =
    handler(
      simulate.request(http.Get, "/api/v1/integration-users")
      |> fixtures.with_auth(admin_session),
    )

  expect.expect_status(res, 200)
  let body = simulate.read_body(res)
  case string.contains(body, "\"integration_users\"") {
    True -> Nil
    False -> panic as "expected integration_users payload"
  }
  case string.contains(body, "\"active_token_count\":1") {
    True -> Nil
    False -> panic as "expected active_token_count to be 1"
  }
}

pub fn integration_user_deactivate_requires_no_active_tokens_test() {
  let assert Ok(#(app, handler, admin_session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app
  let assert Ok(integration_user_id) =
    create_integration_user(handler, admin_session, "deactivate@example.com")
  let assert Ok(#(token_id, _bearer)) =
    create_api_token_created(
      handler,
      admin_session,
      "deactivate@example.com",
      None,
      ["projects:read"],
    )

  handler(
    simulate.request(
      http.Delete,
      "/api/v1/integration-users/" <> int.to_string(integration_user_id),
    )
    |> fixtures.with_auth(admin_session),
  )
  |> expect.expect_status(409)

  handler(
    simulate.request(
      http.Delete,
      "/api/v1/api-tokens/" <> int.to_string(token_id),
    )
    |> fixtures.with_auth(admin_session),
  )
  |> expect.expect_status(204)

  handler(
    simulate.request(
      http.Delete,
      "/api/v1/integration-users/" <> int.to_string(integration_user_id),
    )
    |> fixtures.with_auth(admin_session),
  )
  |> expect.expect_status(204)

  let assert Ok(deleted_count) =
    fixtures.query_int(
      db,
      "select count(*)::int from users where id = $1 and deleted_at is not null",
      [pog.int(integration_user_id)],
    )
  expect.equal(deleted_count, 1)

  let tokens_res =
    handler(
      simulate.request(http.Get, "/api/v1/api-tokens")
      |> fixtures.with_auth(admin_session),
    )
  expect.expect_status(tokens_res, 200)
  case
    string.contains(
      simulate.read_body(tokens_res),
      "\"integration_user_email\":\"deactivate@example.com\"",
    )
  {
    True -> Nil
    False -> panic as "expected token to preserve integration email"
  }
}

pub fn bearer_revoked_expired_and_unsupported_routes_are_rejected_test() {
  let assert Ok(#(_app, handler, admin_session)) = fixtures.bootstrap()
  let assert Ok(project_id) =
    fixtures.create_project(handler, admin_session, "Core")
  let assert Ok(integration_user_id) =
    create_integration_user(handler, admin_session, "state@example.com")
  let assert Ok(Nil) =
    fixtures.add_member(
      handler,
      admin_session,
      project_id,
      integration_user_id,
      "manager",
    )
  let assert Ok(token) =
    create_api_token(
      handler,
      admin_session,
      "state@example.com",
      Some(project_id),
      ["projects:read", "tasks:read", "tasks:read"],
    )

  handler(
    simulate.request(http.Get, "/api/v1/org/users")
    |> fixtures.with_bearer(token),
  )
  |> expect.expect_status(403)

  let assert Ok(expired_token) =
    create_api_token_with_expires(
      handler,
      admin_session,
      "state@example.com",
      Some(project_id),
      ["tasks:read"],
      Some("2000-01-01T00:00:00Z"),
    )

  handler(
    simulate.request(
      http.Get,
      "/api/v1/projects/" <> int.to_string(project_id) <> "/tasks",
    )
    |> fixtures.with_bearer(expired_token),
  )
  |> expect.expect_status(401)

  let assert Ok(#(token_id, token_to_revoke)) =
    create_api_token_created(
      handler,
      admin_session,
      "state@example.com",
      Some(project_id),
      ["tasks:read"],
    )

  handler(
    simulate.request(
      http.Delete,
      "/api/v1/api-tokens/" <> int.to_string(token_id),
    )
    |> fixtures.with_auth(admin_session),
  )
  |> expect.expect_status(204)

  handler(
    simulate.request(
      http.Get,
      "/api/v1/projects/" <> int.to_string(project_id) <> "/tasks",
    )
    |> fixtures.with_bearer(token_to_revoke),
  )
  |> expect.expect_status(401)
}

fn create_active_card(
  handler: fixtures.Handler,
  session: fixtures.Session,
  project_id: Int,
  title: String,
) -> Result(Int, String) {
  use card_id <- result.try(fixtures.create_card(
    handler,
    session,
    project_id,
    title,
  ))
  use Nil <- result.try(fixtures.activate_card(handler, session, card_id))
  Ok(card_id)
}

fn create_integration_user(
  handler: fixtures.Handler,
  session: fixtures.Session,
  email: String,
) -> Result(Int, String) {
  let res =
    handler(
      simulate.request(http.Post, "/api/v1/integration-users")
      |> fixtures.with_auth(session)
      |> simulate.json_body(json.object([#("email", json.string(email))])),
    )

  case res.status {
    200 ->
      fixtures.decode_data_entity_id(
        simulate.read_body(res),
        "integration_user",
      )
    status -> Error("create_integration_user failed: " <> int.to_string(status))
  }
}

fn create_api_token(
  handler: fixtures.Handler,
  session: fixtures.Session,
  integration: String,
  project_id: Option(Int),
  scopes: List(String),
) -> Result(String, String) {
  create_api_token_with_expires(
    handler,
    session,
    integration,
    project_id,
    scopes,
    None,
  )
}

fn create_api_token_with_expires(
  handler: fixtures.Handler,
  session: fixtures.Session,
  integration: String,
  project_id: Option(Int),
  scopes: List(String),
  expires_at: Option(String),
) -> Result(String, String) {
  let res =
    create_api_token_response(
      handler,
      session,
      integration,
      project_id,
      scopes,
      expires_at,
    )

  case res.status {
    200 -> decode_token(simulate.read_body(res))
    status -> Error("create_api_token failed: " <> int.to_string(status))
  }
}

fn create_api_token_created(
  handler: fixtures.Handler,
  session: fixtures.Session,
  integration: String,
  project_id: Option(Int),
  scopes: List(String),
) -> Result(#(Int, String), String) {
  let res =
    create_api_token_response(
      handler,
      session,
      integration,
      project_id,
      scopes,
      None,
    )

  case res.status {
    200 -> decode_created_token(simulate.read_body(res))
    status ->
      Error("create_api_token_created failed: " <> int.to_string(status))
  }
}

fn create_api_token_response(
  handler: fixtures.Handler,
  session: fixtures.Session,
  integration: String,
  project_id: Option(Int),
  scopes: List(String),
  expires_at: Option(String),
) {
  let res =
    handler(
      simulate.request(http.Post, "/api/v1/api-tokens")
      |> fixtures.with_auth(session)
      |> simulate.json_body(
        json.object([
          #("name", json.string("ci-token")),
          #("integration", json.string(integration)),
          #("project_id", option_int_json(project_id)),
          #("scopes", json.array(scopes, of: json.string)),
          #("expires_at", option_string_json(expires_at)),
        ]),
      ),
    )

  res
}

fn decode_project_names(body: String) -> List(String) {
  fixtures.require_data_string_list_field(body, "projects", "name")
}

fn decode_token(body: String) -> Result(String, String) {
  let data_decoder = {
    use token <- decode.field("token", decode.string)
    decode.success(token)
  }
  decode_data(body, data_decoder)
  |> result.map_error(fn(_) { "invalid token response" })
}

fn decode_created_token(body: String) -> Result(#(Int, String), String) {
  let token_decoder = {
    use id <- decode.field("id", decode.int)
    decode.success(id)
  }
  let data_decoder = {
    use id <- decode.field("api_token", token_decoder)
    use token <- decode.field("token", decode.string)
    decode.success(#(id, token))
  }
  decode_data(body, data_decoder)
  |> result.map_error(fn(_) { "invalid created token response" })
}

fn decode_data(body: String, decoder: decode.Decoder(a)) {
  json.parse(from: body, using: decode.field("data", decoder, decode.success))
}

fn option_int_json(value: Option(Int)) -> json.Json {
  case value {
    None -> json.null()
    Some(id) -> json.int(id)
  }
}

fn option_string_json(value: Option(String)) -> json.Json {
  case value {
    None -> json.null()
    Some(raw) -> json.string(raw)
  }
}
