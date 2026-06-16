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

import gleam/http
import gleam/option.{type Option, None, Some}
import gleam/result
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/authorization
import scrumbringer_server/http/csrf
import scrumbringer_server/http/json_payload
import scrumbringer_server/http/service_error_response
import scrumbringer_server/http/workflows/payloads as workflow_payloads
import scrumbringer_server/http/workflows/presenters as workflow_presenters
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
  response_from_result(list_project_workflows(req, ctx, project_id))
}

fn handle_create_project(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> wisp.Response {
  case require_project_workflow_create_access(req, ctx, project_id) {
    Error(resp) -> resp
    Ok(#(db, user, project_id)) ->
      json_payload.with_response(req, decode_create_payload, fn(payload) {
        response_from_result(create_project_workflow(
          db,
          user,
          project_id,
          payload,
        ))
      })
  }
}

fn handle_update(
  req: wisp.Request,
  ctx: auth.Ctx,
  workflow_id: String,
) -> wisp.Response {
  case require_workflow_update_access(req, ctx, workflow_id) {
    Error(resp) -> resp
    Ok(#(db, workflow_id, workflow)) ->
      json_payload.with_response(req, decode_update_payload, fn(payload) {
        response_from_result(update_project_workflow(
          db,
          workflow_id,
          workflow,
          payload,
        ))
      })
  }
}

fn handle_delete(
  req: wisp.Request,
  ctx: auth.Ctx,
  workflow_id: String,
) -> wisp.Response {
  response_from_result(delete_project_workflow(req, ctx, workflow_id))
}

fn response_from_result(
  result: Result(wisp.Response, wisp.Response),
) -> wisp.Response {
  case result {
    Ok(resp) -> resp
    Error(resp) -> resp
  }
}

fn list_project_workflows(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id_str: String,
) -> Result(wisp.Response, wisp.Response) {
  use user <- result.try(auth.require_current_user_response(req, ctx))
  use project_id <- result.try(api.parse_id(project_id_str))
  let auth.Ctx(db: db, ..) = ctx
  use _ <- result.try(require_project_manager(db, project_id, user.id))
  use workflows <- result.try(list_workflows_db(db, project_id))

  Ok(api.ok(workflow_presenters.workflows_response(workflows)))
}

fn require_project_workflow_create_access(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id_str: String,
) -> Result(#(pog.Connection, StoredUser, Int), wisp.Response) {
  use user <- result.try(auth.require_current_user_response(req, ctx))
  use project_id <- result.try(api.parse_id(project_id_str))
  let auth.Ctx(db: db, ..) = ctx
  use _ <- result.try(require_project_manager(db, project_id, user.id))
  use _ <- result.try(csrf.require_csrf(req))
  Ok(#(db, user, project_id))
}

fn create_project_workflow(
  db: pog.Connection,
  user: StoredUser,
  project_id: Int,
  payload: workflow_payloads.CreatePayload,
) -> Result(wisp.Response, wisp.Response) {
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
    Ok(workflow) -> Ok(api.ok(workflow_presenters.workflow_response(workflow)))
    Error(error) -> Error(workflow_error_response(error))
  }
}

fn require_workflow_update_access(
  req: wisp.Request,
  ctx: auth.Ctx,
  workflow_id_str: String,
) -> Result(#(pog.Connection, Int, workflows_db.WorkflowRecord), wisp.Response) {
  use user <- result.try(auth.require_current_user_response(req, ctx))
  use workflow_id <- result.try(api.parse_id(workflow_id_str))
  let auth.Ctx(db: db, ..) = ctx
  use workflow <- result.try(require_workflow_manager_access(
    db,
    user,
    workflow_id,
  ))
  use _ <- result.try(csrf.require_csrf(req))
  Ok(#(db, workflow_id, workflow))
}

fn update_project_workflow(
  db: pog.Connection,
  workflow_id: Int,
  workflow: workflows_db.WorkflowRecord,
  payload: workflow_payloads.UpdatePayload,
) -> Result(wisp.Response, wisp.Response) {
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
    payload.active,
  ))

  get_workflow_response(db, workflow_id)
}

fn delete_project_workflow(
  req: wisp.Request,
  ctx: auth.Ctx,
  workflow_id_str: String,
) -> Result(wisp.Response, wisp.Response) {
  use user <- result.try(auth.require_current_user_response(req, ctx))
  use workflow_id <- result.try(api.parse_id(workflow_id_str))
  let auth.Ctx(db: db, ..) = ctx
  use workflow <- result.try(require_workflow_manager_access(
    db,
    user,
    workflow_id,
  ))
  use _ <- result.try(csrf.require_csrf(req))
  use _ <- result.try(delete_workflow_db(
    db,
    workflow_id,
    workflow.org_id,
    workflow.project_id,
  ))

  Ok(api.no_content())
}

fn require_project_manager(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
) -> Result(Nil, wisp.Response) {
  case projects_db.is_project_manager(db, project_id, user_id) {
    Ok(True) -> Ok(Nil)
    Ok(False) -> Error(api.error(403, "FORBIDDEN", "Forbidden"))
    Error(_) -> Error(database_error_response())
  }
}

fn require_workflow_manager_access(
  db: pog.Connection,
  user: StoredUser,
  workflow_id: Int,
) -> Result(workflows_db.WorkflowRecord, wisp.Response) {
  use workflow <- result.try(get_workflow(db, workflow_id))
  use _ <- result.try(require_workflow_manager(db, user, workflow))
  Ok(workflow)
}

fn require_workflow_manager(
  db: pog.Connection,
  user: StoredUser,
  workflow: workflows_db.WorkflowRecord,
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

fn list_workflows_db(
  db: pog.Connection,
  project_id: Int,
) -> Result(List(workflows_db.WorkflowRecord), wisp.Response) {
  case workflows_db.list_project_workflows(db, project_id) {
    Ok(workflows) -> Ok(workflows)
    Error(_) -> Error(database_error_response())
  }
}

fn get_workflow(
  db: pog.Connection,
  workflow_id: Int,
) -> Result(workflows_db.WorkflowRecord, wisp.Response) {
  case workflows_db.get_workflow(db, workflow_id) {
    Ok(workflow) -> Ok(workflow)
    Error(error) -> Error(workflow_error_response(error))
  }
}

fn decode_create_payload(
  data,
) -> Result(workflow_payloads.CreatePayload, wisp.Response) {
  workflow_payloads.decode_create(data)
  |> result.map_error(fn(_) {
    api.error(400, "VALIDATION_ERROR", "Invalid JSON")
  })
}

fn decode_update_payload(
  data,
) -> Result(workflow_payloads.UpdatePayload, wisp.Response) {
  workflow_payloads.decode_update(data)
  |> result.map_error(fn(_) {
    api.error(400, "VALIDATION_ERROR", "Invalid JSON")
  })
}

fn update_metadata_if_needed(
  db: pog.Connection,
  workflow_id: Int,
  org_id: Int,
  project_id: Int,
  payload: workflow_payloads.UpdatePayload,
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
        Error(error) -> Error(workflow_error_response(error))
      }
  }
}

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
        Error(error) -> Error(workflow_error_response(error))
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
    Error(error) -> Error(service_error_response.to_response(error))
  }
}

fn get_workflow_response(
  db: pog.Connection,
  workflow_id: Int,
) -> Result(wisp.Response, wisp.Response) {
  case workflows_db.get_workflow(db, workflow_id) {
    Ok(workflow) -> Ok(api.ok(workflow_presenters.workflow_response(workflow)))
    Error(error) -> Error(workflow_error_response(error))
  }
}

fn workflow_error_response(error: service_error.ServiceError) -> wisp.Response {
  case error {
    service_error.AlreadyExists ->
      api.error(422, "VALIDATION_ERROR", "Workflow name already exists")
    _ -> service_error_response.to_response(error)
  }
}

fn database_error_response() -> wisp.Response {
  api.error(500, "INTERNAL", "Database error")
}
