//// HTTP handlers for task templates.
////
//// ## Mission
////
//// Provide CRUD endpoints for project-scoped task templates.
////
//// ## Responsibilities
////
//// - Validate HTTP requests and JSON payloads
//// - Authorize project managers
//// - Serialize template data for responses
////
//// ## Non-responsibilities
////
//// - Template repository (see `use_case/task_templates_db.gleam`)
//// - Project authorization rules (see `use_case/projects_db.gleam`)
////
//// ## Relationships
////
//// - Delegates DB work to `use_case/task_templates_db.gleam`
//// - Uses `http/auth.gleam` for session identity
//// - Uses `http/csrf.gleam` for mutation protection

import gleam/http
import gleam/json
import gleam/result
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/authorization
import scrumbringer_server/http/csrf
import scrumbringer_server/http/service_error_response
import scrumbringer_server/http/task_templates/payloads as template_payloads
import scrumbringer_server/http/task_templates/presenters as template_presenters
import scrumbringer_server/use_case/automation_config_audit_db as config_audit
import scrumbringer_server/use_case/projects_db
import scrumbringer_server/use_case/service_error
import scrumbringer_server/use_case/store_state.{type StoredUser}
import scrumbringer_server/use_case/task_templates_db
import wisp

// =============================================================================
// Context + Routing
// =============================================================================

