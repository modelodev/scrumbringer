//// Shared test fixtures and helpers for integration tests.
////
//// Provides typed, idiomatic helpers that:
//// - Return Result instead of panicking
//// - Extract IDs from API responses (not raw SQL)
//// - Reduce duplication across test modules

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
import scrumbringer_server/services/rules_engine.{
  type StateChangeEvent, Card, StateChangeEvent, Task,
}
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
        "Bootstrap failed: status=" <> int.to_string(status) <> " body=" <> simulate.read_body(res),
      )
  }
}

/// Extract session and CSRF tokens from response headers.
pub fn extract_session(headers: List(#(String, String))) -> Result(Session, String) {
  case find_cookie_value(headers, "sb_session"), find_cookie_value(headers, "sb_csrf") {
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
    |> result.map_error(fn(e) { "Failed to insert invite: " <> string.inspect(e) }),
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
      |> simulate.json_body(json.object([#("name", json.string(name))])),
    )

  case res.status {
    200 -> decode_entity_id(simulate.read_body(res), Project)
    status ->
      Error(
        "create_project failed: status=" <> int.to_string(status) <> " name=" <> name <> " body=" <> simulate.read_body(res),
      )
  }
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
        "create_task_type failed: status=" <> int.to_string(status) <> " name=" <> name <> " body=" <> simulate.read_body(res),
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
        "create_workflow failed: status=" <> int.to_string(status) <> " name=" <> name <> " body=" <> simulate.read_body(res),
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
  to_state: String,
) -> Result(Int, String) {
  let payload = build_rule_payload(TaskResource, name, to_state, task_type_id)
  do_create_rule(handler, session, workflow_id, name, payload)
}

/// Create a rule for card resource type and return its ID.
pub fn create_rule_card(
  handler: Handler,
  session: Session,
  workflow_id: Int,
  name: String,
  to_state: String,
) -> Result(Int, String) {
  let payload = build_rule_payload(CardResource, name, to_state, None)
  do_create_rule(handler, session, workflow_id, name, payload)
}

/// Build JSON payload for rule creation.
fn build_rule_payload(
  resource_type: RuleResourceType,
  name: String,
  to_state: String,
  task_type_id: Option(Int),
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
    #("resource_type", json.string(resource_type_str)),
    #("to_state", json.string(to_state)),
    #("active", json.bool(True)),
  ]

  let fields = case task_type_id {
    Some(id) -> [#("task_type_id", json.int(id)), ..base_fields]
    None -> base_fields
  }

  json.object(fields)
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
        "create_rule failed: status=" <> int.to_string(status) <> " name=" <> name <> " body=" <> simulate.read_body(res),
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
  create_template_full(handler, session, project_id, type_id, name, "Auto-created task", None)
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
  create_template_full(handler, session, project_id, type_id, name, description, None)
}

/// Create a task template with all options.
pub fn create_template_full(
  handler: Handler,
  session: Session,
  project_id: Int,
  type_id: Int,
  name: String,
  description: String,
  priority: Option(Int),
) -> Result(Int, String) {
  let priority_val = option.unwrap(priority, 3)
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
          #("priority", json.int(priority_val)),
        ]),
      ),
    )

  case res.status {
    200 -> decode_entity_id(simulate.read_body(res), Template)
    status ->
      Error(
        "create_template failed: status=" <> int.to_string(status) <> " name=" <> name <> " body=" <> simulate.read_body(res),
      )
  }
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
        "create_task failed: status=" <> int.to_string(status) <> " title=" <> title <> " body=" <> simulate.read_body(res),
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
        "create_card failed: status=" <> int.to_string(status) <> " title=" <> title <> " body=" <> simulate.read_body(res),
      )
  }
}

