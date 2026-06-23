//// Shared test fixtures and helpers for integration tests.
////
//// Provides typed, idiomatic helpers that:
//// - Return Result instead of panicking
//// - Extract IDs from API responses (not raw SQL)
//// - Reduce duplication across test modules

import domain/card as domain_card
import domain/org_role
import domain/project_role
import domain/task_status
import gleam/dynamic/decode
import gleam/erlang/charlist
import gleam/http
import gleam/http/request
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import pog
import scrumbringer_server
import scrumbringer_server/seed_db
import scrumbringer_server/use_case/rate_limit
import scrumbringer_server/use_case/rules_engine
import scrumbringer_server/use_case/workflows/validation_core
import wisp
import wisp/simulate

// =============================================================================
// Types
// =============================================================================

const secret = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

/// Session credentials for authenticated requests.
pub type Session {
  Session(token: String, csrf: String)
}

/// Rule execution record for verification.
pub type RuleExecution {
  RuleExecution(outcome: String, suppression_reason: String)
}

/// Handler function type alias.
pub type Handler =
  fn(wisp.Request) -> wisp.Response

/// Entity types for type-safe API response decoding.
pub type Entity {
  Project
  TaskType
  Workflow
  Rule
  Template
  TaskEntity
  CardEntity
}

/// Resource type for rules (task or card).
pub type RuleResourceType {
  TaskResource
  CardResource
}

// =============================================================================
// Bootstrap
// =============================================================================

/// Create a fresh test app with database reset and admin user registered.
/// Returns the app and a session for the admin user.
pub fn bootstrap() -> Result(
  #(scrumbringer_server.App, Handler, Session),
  String,
) {
  use database_url <- result.try(require_database_url())
  use app <- result.try(
    scrumbringer_server.new_app(secret, database_url)
    |> result.map_error(fn(_) { "Failed to create app" }),
  )

  let handler = scrumbringer_server.handler(app)
  let scrumbringer_server.App(db: db, ..) = app

  let _ = rate_limit.reset_for_tests()
  use _ <- result.try(reset_db(db))
  use _ <- result.try(reset_workflow_tables(db))

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

  case res.status {
    200 -> {
      use session <- result.try(extract_session(res.headers))
      Ok(#(app, handler, session))
    }
    status ->
      Error(
        "Bootstrap failed: status="
        <> int.to_string(status)
        <> " body="
        <> simulate.read_body(res),
      )
  }
}

/// Extract session and CSRF tokens from response headers.
pub fn extract_session(
  headers: List(#(String, String)),
) -> Result(Session, String) {
  case
    find_cookie_value(headers, "sb_session"),
    find_cookie_value(headers, "sb_csrf")
  {
    Some(token), Some(csrf) -> Ok(Session(token: token, csrf: csrf))
    None, _ -> Error("Missing sb_session cookie")
    _, None -> Error("Missing sb_csrf cookie")
  }
}

// =============================================================================
// Authentication
// =============================================================================

/// Login as a user and return their session.
pub fn login(
  handler: Handler,
  email: String,
  password: String,
) -> Result(Session, String) {
  let res =
    handler(
      simulate.request(http.Post, "/api/v1/auth/login")
      |> simulate.json_body(
        json.object([
          #("email", json.string(email)),
          #("password", json.string(password)),
        ]),
      ),
    )

  case res.status {
    200 -> extract_session(res.headers)
    status ->
      Error(
        "Login failed: status=" <> int.to_string(status) <> " email=" <> email,
      )
  }
}

/// Create a member user via invite link and return their ID.
pub fn create_member_user(
  handler: Handler,
  db: pog.Connection,
  email: String,
  invite_code: String,
) -> Result(Int, String) {
  // Insert invite link
  use _ <- result.try(
    pog.query(
      "insert into org_invite_links (org_id, email, token, created_by) values (1, $1, $2, 1)",
    )
    |> pog.parameter(pog.text(email))
    |> pog.parameter(pog.text(invite_code))
    |> pog.execute(db)
    |> result.map_error(fn(e) {
      "Failed to insert invite: " <> string.inspect(e)
    }),
  )

  // Register user
  let res =
    handler(
      simulate.request(http.Post, "/api/v1/auth/register")
      |> simulate.json_body(
        json.object([
          #("password", json.string("passwordpassword")),
          #("invite_token", json.string(invite_code)),
        ]),
      ),
    )

  case res.status {
    200 -> {
      query_int(db, "select id from users where email = $1", [pog.text(email)])
      |> result.map_error(fn(_) { "Failed to find user: " <> email })
    }
    status -> Error("Create member failed: status=" <> int.to_string(status))
  }
}

// =============================================================================
// Entity Creation (return IDs from API response)
// =============================================================================

/// Create a project and return its ID.
pub fn create_project(
  handler: Handler,
  session: Session,
  name: String,
) -> Result(Int, String) {
  let res =
    handler(
      simulate.request(http.Post, "/api/v1/projects")
      |> with_auth(session)
      |> simulate.json_body(project_create_json(name)),
    )

  case res.status {
    200 -> decode_entity_id(simulate.read_body(res), Project)
    status ->
      Error(
        "create_project failed: status="
        <> int.to_string(status)
        <> " name="
        <> name
        <> " body="
        <> simulate.read_body(res),
      )
  }
}

fn project_create_json(name: String) -> json.Json {
  json.object([
    #("name", json.string(name)),
    #("healthy_pool_limit", json.int(20)),
    #(
      "card_depth_names",
      json.array(
        [
          project_depth_name_json(1, "Initiative", "Initiatives"),
          project_depth_name_json(2, "Feature", "Features"),
          project_depth_name_json(3, "Task group", "Task groups"),
        ],
        of: fn(value) { value },
      ),
    ),
  ])
}

fn project_depth_name_json(
  depth: Int,
  singular_name: String,
  plural_name: String,
) -> json.Json {
  json.object([
    #("depth", json.int(depth)),
    #("singular_name", json.string(singular_name)),
    #("plural_name", json.string(plural_name)),
  ])
}

/// Create a task type and return its ID.
pub fn create_task_type(
  handler: Handler,
  session: Session,
  project_id: Int,
  name: String,
  icon: String,
) -> Result(Int, String) {
  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/task-types",
      )
      |> with_auth(session)
      |> simulate.json_body(
        json.object([
          #("name", json.string(name)),
          #("icon", json.string(icon)),
        ]),
      ),
    )

  case res.status {
    200 -> decode_entity_id(simulate.read_body(res), TaskType)
    status ->
      Error(
        "create_task_type failed: status="
        <> int.to_string(status)
        <> " name="
        <> name
        <> " body="
        <> simulate.read_body(res),
      )
  }
}