/// Routes requests for project template collections (GET/POST).
///
/// Example:
///   handle_project_templates(req, ctx, project_id)
pub fn handle_project_templates(
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

/// Routes requests for a single template (PATCH/DELETE).
///
/// Example:
///   handle_template(req, ctx, template_id)
pub fn handle_template(
  req: wisp.Request,
  ctx: auth.Ctx,
  template_id: String,
) -> wisp.Response {
  case req.method {
    http.Patch -> handle_update(req, ctx, template_id)
    http.Delete -> handle_delete(req, ctx, template_id)
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

  case auth.require_current_user_response(req, ctx) {
    Error(resp) -> resp
    Ok(user) -> list_project_templates_for_user(ctx, user, project_id)
  }
}

fn handle_create_project(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> wisp.Response {
  case auth.require_current_user_response(req, ctx) {
    Error(resp) -> resp
    Ok(user) -> create_project_template_for_user(req, ctx, user, project_id)
  }
}

fn handle_update(
  req: wisp.Request,
  ctx: auth.Ctx,
  template_id: String,
) -> wisp.Response {
  case auth.require_current_user_response(req, ctx) {
    Error(resp) -> resp
    Ok(user) -> update_template_for_user(req, ctx, user, template_id)
  }
}

fn handle_delete(
  req: wisp.Request,
  ctx: auth.Ctx,
  template_id: String,
) -> wisp.Response {
  case auth.require_current_user_response(req, ctx) {
    Error(resp) -> resp
    Ok(user) -> delete_template_for_user(req, ctx, user, template_id)
  }
}

// =============================================================================
// Flows
// =============================================================================

fn list_project_templates_for_user(
  ctx: auth.Ctx,
  user: StoredUser,
  project_id: String,
) -> wisp.Response {
  case api.parse_id(project_id) {
    Error(resp) -> resp
    Ok(project_id) -> list_project_templates(ctx, user, project_id)
  }
}

fn list_project_templates(
  ctx: auth.Ctx,
  user: StoredUser,
  project_id: Int,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case ensure_project_manager_db(db, project_id, user.id) {
    Ok(Nil) -> list_project_templates_db(db, project_id)
    Error(resp) -> resp
  }
}

fn list_project_templates_db(
  db: pog.Connection,
  project_id: Int,
) -> wisp.Response {
  case task_templates_db.list_project_templates(db, project_id) {
    Ok(templates) -> api.ok(template_presenters.templates_response(templates))

    Error(error) -> template_error_response(error)
  }
}

fn create_project_template_for_user(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  project_id: String,
) -> wisp.Response {
  case api.parse_id(project_id) {
    Error(resp) -> resp
    Ok(project_id) -> create_template_for_project(req, ctx, user, project_id)
  }
}

fn create_template_for_project(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  project_id: Int,
) -> wisp.Response {
  case ensure_project_manager(ctx, project_id, user.id) {
    Error(resp) -> resp
    Ok(Nil) -> create_template(req, ctx, user, project_id)
  }
}

fn update_template_for_user(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  template_id: String,
) -> wisp.Response {
  case api.parse_id(template_id) {
    Error(resp) -> resp
    Ok(template_id) -> update_template_for_id(req, ctx, user, template_id)
  }
}

fn update_template_for_id(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  template_id: Int,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case require_template_project_manager(db, user, template_id) {
    Error(resp) -> resp
    Ok(#(org_id, project_id)) ->
      update_template(req, ctx, user, template_id, org_id, project_id)
  }
}

fn delete_template_for_user(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  template_id: String,
) -> wisp.Response {
  case api.parse_id(template_id) {
    Error(resp) -> resp
    Ok(template_id) -> delete_template_for_id(req, ctx, user, template_id)
  }
}

fn delete_template_for_id(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  template_id: Int,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case require_template_project_manager(db, user, template_id) {
    Error(resp) -> resp
    Ok(#(org_id, project_id)) ->
      delete_template(req, ctx, user, template_id, org_id, project_id)
  }
}

fn ensure_project_manager(
  ctx: auth.Ctx,
  project_id: Int,
  user_id: Int,
) -> Result(Nil, wisp.Response) {
  let auth.Ctx(db: db, ..) = ctx

  ensure_project_manager_db(db, project_id, user_id)
}

fn ensure_project_manager_db(
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

fn require_template_project_manager(
  db: pog.Connection,
  user: StoredUser,
  template_id: Int,
) -> Result(#(Int, Int), wisp.Response) {
  use template <- result.try(fetch_template(db, template_id))
  authorization.require_project_manager(
    db,
    user,
    template.org_id,
    template.project_id,
  )
}

fn fetch_template(
  db: pog.Connection,
  template_id: Int,
) -> Result(task_templates_db.TaskTemplate, wisp.Response) {
  case task_templates_db.get_template(db, template_id) {
    Ok(template) -> Ok(template)
    Error(error) -> Error(template_error_response(error))
  }
}

// =============================================================================
// Shared helpers
// =============================================================================

fn create_template(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  project_id: Int,
) -> wisp.Response {
  with_mutation_payload(req, decode_create_payload, fn(payload) {
    create_template_db(ctx, user, project_id, payload)
  })
}

fn create_template_db(
  ctx: auth.Ctx,
  user: StoredUser,
  project_id: Int,
  payload: template_payloads.CreatePayload,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case
    run_config_transaction(db, fn(tx) {
      use template <- result.try(
        task_templates_db.create_template(
          tx,
          user.org_id,
          project_id,
          payload.name,
          payload.description,
          payload.type_id,
          payload.priority,
          user.id,
        )
        |> result.map_error(template_error_response),
      )
      use _ <- result.try(record_config_change(
        tx,
        user,
        project_id,
        config_audit.Template,
        template.id,
        config_audit.Created,
        json.object([#("name", json.string(template.name))]),
      ))
      Ok(api.ok(template_presenters.template_response(template)))
    })
  {
    Ok(resp) -> resp
    Error(resp) -> resp
  }
}

fn update_template(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  template_id: Int,
  org_id: Int,
  project_id: Int,
) -> wisp.Response {
  with_mutation_payload(req, decode_update_payload, fn(payload) {
    update_template_db(ctx, user, template_id, org_id, project_id, payload)
  })
}

fn update_template_db(
  ctx: auth.Ctx,
  user: StoredUser,
  template_id: Int,
  org_id: Int,
  project_id: Int,
  payload: template_payloads.UpdatePayload,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case
    run_config_transaction(db, fn(tx) {
      use template <- result.try(
        task_templates_db.update_template(
          tx,
          template_id,
          org_id,
          project_id,
          payload.name,
          payload.description,
          payload.type_id,
          payload.priority,
        )
        |> result.map_error(template_error_response),
      )
      use _ <- result.try(record_config_change(
        tx,
        user,
        project_id,
        config_audit.Template,
        template.id,
        config_audit.Updated,
        json.object([#("name", json.string(template.name))]),
      ))
      Ok(api.ok(template_presenters.template_response(template)))
    })
  {
    Ok(resp) -> resp
    Error(resp) -> resp
  }
}

fn delete_template(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  template_id: Int,
  org_id: Int,
  project_id: Int,
) -> wisp.Response {
  case csrf.require_csrf(req) {
    Error(resp) -> resp

    Ok(Nil) -> delete_template_db(ctx, user, template_id, org_id, project_id)
  }
}

fn delete_template_db(
  ctx: auth.Ctx,
  user: StoredUser,
  template_id: Int,
  org_id: Int,
  project_id: Int,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case
    run_config_transaction(db, fn(tx) {
      use template <- result.try(
        task_templates_db.get_template(tx, template_id)
        |> result.map_error(template_error_response),
      )
      use _ <- result.try(
        task_templates_db.delete_template(tx, template_id, org_id)
        |> result.map_error(template_error_response),
      )
      use _ <- result.try(record_config_change(
        tx,
        user,
        project_id,
        config_audit.Template,
        template.id,
        config_audit.Deleted,
        json.object([#("name", json.string(template.name))]),
      ))
      Ok(api.no_content())
    })
  {
    Ok(resp) -> resp
    Error(resp) -> resp
  }
}

fn template_error_response(error: service_error.ServiceError) -> wisp.Response {
  case error {
    service_error.InvalidReference(_) ->
      api.error(422, "VALIDATION_ERROR", "Invalid type_id")
    service_error.Conflict(message) -> api.error(409, "CONFLICT", message)
    _ -> service_error_response.to_response(error)
  }
}

fn database_error_response() -> wisp.Response {
  api.error(500, "INTERNAL", "Database error")
}

fn record_config_change(
  db: pog.Connection,
  user: StoredUser,
  project_id: Int,
  entity_type: config_audit.EntityType,
  entity_id: Int,
  change_type: config_audit.ChangeType,
  payload: json.Json,
) -> Result(Nil, wisp.Response) {
  config_audit.insert(
    db,
    user.org_id,
    project_id,
    user.id,
    entity_type,
    entity_id,
    change_type,
    payload,
  )
  |> result.map_error(service_error_response.to_response)
}

fn run_config_transaction(
  db: pog.Connection,
  callback: fn(pog.Connection) -> Result(a, wisp.Response),
) -> Result(a, wisp.Response) {
  case pog.transaction(db, callback) {
    Ok(value) -> Ok(value)
    Error(pog.TransactionRolledBack(resp)) -> Error(resp)
    Error(pog.TransactionQueryError(_)) -> Error(database_error_response())
  }
}

fn with_mutation_payload(
  req: wisp.Request,
  decode_payload,
  handle_payload: fn(payload) -> wisp.Response,
) -> wisp.Response {
  case csrf.require_csrf(req) {
    Error(resp) -> resp

    Ok(Nil) -> {
      use data <- wisp.require_json(req)

      case decode_payload(data) {
        Error(resp) -> resp
        Ok(payload) -> handle_payload(payload)
      }
    }
  }
}

fn decode_create_payload(
  data,
) -> Result(template_payloads.CreatePayload, wisp.Response) {
  case template_payloads.decode_create(data) {
    Error(_) -> Error(api.error(400, "VALIDATION_ERROR", "Invalid JSON"))
    Ok(payload) -> Ok(payload)
  }
}

fn decode_update_payload(
  data,
) -> Result(template_payloads.UpdatePayload, wisp.Response) {
  case template_payloads.decode_update(data) {
    Error(_) -> Error(api.error(400, "VALIDATION_ERROR", "Invalid JSON"))
    Ok(payload) -> Ok(payload)
  }
}