/// Attach a template to a rule.
pub fn attach_template(
  handler: Handler,
  session: Session,
  rule_id: Int,
  template_id: Int,
) -> Result(Nil, String) {
  let res =
    handler(
      simulate.request(
        http.Post,
        "/api/v1/rules/" <> int.to_string(rule_id) <> "/templates/" <> int.to_string(template_id),
      )
      |> with_auth(session)
      |> simulate.json_body(json.object([#("execution_order", json.int(1))])),
    )

  case res.status {
    200 -> Ok(Nil)
    status ->
      Error(
        "attach_template failed: status=" <> int.to_string(status) <> " rule_id=" <> int.to_string(rule_id) <> " template_id=" <> int.to_string(template_id) <> " body=" <> simulate.read_body(res),
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

/// Fetch a rule execution record.
pub fn fetch_rule_execution(
  db: pog.Connection,
  rule_id: Int,
  origin_type: String,
  origin_id: Int,
) -> Result(RuleExecution, String) {
  let decoder = {
    use outcome <- decode.field(0, decode.string)
    use suppression_reason <- decode.field(1, decode.string)
    decode.success(RuleExecution(outcome: outcome, suppression_reason: suppression_reason))
  }

  case
    pog.query(
      "select outcome, coalesce(suppression_reason, '') from rule_executions where rule_id = $1 and origin_type = $2 and origin_id = $3",
    )
    |> pog.parameter(pog.int(rule_id))
    |> pog.parameter(pog.text(origin_type))
    |> pog.parameter(pog.int(origin_id))
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
        Error(_) -> Error("Failed to decode " <> entity_str <> " id from: " <> body)
      }
    }
  }
}

/// Decode a list of names from an API response using type-safe Entity.
pub fn decode_entity_names(body: String, entity: Entity) -> Result(List(String), String) {
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
        Error(_) -> Error("Failed to decode " <> entity_str <> " names from: " <> body)
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

// =============================================================================
// Event Construction Helpers
// =============================================================================

/// Create a StateChangeEvent for a task resource (user_triggered defaults to True).
pub fn task_event(
  task_id: Int,
  project_id: Int,
  org_id: Int,
  user_id: Int,
  from_state: Option(String),
  to_state: String,
  task_type_id: Option(Int),
) -> StateChangeEvent {
  task_event_full(task_id, project_id, org_id, user_id, from_state, to_state, task_type_id, True)
}

/// Create a StateChangeEvent for a task resource with explicit user_triggered.
pub fn task_event_full(
  task_id: Int,
  project_id: Int,
  org_id: Int,
  user_id: Int,
  from_state: Option(String),
  to_state: String,
  task_type_id: Option(Int),
  user_triggered: Bool,
) -> StateChangeEvent {
  StateChangeEvent(
    resource_type: Task,
    resource_id: task_id,
    from_state: from_state,
    to_state: to_state,
    project_id: project_id,
    org_id: org_id,
    user_id: user_id,
    user_triggered: user_triggered,
    task_type_id: task_type_id,
  )
}

/// Create a StateChangeEvent for a card resource (user_triggered defaults to True).
pub fn card_event(
  card_id: Int,
  project_id: Int,
  org_id: Int,
  user_id: Int,
  from_state: Option(String),
  to_state: String,
) -> StateChangeEvent {
  card_event_full(card_id, project_id, org_id, user_id, from_state, to_state, True)
}

/// Create a StateChangeEvent for a card resource with explicit user_triggered.
pub fn card_event_full(
  card_id: Int,
  project_id: Int,
  org_id: Int,
  user_id: Int,
  from_state: Option(String),
  to_state: String,
  user_triggered: Bool,
) -> StateChangeEvent {
  StateChangeEvent(
    resource_type: Card,
    resource_id: card_id,
    from_state: from_state,
    to_state: to_state,
    project_id: project_id,
    org_id: org_id,
    user_id: user_id,
    user_triggered: user_triggered,
    task_type_id: None,
  )
}

// =============================================================================
// State Mutation Helpers
// =============================================================================

/// Set the active status of a workflow.
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
  |> result.map_error(fn(e) { "set_workflow_active failed: " <> string.inspect(e) })
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

// =============================================================================
// Internal Helpers
// =============================================================================

fn find_cookie_value(headers: List(#(String, String)), name: String) -> Option(String) {
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
      let #(value, _) =
        header
        |> string.drop_start(string.length(target))
        |> string.split_once(";")
        |> result.unwrap(#("", ""))
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
  |> result.map_error(fn(e) { "reset_workflow_tables failed: " <> string.inspect(e) })
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