/// Create a workflow and return its ID.
pub fn create_workflow(
  handler: Handler,
  session: Session,
  project_id: Int,
  name: String,
) -> Result(Int, String) {
  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/workflows",
      )
      |> with_auth(session)
      |> simulate.json_body(
        json.object([
          #("name", json.string(name)),
          #("description", json.string("Test workflow")),
          #("active", json.bool(True)),
        ]),
      ),
    )

  case res.status {
    200 -> decode_entity_id(simulate.read_body(res), Workflow)
    status ->
      Error(
        "create_workflow failed: status="
        <> int.to_string(status)
        <> " name="
        <> name
        <> " body="
        <> simulate.read_body(res),
      )
  }
}

/// Create a rule for task resource type and return its ID.
pub fn create_rule(
  handler: Handler,
  session: Session,
  workflow_id: Int,
  task_type_id: Option(Int),
  name: String,
  to_state: task_status.TaskPhase,
  template_id: Int,
) -> Result(Int, String) {
  let payload =
    build_rule_payload(
      TaskResource,
      name,
      task_status.task_status_to_string(to_state),
      task_type_id,
      template_id,
    )
  do_create_rule(handler, session, workflow_id, name, payload)
}

/// Create a rule for card resource type and return its ID.
pub fn create_rule_card(
  handler: Handler,
  session: Session,
  workflow_id: Int,
  name: String,
  to_state: domain_card.CardPhase,
  template_id: Int,
) -> Result(Int, String) {
  let payload =
    build_rule_payload(
      CardResource,
      name,
      domain_card.state_to_string(to_state),
      None,
      template_id,
    )
  do_create_rule(handler, session, workflow_id, name, payload)
}

