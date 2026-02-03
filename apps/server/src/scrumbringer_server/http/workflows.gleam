//// HTTP handlers for workflows CRUD endpoints.
////
//// ## Mission
////
//// Provide CRUD endpoints for workflows within projects.
////
//// ## Responsibilities
////
//// - Authorize project managers
//// - Parse and validate workflow payloads
//// - Delegate persistence to workflow services
////
//// ## Non-responsibilities
////
//// - Workflow persistence (see `services/workflows_db.gleam`)
//// - Project membership checks (see `services/projects_db.gleam`)
////
//// ## Relations
////
//// - Uses `services/projects_db` for access checks
//// - Uses `services/workflows_db` for persistence

import gleam/dynamic
import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/result
import helpers/json as json_helpers
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/authorization
import scrumbringer_server/http/csrf
import scrumbringer_server/services/projects_db
import scrumbringer_server/services/service_error
import scrumbringer_server/services/store_state.{type StoredUser}
import scrumbringer_server/services/workflows_db
import wisp

// =============================================================================
// Routing
// =============================================================================

/// Handle /api/projects/:project_id/workflows requests.
/// Example: handle_project_workflows(req, ctx, project_id)
pub fn handle_project_workflows(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> wisp.Response {
  case req.method {
    http.Get -> handle_list_project(req, ctx, project_id)
    http.Post -> handle_create_project(req, ctx, project_id)
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}

/// Handle /api/workflows/:workflow_id requests.
/// Example: handle_workflow(req, ctx, workflow_id)
pub fn handle_workflow(
  req: wisp.Request,
  ctx: auth.Ctx,
  workflow_id: String,
) -> wisp.Response {
  case req.method {
    http.Patch -> handle_update(req, ctx, workflow_id)
    http.Delete -> handle_delete(req, ctx, workflow_id)
    _ -> wisp.method_not_allowed([http.Patch, http.Delete])
  }
}

// =============================================================================
// Handlers
// =============================================================================

fn handle_list_project(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case list_project_workflows(req, ctx, project_id) {
    Ok(resp) -> resp
    Error(resp) -> resp
  }
}

fn handle_create_project(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> wisp.Response {
  use data <- wisp.require_json(req)
  // Justified nested case: unwrap Result<Response, Response> into a Response.
  case create_project_workflow(req, ctx, project_id, data) {
    Ok(resp) -> resp
    Error(resp) -> resp
  }
}

fn handle_update(
  req: wisp.Request,
  ctx: auth.Ctx,
  workflow_id: String,
) -> wisp.Response {
  use data <- wisp.require_json(req)
  // Justified nested case: unwrap Result<Response, Response> into a Response.
  case update_project_workflow(req, ctx, workflow_id, data) {
    Ok(resp) -> resp
    Error(resp) -> resp
  }
}

fn handle_delete(
  req: wisp.Request,
  ctx: auth.Ctx,
  workflow_id: String,
) -> wisp.Response {
  case delete_project_workflow(req, ctx, workflow_id) {
    Ok(resp) -> resp
    Error(resp) -> resp
  }
}

// =============================================================================
// Shared helpers
// =============================================================================

type CreatePayload {
  CreatePayload(name: String, description: String, active: Bool)
}

type UpdatePayload {
  UpdatePayload(
    name: Option(String),
    description: Option(String),
    active: Option(Int),
  )
}

fn list_project_workflows(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id_str: String,
) -> Result(wisp.Response, wisp.Response) {
  use user <- result.try(require_current_user(req, ctx))
  use project_id <- result.try(parse_id(project_id_str))
  let auth.Ctx(db: db, ..) = ctx
  use _ <- result.try(require_project_manager(db, project_id, user.id))
  use workflows <- result.try(list_workflows_db(db, project_id))

  Ok(
    api.ok(
      json.object([#("workflows", json.array(workflows, of: workflow_json))]),
    ),
  )
}

fn create_project_workflow(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id_str: String,
  data: dynamic.Dynamic,
) -> Result(wisp.Response, wisp.Response) {
  use user <- result.try(require_current_user(req, ctx))
  use project_id <- result.try(parse_id(project_id_str))
  let auth.Ctx(db: db, ..) = ctx
  use _ <- result.try(require_project_manager(db, project_id, user.id))
  use _ <- result.try(csrf.require_csrf(req))
  use payload <- result.try(decode_create_payload(data))

  case
    workflows_db.create_workflow(
      db,
      user.org_id,
      project_id,
      payload.name,
      payload.description,
      payload.active,
      user.id,
    )
  {
    Ok(workflow) ->
      Ok(api.ok(json.object([#("workflow", workflow_json(workflow))])))
    Error(service_error.AlreadyExists) ->
      Error(api.error(422, "VALIDATION_ERROR", "Workflow name already exists"))
    Error(service_error.DbError(_)) ->
      Error(api.error(500, "INTERNAL", "Database error"))
    Error(service_error.NotFound) ->
      Error(api.error(404, "NOT_FOUND", "Not found"))
    Error(service_error.ValidationError(msg)) ->
      Error(api.error(422, "VALIDATION_ERROR", msg))
    Error(service_error.InvalidReference(_)) ->
      Error(api.error(422, "VALIDATION_ERROR", "Invalid reference"))
    Error(service_error.Conflict(_)) ->
      Error(api.error(409, "CONFLICT", "Conflict"))
    Error(service_error.Unexpected(_)) ->
      Error(api.error(500, "INTERNAL", "Unexpected error"))
  }
}

fn update_project_workflow(
  req: wisp.Request,
  ctx: auth.Ctx,
  workflow_id_str: String,
  data: dynamic.Dynamic,
) -> Result(wisp.Response, wisp.Response) {
  use user <- result.try(require_current_user(req, ctx))
  use workflow_id <- result.try(parse_id(workflow_id_str))
  let auth.Ctx(db: db, ..) = ctx
  use workflow <- result.try(get_workflow(db, workflow_id))
  use _ <- result.try(require_workflow_manager(db, user, workflow))
  use _ <- result.try(csrf.require_csrf(req))
  use payload <- result.try(decode_update_payload(data))
  use active_value <- result.try(normalize_active(payload.active))
  use _ <- result.try(update_metadata_if_needed(
    db,
    workflow_id,
    workflow.org_id,
    workflow.project_id,
    payload,
  ))
  use _ <- result.try(update_active_if_needed(
    db,
    workflow_id,
    workflow.org_id,
    workflow.project_id,
    active_value,
  ))

  get_workflow_response(db, workflow_id)
}

fn delete_project_workflow(
  req: wisp.Request,
  ctx: auth.Ctx,
  workflow_id_str: String,
) -> Result(wisp.Response, wisp.Response) {
  use user <- result.try(require_current_user(req, ctx))
  use workflow_id <- result.try(parse_id(workflow_id_str))
  let auth.Ctx(db: db, ..) = ctx
  use workflow <- result.try(get_workflow(db, workflow_id))
  use _ <- result.try(require_workflow_manager(db, user, workflow))
  use _ <- result.try(csrf.require_csrf(req))
  use _ <- result.try(delete_workflow_db(
    db,
    workflow_id,
    workflow.org_id,
    workflow.project_id,
  ))

  Ok(api.no_content())
}

fn require_current_user(
  req: wisp.Request,
  ctx: auth.Ctx,
) -> Result(StoredUser, wisp.Response) {
  case auth.require_current_user(req, ctx) {
    Ok(user) -> Ok(user)
    Error(_) ->
      Error(api.error(401, "AUTH_REQUIRED", "Authentication required"))
  }
}

fn require_project_manager(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
) -> Result(Nil, wisp.Response) {
  case projects_db.is_project_manager(db, project_id, user_id) {
    Ok(True) -> Ok(Nil)
    Ok(False) -> Error(api.error(403, "FORBIDDEN", "Forbidden"))
    Error(_) -> Error(api.error(500, "INTERNAL", "Database error"))
  }
}

fn require_workflow_manager(
  db: pog.Connection,
  user: StoredUser,
  workflow: workflows_db.Workflow,
) -> Result(Nil, wisp.Response) {
  case
    authorization.require_project_manager(
      db,
      user,
      workflow.org_id,
      workflow.project_id,
    )
  {
    Ok(_) -> Ok(Nil)
    Error(resp) -> Error(resp)
  }
}

fn parse_id(value: String) -> Result(Int, wisp.Response) {
  case int.parse(value) {
    Ok(id) -> Ok(id)
    Error(_) -> Error(api.error(404, "NOT_FOUND", "Not found"))
  }
}

fn list_workflows_db(
  db: pog.Connection,
  project_id: Int,
) -> Result(List(workflows_db.Workflow), wisp.Response) {
  case workflows_db.list_project_workflows(db, project_id) {
    Ok(workflows) -> Ok(workflows)
    Error(_) -> Error(api.error(500, "INTERNAL", "Database error"))
  }
}

fn get_workflow(
  db: pog.Connection,
  workflow_id: Int,
) -> Result(workflows_db.Workflow, wisp.Response) {
  case workflows_db.get_workflow(db, workflow_id) {
    Ok(workflow) -> Ok(workflow)
    Error(service_error.NotFound) ->
      Error(api.error(404, "NOT_FOUND", "Not found"))
    Error(service_error.AlreadyExists) ->
      Error(api.error(422, "VALIDATION_ERROR", "Workflow name already exists"))
    Error(service_error.DbError(_)) ->
      Error(api.error(500, "INTERNAL", "Database error"))
    Error(service_error.ValidationError(msg)) ->
      Error(api.error(422, "VALIDATION_ERROR", msg))
    Error(service_error.InvalidReference(_)) ->
      Error(api.error(422, "VALIDATION_ERROR", "Invalid reference"))
    Error(service_error.Conflict(_)) ->
      Error(api.error(409, "CONFLICT", "Conflict"))
    Error(service_error.Unexpected(_)) ->
      Error(api.error(500, "INTERNAL", "Unexpected error"))
  }
}

fn decode_create_payload(
  data: dynamic.Dynamic,
) -> Result(CreatePayload, wisp.Response) {
  let decoder = {
    use name <- decode.field("name", decode.string)
    use description <- decode.optional_field("description", "", decode.string)
    use active <- decode.optional_field("active", False, decode.bool)
    decode.success(CreatePayload(
      name: name,
      description: description,
      active: active,
    ))
  }

  decode.run(data, decoder)
  |> result.map_error(fn(_) {
    api.error(400, "VALIDATION_ERROR", "Invalid JSON")
  })
}

fn decode_update_payload(
  data: dynamic.Dynamic,
) -> Result(UpdatePayload, wisp.Response) {
  let decoder = {
    use name <- decode.optional_field(
      "name",
      None,
      decode.optional(decode.string),
    )
    use description <- decode.optional_field(
      "description",
      None,
      decode.optional(decode.string),
    )
    use active <- decode.optional_field(
      "active",
      None,
      decode.optional(decode.int),
    )
    decode.success(UpdatePayload(
      name: name,
      description: description,
      active: active,
    ))
  }

  decode.run(data, decoder)
  |> result.map_error(fn(_) {
    api.error(400, "VALIDATION_ERROR", "Invalid JSON")
  })
}

fn normalize_active(active: Option(Int)) -> Result(Option(Bool), wisp.Response) {
  case active {
    None -> Ok(None)
    Some(0) -> Ok(Some(False))
    Some(1) -> Ok(Some(True))
    Some(_) -> Error(api.error(422, "VALIDATION_ERROR", "Invalid active"))
  }
}

// Justification: nested case improves clarity for branching logic.
fn update_metadata_if_needed(
  db: pog.Connection,
  workflow_id: Int,
  org_id: Int,
  project_id: Int,
  payload: UpdatePayload,
) -> Result(Nil, wisp.Response) {
  let has_updates = case payload.name, payload.description {
    None, None -> False
    _, _ -> True
  }

  case has_updates {
    False -> Ok(Nil)
    True ->
      case
        workflows_db.update_workflow(
          db,
          workflow_id,
          org_id,
          project_id,
          payload.name,
          payload.description,
        )
      {
        Ok(_) -> Ok(Nil)
        Error(service_error.NotFound) ->
          Error(api.error(404, "NOT_FOUND", "Not found"))
        Error(service_error.AlreadyExists) ->
          Error(api.error(
            422,
            "VALIDATION_ERROR",
            "Workflow name already exists",
          ))
        Error(service_error.DbError(_)) ->
          Error(api.error(500, "INTERNAL", "Database error"))
        Error(service_error.ValidationError(msg)) ->
          Error(api.error(422, "VALIDATION_ERROR", msg))
        Error(service_error.InvalidReference(_)) ->
          Error(api.error(422, "VALIDATION_ERROR", "Invalid reference"))
        Error(service_error.Conflict(_)) ->
          Error(api.error(409, "CONFLICT", "Conflict"))
        Error(service_error.Unexpected(_)) ->
          Error(api.error(500, "INTERNAL", "Unexpected error"))
      }
  }
}

// Justification: nested case improves clarity for branching logic.
fn update_active_if_needed(
  db: pog.Connection,
  workflow_id: Int,
  org_id: Int,
  project_id: Int,
  active_value: Option(Bool),
) -> Result(Nil, wisp.Response) {
  case active_value {
    None -> Ok(Nil)
    Some(active) ->
      case
        workflows_db.set_active_cascade(
          db,
          workflow_id,
          org_id,
          project_id,
          active,
        )
      {
        Ok(Nil) -> Ok(Nil)
        Error(service_error.NotFound) ->
          Error(api.error(404, "NOT_FOUND", "Not found"))
        Error(service_error.AlreadyExists) ->
          Error(api.error(
            422,
            "VALIDATION_ERROR",
            "Workflow name already exists",
          ))
        Error(service_error.DbError(_)) ->
          Error(api.error(500, "INTERNAL", "Database error"))
        Error(service_error.ValidationError(msg)) ->
          Error(api.error(422, "VALIDATION_ERROR", msg))
        Error(service_error.InvalidReference(_)) ->
          Error(api.error(422, "VALIDATION_ERROR", "Invalid reference"))
        Error(service_error.Conflict(_)) ->
          Error(api.error(409, "CONFLICT", "Conflict"))
        Error(service_error.Unexpected(_)) ->
          Error(api.error(500, "INTERNAL", "Unexpected error"))
      }
  }
}

fn delete_workflow_db(
  db: pog.Connection,
  workflow_id: Int,
  org_id: Int,
  project_id: Int,
) -> Result(Nil, wisp.Response) {
  case workflows_db.delete_workflow(db, workflow_id, org_id, project_id) {
    Ok(Nil) -> Ok(Nil)
    Error(service_error.NotFound) ->
      Error(api.error(404, "NOT_FOUND", "Not found"))
    Error(service_error.DbError(_)) ->
      Error(api.error(500, "INTERNAL", "Database error"))
    Error(service_error.ValidationError(msg)) ->
      Error(api.error(422, "VALIDATION_ERROR", msg))
    Error(service_error.InvalidReference(_)) ->
      Error(api.error(422, "VALIDATION_ERROR", "Invalid reference"))
    Error(service_error.Conflict(_)) ->
      Error(api.error(409, "CONFLICT", "Conflict"))
    Error(service_error.Unexpected(_)) ->
      Error(api.error(500, "INTERNAL", "Unexpected error"))
    Error(service_error.AlreadyExists) ->
      Error(api.error(409, "CONFLICT", "Conflict"))
  }
}

fn get_workflow_response(
  db: pog.Connection,
  workflow_id: Int,
) -> Result(wisp.Response, wisp.Response) {
  case workflows_db.get_workflow(db, workflow_id) {
    Ok(workflow) ->
      Ok(api.ok(json.object([#("workflow", workflow_json(workflow))])))
    Error(service_error.NotFound) ->
      Error(api.error(404, "NOT_FOUND", "Not found"))
    Error(service_error.AlreadyExists) ->
      Error(api.error(422, "VALIDATION_ERROR", "Workflow name already exists"))
    Error(service_error.DbError(_)) ->
      Error(api.error(500, "INTERNAL", "Database error"))
    Error(service_error.ValidationError(msg)) ->
      Error(api.error(422, "VALIDATION_ERROR", msg))
    Error(service_error.InvalidReference(_)) ->
      Error(api.error(422, "VALIDATION_ERROR", "Invalid reference"))
    Error(service_error.Conflict(_)) ->
      Error(api.error(409, "CONFLICT", "Conflict"))
    Error(service_error.Unexpected(_)) ->
      Error(api.error(500, "INTERNAL", "Unexpected error"))
  }
}

fn workflow_json(workflow: workflows_db.Workflow) -> json.Json {
  let workflows_db.Workflow(
    id: id,
    org_id: org_id,
    project_id: project_id,
    name: name,
    description: description,
    active: active,
    rule_count: rule_count,
    created_by: created_by,
    created_at: created_at,
  ) = workflow

  json.object([
    #("id", json.int(id)),
    #("org_id", json.int(org_id)),
    #("project_id", json.int(project_id)),
    #("name", json.string(name)),
    #("description", json_helpers.option_string_json(description)),
    #("active", json.bool(active)),
    #("rule_count", json.int(rule_count)),
    #("created_by", json.int(created_by)),
    #("created_at", json.string(created_at)),
  ])
}