/// Build JSON payload for rule creation.
fn build_rule_payload(
  resource_type: RuleResourceType,
  name: String,
  to_state: String,
  task_type_id: Option(Int),
  template_id: Int,
) -> json.Json {
  let resource_type_str = case resource_type {
    TaskResource -> "task"
    CardResource -> "card"
  }
  let goal = case resource_type {
    TaskResource -> "Auto QA"
    CardResource -> "Card automation"
  }

  let base_fields = [
    #("name", json.string(name)),
    #("goal", json.string(goal)),
    #("trigger", trigger_payload(resource_type_str, to_state, task_type_id)),
    #(
      "action",
      json.object([
        #("type", json.string("create_task")),
        #("template_id", json.int(template_id)),
      ]),
    ),
    #("status", json.object([#("type", json.string("active"))])),
  ]

  json.object(base_fields)
}

fn trigger_payload(
  resource_type: String,
  to_state: String,
  task_type_id: Option(Int),
) -> json.Json {
  case resource_type {
    "task" ->
      json.object([
        #("type", json.string(task_trigger_type(to_state))),
        #("task_type_id", option_int_json(task_type_id)),
      ])
    "card" ->
      json.object([
        #("type", json.string(card_trigger_type(to_state))),
        #("scope", json.object([#("type", json.string("any_card"))])),
      ])
    _ -> json.object([])
  }
}

fn task_trigger_type(to_state: String) -> String {
  case to_state {
    "available" -> "task_created"
    "claimed" | "ongoing" -> "task_claimed"
    "completed" -> "task_completed"
    _ -> "task_completed"
  }
}

fn card_trigger_type(to_state: String) -> String {
  case to_state {
    "en_curso" -> "card_activated"
    "cerrada" -> "card_closed"
    _ -> "card_closed"
  }
}

fn option_int_json(value: Option(Int)) -> json.Json {
  case value {
    Some(id) -> json.int(id)
    None -> json.null()
  }
}

/// Internal helper to create a rule with a pre-built payload.
fn do_create_rule(
  handler: Handler,
  session: Session,
  workflow_id: Int,
  name: String,
  payload: json.Json,
) -> Result(Int, String) {
  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/workflows/" <> int.to_string(workflow_id) <> "/rules",
      )
      |> with_auth(session)
      |> simulate.json_body(payload),
    )

  case res.status {
    200 -> decode_entity_id(simulate.read_body(res), Rule)
    status ->
      Error(
        "create_rule failed: status="
        <> int.to_string(status)
        <> " name="
        <> name
        <> " body="
        <> simulate.read_body(res),
      )
  }
}

/// Create a task template with default description and priority.
pub fn create_template(
  handler: Handler,
  session: Session,
  project_id: Int,
  type_id: Int,
  name: String,
) -> Result(Int, String) {
  create_template_full(
    handler,
    session,
    project_id,
    type_id,
    name,
    "Auto-created task",
    3,
  )
}

/// Create a task template with description (default priority 3).
pub fn create_template_with_desc(
  handler: Handler,
  session: Session,
  project_id: Int,
  type_id: Int,
  name: String,
  description: String,
) -> Result(Int, String) {
  create_template_full(
    handler,
    session,
    project_id,
    type_id,
    name,
    description,
    3,
  )
}

/// Create a task template with a validated explicit priority.
pub fn create_template_with_priority(
  handler: Handler,
  session: Session,
  project_id: Int,
  type_id: Int,
  name: String,
  priority: Int,
) -> Result(Int, String) {
  create_template_full(
    handler,
    session,
    project_id,
    type_id,
    name,
    "Auto-created task",
    priority,
  )
}

/// Create a task template with all options.
pub fn create_template_full(
  handler: Handler,
  session: Session,
  project_id: Int,
  type_id: Int,
  name: String,
  description: String,
  priority: Int,
) -> Result(Int, String) {
  use _ <- result.try(validate_template_priority(priority))
  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/task-templates",
      )
      |> with_auth(session)
      |> simulate.json_body(
        json.object([
          #("name", json.string(name)),
          #("description", json.string(description)),
          #("type_id", json.int(type_id)),
          #("priority", json.int(priority)),
        ]),
      ),
    )

  case res.status {
    200 -> decode_entity_id(simulate.read_body(res), Template)
    status ->
      Error(
        "create_template failed: status="
        <> int.to_string(status)
        <> " name="
        <> name
        <> " body="
        <> simulate.read_body(res),
      )
  }
}

fn validate_template_priority(priority: Int) -> Result(Nil, String) {
  validation_core.validate_priority_value(priority)
  |> result.map_error(fn(_) {
    "Invalid task template priority: " <> int.to_string(priority)
  })
}

/// Create a task and return its ID.
pub fn create_task(
  handler: Handler,
  session: Session,
  project_id: Int,
  type_id: Int,
  title: String,
) -> Result(Int, String) {
  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/tasks",
      )
      |> with_auth(session)
      |> simulate.json_body(
        json.object([
          #("title", json.string(title)),
          #("description", json.string("Test task")),
          #("type_id", json.int(type_id)),
          #("priority", json.int(3)),
        ]),
      ),
    )

  case res.status {
    200 -> decode_entity_id(simulate.read_body(res), TaskEntity)
    status ->
      Error(
        "create_task failed: status="
        <> int.to_string(status)
        <> " title="
        <> title
        <> " body="
        <> simulate.read_body(res),
      )
  }
}

/// Create a task associated with a card and return its ID.
pub fn create_task_with_card(
  handler: Handler,
  session: Session,
  project_id: Int,
  type_id: Int,
  card_id: Int,
  title: String,
) -> Result(Int, String) {
  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/tasks",
      )
      |> with_auth(session)
      |> simulate.json_body(
        json.object([
          #("title", json.string(title)),
          #("description", json.string("Test task with card")),
          #("type_id", json.int(type_id)),
          #("priority", json.int(3)),
          #("card_id", json.int(card_id)),
        ]),
      ),
    )

  case res.status {
    200 -> decode_entity_id(simulate.read_body(res), TaskEntity)
    status ->
      Error(
        "create_task_with_card failed: status="
        <> int.to_string(status)
        <> " title="
        <> title
        <> " body="
        <> simulate.read_body(res),
      )
  }
}

/// Create a card and return its ID.
pub fn create_card(
  handler: Handler,
  session: Session,
  project_id: Int,
  title: String,
) -> Result(Int, String) {
  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/cards",
      )
      |> with_auth(session)
      |> simulate.json_body(
        json.object([
          #("title", json.string(title)),
          #("description", json.string("Test card")),
        ]),
      ),
    )

  case res.status {
    200 -> decode_entity_id(simulate.read_body(res), CardEntity)
    status ->
      Error(
        "create_card failed: status="
        <> int.to_string(status)
        <> " title="
        <> title
        <> " body="
        <> simulate.read_body(res),
      )
  }
}

/// Select the template used by a rule.
pub fn select_rule_template(
  handler: Handler,
  session: Session,
  rule_id: Int,
  template_id: Int,
) -> Result(Nil, String) {
  let res =
    handler(
      simulate.request(http.Patch, "/api/v1/rules/" <> int.to_string(rule_id))
      |> with_auth(session)
      |> simulate.json_body(
        json.object([
          #(
            "action",
            json.object([
              #("type", json.string("create_task")),
              #("template_id", json.int(template_id)),
            ]),
          ),
        ]),
      ),
    )

  case res.status {
    200 -> Ok(Nil)
    status ->
      Error(
        "select_rule_template failed: status="
        <> int.to_string(status)
        <> " rule_id="
        <> int.to_string(rule_id)
        <> " template_id="
        <> int.to_string(template_id)
        <> " body="
        <> simulate.read_body(res),
      )
  }
}

/// Add a member to a project.
pub fn add_member(
  handler: Handler,
  session: Session,
  project_id: Int,
  user_id: Int,
  role: String,
) -> Result(Nil, String) {
  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/projects/" <> int.to_string(project_id) <> "/members",
      )
      |> with_auth(session)
      |> simulate.json_body(
        json.object([
          #("user_id", json.int(user_id)),
          #("role", json.string(role)),
        ]),
      ),
    )

  case res.status {
    200 -> Ok(Nil)
    status -> Error("add_member failed: status=" <> int.to_string(status))
  }
}

// =============================================================================
// Database Helpers
// =============================================================================

/// Query a single integer value from the database.
pub fn query_int(
  db: pog.Connection,
  sql: String,
  params: List(pog.Value),
) -> Result(Int, String) {
  let decoder = {
    use value <- decode.field(0, decode.int)
    decode.success(value)
  }

  let query =
    params
    |> list.fold(pog.query(sql), fn(query, param) {
      pog.parameter(query, param)
    })

  case pog.returning(query, decoder) |> pog.execute(db) {
    Ok(pog.Returned(rows: [value, ..], ..)) -> Ok(value)
    Ok(pog.Returned(rows: [], ..)) -> Error("No rows returned")
    Error(e) -> Error("Query error: " <> string.inspect(e))
  }
}

/// Query a single string value from the database.
pub fn query_string(
  db: pog.Connection,
  sql: String,
  params: List(pog.Value),
) -> Result(String, String) {
  let decoder = {
    use value <- decode.field(0, decode.string)
    decode.success(value)
  }

  let query =
    params
    |> list.fold(pog.query(sql), fn(query, param) {
      pog.parameter(query, param)
    })

  case pog.returning(query, decoder) |> pog.execute(db) {
    Ok(pog.Returned(rows: [value, ..], ..)) -> Ok(value)
    Ok(pog.Returned(rows: [], ..)) -> Error("No rows returned")
    Error(e) -> Error("Query error: " <> string.inspect(e))
  }
}

/// Query a nullable integer value from the database.
pub fn query_nullable_int(
  db: pog.Connection,
  sql: String,
  params: List(pog.Value),
) -> Result(Option(Int), String) {
  let decoder = {
    use value <- decode.field(0, decode.optional(decode.int))
    decode.success(value)
  }

  let query =
    params
    |> list.fold(pog.query(sql), fn(query, param) {
      pog.parameter(query, param)
    })

  case pog.returning(query, decoder) |> pog.execute(db) {
    Ok(pog.Returned(rows: [value, ..], ..)) -> Ok(value)
    Ok(pog.Returned(rows: [], ..)) -> Error("No rows returned")
    Error(e) -> Error("Query error: " <> string.inspect(e))
  }
}

/// Fetch a rule execution record.
pub fn fetch_rule_execution(
  db: pog.Connection,
  rule_id: Int,
  target_type: String,
  target_id: Int,
) -> Result(RuleExecution, String) {
  let decoder = {
    use outcome <- decode.field(0, decode.string)
    use suppression_reason <- decode.field(1, decode.string)
    decode.success(RuleExecution(
      outcome: outcome,
      suppression_reason: suppression_reason,
    ))
  }

  case
    pog.query(
      "select outcome, coalesce(suppression_reason, '') from rule_executions where rule_id = $1 and (($2 = 'task' and task_id = $3) or ($2 = 'card' and card_id = $3))",
    )
    |> pog.parameter(pog.int(rule_id))
    |> pog.parameter(pog.text(target_type))
    |> pog.parameter(pog.int(target_id))
    |> pog.returning(decoder)
    |> pog.execute(db)
  {
    Ok(pog.Returned(rows: [execution, ..], ..)) -> Ok(execution)
    Ok(pog.Returned(rows: [], ..)) -> Error("Rule execution not found")
    Error(e) -> Error("Query error: " <> string.inspect(e))
  }
}

/// Get org ID for the first organization.
pub fn get_org_id(db: pog.Connection) -> Result(Int, String) {
  query_int(db, "select id from organizations limit 1", [])
}

/// Get user ID by email.
pub fn get_user_id(db: pog.Connection, email: String) -> Result(Int, String) {
  query_int(db, "select id from users where email = $1", [pog.text(email)])
}

// =============================================================================
// Generic Decoders
// =============================================================================

/// Decode an ID from an API response using type-safe Entity.
pub fn decode_entity_id(body: String, entity: Entity) -> Result(Int, String) {
  let entity_str = entity_to_string(entity)
  case json.parse(body, decode.dynamic) {
    Error(_) -> Error("Invalid JSON: " <> body)
    Ok(dynamic) -> {
      let id_decoder = {
        use id <- decode.field("id", decode.int)
        decode.success(id)
      }

      let entity_decoder = {
        use id <- decode.field(entity_str, id_decoder)
        decode.success(id)
      }

      let response_decoder = {
        use id <- decode.field("data", entity_decoder)
        decode.success(id)
      }

      case decode.run(dynamic, response_decoder) {
        Ok(id) -> Ok(id)
        Error(_) ->
          Error("Failed to decode " <> entity_str <> " id from: " <> body)
      }
    }
  }
}

/// Decode a list of names from an API response using type-safe Entity.
pub fn decode_entity_names(
  body: String,
  entity: Entity,
) -> Result(List(String), String) {
  let entity_str = entity_to_string(entity)
  case json.parse(body, decode.dynamic) {
    Error(_) -> Error("Invalid JSON: " <> body)
    Ok(dynamic) -> {
      let name_decoder = {
        use name <- decode.field("name", decode.string)
        decode.success(name)
      }

      let list_decoder = {
        use names <- decode.field(entity_str, decode.list(name_decoder))
        decode.success(names)
      }

      let response_decoder = {
        use names <- decode.field("data", list_decoder)
        decode.success(names)
      }

      case decode.run(dynamic, response_decoder) {
        Ok(names) -> Ok(names)
        Error(_) ->
          Error("Failed to decode " <> entity_str <> " names from: " <> body)
      }
    }
  }
}

/// Convert Entity to JSON field name string.
fn entity_to_string(entity: Entity) -> String {
  case entity {
    Project -> "project"
    TaskType -> "task_type"
    Workflow -> "workflow"
    Rule -> "rule"
    Template -> "template"
    TaskEntity -> "task"
    CardEntity -> "card"
  }
}

// =============================================================================
// Request Helpers
// =============================================================================

/// Add authentication headers to a request.
pub fn with_auth(req: wisp.Request, session: Session) -> wisp.Request {
  req
  |> request.set_cookie("sb_session", session.token)
  |> request.set_cookie("sb_csrf", session.csrf)
  |> request.set_header("X-CSRF", session.csrf)
}

/// Add Bearer token authorization to a request.
pub fn with_bearer(req: wisp.Request, token: String) -> wisp.Request {
  req
  |> request.set_header("Authorization", "Bearer " <> token)
}

/// Create a StateChange for a task resource (user_triggered defaults to True, card_id None).
pub fn task_event_status(
  task_id: Int,
  project_id: Int,
  org_id: Int,
  user_id: Int,
  from_state: Option(task_status.TaskPhase),
  to_state: task_status.TaskPhase,
  task_type_id: Int,
) -> rules_engine.StateChange {
  task_event_status_with_card(
    task_id,
    project_id,
    org_id,
    user_id,
    from_state,
    to_state,
    task_type_id,
    None,
  )
}

/// Create a StateChange for a task resource with card_id.
pub fn task_event_status_with_card(
  task_id: Int,
  project_id: Int,
  org_id: Int,
  user_id: Int,
  from_state: Option(task_status.TaskPhase),
  to_state: task_status.TaskPhase,
  task_type_id: Int,
  card_id: Option(Int),
) -> rules_engine.StateChange {
  task_event_status_full(
    task_id,
    project_id,
    org_id,
    user_id,
    from_state,
    to_state,
    task_type_id,
    True,
    card_id,
  )
}

/// Create a StateChange for a task with full control (user_triggered, card_id).
pub fn task_event_status_full(
  task_id: Int,
  project_id: Int,
  org_id: Int,
  user_id: Int,
  from_state: Option(task_status.TaskPhase),
  to_state: task_status.TaskPhase,
  task_type_id: Int,
  user_triggered: Bool,
  card_id: Option(Int),
) -> rules_engine.StateChange {
  let ctx =
    rules_engine.TaskContext(
      task_id: task_id,
      project_id: project_id,
      org_id: org_id,
      type_id: task_type_id,
      card_id: card_id,
    )

  rules_engine.TaskChange(
    ctx: ctx,
    from_state: from_state,
    to_state: to_state,
    user_id: user_id,
    user_triggered: user_triggered,
  )
}

/// Create a StateChange for a card resource (user_triggered defaults to True).
pub fn card_event_state(
  card_id: Int,
  project_id: Int,
  org_id: Int,
  user_id: Int,
  from_state: Option(domain_card.CardPhase),
  to_state: domain_card.CardPhase,
) -> rules_engine.StateChange {
  card_event_state_full(
    card_id,
    project_id,
    org_id,
    user_id,
    from_state,
    to_state,
    True,
  )
}

/// Create a StateChange for a card resource with explicit user_triggered.
pub fn card_event_state_full(
  card_id: Int,
  project_id: Int,
  org_id: Int,
  user_id: Int,
  from_state: Option(domain_card.CardPhase),
  to_state: domain_card.CardPhase,
  user_triggered: Bool,
) -> rules_engine.StateChange {
  rules_engine.CardChange(
    card_id: card_id,
    project_id: project_id,
    org_id: org_id,
    from_state: from_state,
    to_state: to_state,
    user_id: user_id,
    user_triggered: user_triggered,
  )
}

// =============================================================================
// State Mutation Helpers
// =============================================================================

/// Set the active status of a workflow (direct DB, NO cascade).
pub fn set_workflow_active(
  db: pog.Connection,
  workflow_id: Int,
  active: Bool,
) -> Result(Nil, String) {
  pog.query("UPDATE workflows SET active = $1 WHERE id = $2")
  |> pog.parameter(pog.bool(active))
  |> pog.parameter(pog.int(workflow_id))
  |> pog.execute(db)
  |> result.map(fn(_) { Nil })
  |> result.map_error(fn(e) {
    "set_workflow_active failed: " <> string.inspect(e)
  })
}

/// Set the active status of a workflow via HTTP API (WITH cascade to rules).
pub fn set_workflow_active_cascade(
  handler: Handler,
  session: Session,
  workflow_id: Int,
  active: Bool,
) -> Result(Nil, String) {
  let active_int = case active {
    True -> 1
    False -> 0
  }
  let res =
    handler(
      simulate.request(
        http.Patch,
        "/api/v1/workflows/" <> int.to_string(workflow_id),
      )
      |> with_auth(session)
      |> simulate.json_body(json.object([#("active", json.int(active_int))])),
    )

  case res.status {
    200 -> Ok(Nil)
    _ ->
      Error("set_workflow_active_cascade failed: " <> int.to_string(res.status))
  }
}

/// Set the active status of a rule.
pub fn set_rule_active(
  db: pog.Connection,
  rule_id: Int,
  active: Bool,
) -> Result(Nil, String) {
  pog.query("UPDATE rules SET active = $1 WHERE id = $2")
  |> pog.parameter(pog.bool(active))
  |> pog.parameter(pog.int(rule_id))
  |> pog.execute(db)
  |> result.map(fn(_) { Nil })
  |> result.map_error(fn(e) { "set_rule_active failed: " <> string.inspect(e) })
}

/// Delete a workflow via HTTP API.
pub fn delete_workflow(
  handler: Handler,
  session: Session,
  workflow_id: Int,
) -> Result(Nil, String) {
  let res =
    handler(
      simulate.request(
        http.Delete,
        "/api/v1/workflows/" <> int.to_string(workflow_id),
      )
      |> with_auth(session),
    )

  case res.status {
    204 -> Ok(Nil)
    _ -> Error("delete_workflow failed: " <> int.to_string(res.status))
  }
}

// =============================================================================
// Direct DB Operations (fast bulk setup, bypasses API)
// =============================================================================

/// Insert a task directly to DB with full options.
pub fn insert_task_db(
  db: pog.Connection,
  opts: seed_db.TaskInsertOptions,
) -> Result(Int, String) {
  seed_db.insert_task(db, opts)
}

/// Insert a task with simple defaults directly to DB.
pub fn insert_task_db_simple(
  db: pog.Connection,
  project_id: Int,
  type_id: Int,
  title: String,
  created_by: Int,
  card_id: Option(Int),
) -> Result(Int, String) {
  seed_db.insert_task_simple(
    db,
    project_id,
    type_id,
    title,
    created_by,
    card_id,
  )
}

/// Insert accumulated work time for a user on a task.
pub fn insert_work_session_db(
  db: pog.Connection,
  user_id: Int,
  task_id: Int,
  accumulated_s: Int,
) -> Result(Nil, String) {
  seed_db.insert_work_session(db, user_id, task_id, accumulated_s)
}

/// Insert a task note directly to DB.
pub fn insert_note_db(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
  content: String,
) -> Result(Int, String) {
  seed_db.insert_task_note(db, task_id, user_id, content, None)
}

/// Insert a card directly to DB.
pub fn insert_card_db(
  db: pog.Connection,
  project_id: Int,
  title: String,
  color: Option(domain_card.CardColor),
  created_by: Int,
) -> Result(Int, String) {
  seed_db.insert_card_simple(db, project_id, title, color, created_by)
}

/// Insert a user directly to DB.
pub fn insert_user_db(
  db: pog.Connection,
  org_id: Int,
  email: String,
  org_role: org_role.OrgRole,
) -> Result(Int, String) {
  seed_db.insert_user_simple(db, org_id, email, org_role)
}

/// Insert a task type directly to DB.
pub fn insert_task_type_db(
  db: pog.Connection,
  project_id: Int,
  name: String,
  icon: String,
) -> Result(Int, String) {
  seed_db.insert_task_type(db, project_id, name, icon)
}

/// Insert a project directly to DB.
pub fn insert_project_db(
  db: pog.Connection,
  org_id: Int,
  name: String,
) -> Result(Int, String) {
  seed_db.insert_project(db, org_id, name, None)
}

/// Insert a project member directly to DB.
pub fn insert_member_db(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
  role: project_role.ProjectRole,
) -> Result(Nil, String) {
  seed_db.insert_member(db, project_id, user_id, role)
}

/// Insert a task event directly to DB.
pub fn insert_task_event_db(
  db: pog.Connection,
  org_id: Int,
  project_id: Int,
  task_id: Int,
  user_id: Int,
  event_type: String,
) -> Result(Nil, String) {
  seed_db.insert_task_event_simple(
    db,
    org_id,
    project_id,
    task_id,
    user_id,
    event_type,
  )
}

// =============================================================================
// Internal Helpers
// =============================================================================

fn find_cookie_value(
  headers: List(#(String, String)),
  name: String,
) -> Option(String) {
  let target = name <> "="

  let cookies =
    headers
    |> list.filter_map(fn(h) {
      case h.0 {
        "set-cookie" -> Ok(h.1)
        _ -> Error(Nil)
      }
    })

  case list.find(cookies, fn(h) { string.starts_with(h, target) }) {
    Ok(header) -> {
      let assert Ok(#(value, _)) =
        header
        |> string.drop_start(string.length(target))
        |> string.split_once(";")

      Some(value)
    }
    Error(_) -> None
  }
}

fn require_database_url() -> Result(String, String) {
  case getenv("DATABASE_URL", "") {
    "" -> Error("DATABASE_URL environment variable is required")
    url -> Ok(url)
  }
}

fn reset_db(db: pog.Connection) -> Result(Nil, String) {
  pog.query(
    "TRUNCATE project_members, org_invite_links, org_invites, users, projects, organizations RESTART IDENTITY CASCADE",
  )
  |> pog.execute(db)
  |> result.map(fn(_) { Nil })
  |> result.map_error(fn(e) { "reset_db failed: " <> string.inspect(e) })
}

fn reset_workflow_tables(db: pog.Connection) -> Result(Nil, String) {
  pog.query(
    "TRUNCATE rule_templates, rule_executions, rules, workflows, task_templates, tasks, task_types, cards RESTART IDENTITY CASCADE",
  )
  |> pog.execute(db)
  |> result.map(fn(_) { Nil })
  |> result.map_error(fn(e) {
    "reset_workflow_tables failed: " <> string.inspect(e)
  })
}

fn getenv(key: String, default: String) -> String {
  let key_charlist = charlist.from_string(key)
  let default_charlist = charlist.from_string(default)
  getenv_charlist(key_charlist, default_charlist)
  |> charlist.to_string
}

@external(erlang, "os", "getenv")
fn getenv_charlist(
  key: charlist.Charlist,
  default: charlist.Charlist,
) -> charlist.Charlist
