//// Task type HTTP handler helpers.
////
//// ## Mission
////
//// Provide HTTP endpoints for listing, creating, and updating task types.
////
//// ## Responsibilities
////
//// - Parse route params and JSON payloads
//// - Authorize current user
//// - Map workflow responses into HTTP responses
////
//// ## Non-responsibilities
////
//// - Task type persistence (see `services/task_types_db.gleam`)
//// - Workflow orchestration (see `services/workflows/handlers.gleam`)
////
//// ## Relationships
////
//// - Uses `http/auth.gleam` for user identity
//// - Uses `services/workflows/handlers.gleam` for domain operations

import gleam/dynamic
import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/option.{type Option, None, Some}
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/http/tasks/presenters
import scrumbringer_server/services/store_state.{type StoredUser}
import scrumbringer_server/services/workflows/handlers as workflow
import scrumbringer_server/services/workflows/types as workflow_types
import wisp

/// Lists task types for a project.
///
/// Example:
///   handle_task_types_list(req, ctx, "42")
pub fn handle_task_types_list(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")
    Ok(user) -> list_task_types_for_user(ctx, user, project_id)
  }
}

/// Creates a task type for a project.
///
/// Example:
///   handle_task_types_create(req, ctx, "42")
pub fn handle_task_types_create(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")
    Ok(user) -> create_task_type_for_user(req, ctx, user, project_id)
  }
}

/// Updates a task type (PATCH).
///
/// Example:
///   handle_task_type_update(req, ctx, "12")
pub fn handle_task_type_update(
  req: wisp.Request,
  ctx: auth.Ctx,
  type_id: String,
) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")
    Ok(user) -> update_task_type_for_user(req, ctx, user, type_id)
  }
}

/// Deletes a task type if not in use (DELETE).
///
/// Example:
///   handle_task_type_delete(req, ctx, "12")
pub fn handle_task_type_delete(
  req: wisp.Request,
  ctx: auth.Ctx,
  type_id: String,
) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")
    Ok(user) -> delete_task_type_for_user(req, ctx, user, type_id)
  }
}

// Justification: nested case improves clarity for branching logic.
fn list_task_types_for_user(
  ctx: auth.Ctx,
  user: StoredUser,
  project_id: String,
) -> wisp.Response {
  case parse_project_id(project_id) {
    Error(resp) -> resp

    Ok(project_id) -> {
      let auth.Ctx(db: db, ..) = ctx

      // Justification: nested case maps workflow results into HTTP responses.
      case
        workflow.handle(db, workflow_types.ListTaskTypes(project_id, user.id))
      {
        Ok(workflow_types.TaskTypesList(task_types)) ->
          api.ok(
            json.object([
              #(
                "task_types",
                json.array(task_types, of: presenters.task_type_json),
              ),
            ]),
          )

        Ok(_) -> api.error(500, "INTERNAL", "Unexpected response")
        Error(workflow_types.NotAuthorized) ->
          api.error(403, "FORBIDDEN", "Forbidden")
        Error(workflow_types.DbError(_)) ->
          api.error(500, "INTERNAL", "Database error")
        Error(_) -> api.error(500, "INTERNAL", "Unexpected error")
      }
    }
  }
}

fn create_task_type_for_user(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  project_id: String,
) -> wisp.Response {
  case csrf.require_csrf(req) {
    Error(resp) -> resp
    Ok(Nil) -> create_task_type_with_csrf(req, ctx, user, project_id)
  }
}

// Justification: nested case improves clarity for branching logic.
fn create_task_type_with_csrf(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  project_id: String,
) -> wisp.Response {
  case parse_project_id(project_id) {
    Error(resp) -> resp

    Ok(project_id) -> {
      use data <- wisp.require_json(req)

      case decode_task_type_payload(data) {
        Error(resp) -> resp

        Ok(#(name, icon, capability_id)) ->
          create_task_type_db(ctx, user, project_id, name, icon, capability_id)
      }
    }
  }
}

fn create_task_type_db(
  ctx: auth.Ctx,
  user: StoredUser,
  project_id: Int,
  name: String,
  icon: String,
  capability_id: Option(Int),
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  // Justification: nested case maps workflow results into HTTP responses.
  case
    workflow.handle(
      db,
      workflow_types.CreateTaskType(
        project_id,
        user.id,
        user.org_id,
        name,
        icon,
        capability_id,
      ),
    )
  {
    Ok(workflow_types.TaskTypeCreated(task_type)) ->
      api.ok(
        json.object([
          #("task_type", presenters.task_type_json(task_type)),
        ]),
      )

    Ok(_) -> api.error(500, "INTERNAL", "Unexpected response")
    Error(workflow_types.NotAuthorized) ->
      api.error(403, "FORBIDDEN", "Forbidden")
    Error(workflow_types.TaskTypeAlreadyExists) ->
      api.error(422, "VALIDATION_ERROR", "Task type name already exists")
    Error(workflow_types.ValidationError(msg)) ->
      api.error(422, "VALIDATION_ERROR", msg)
    Error(workflow_types.DbError(_)) ->
      api.error(500, "INTERNAL", "Database error")
    Error(_) -> api.error(500, "INTERNAL", "Unexpected error")
  }
}

fn update_task_type_for_user(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  type_id: String,
) -> wisp.Response {
  case csrf.require_csrf(req) {
    Error(resp) -> resp
    Ok(Nil) -> update_task_type_with_csrf(req, ctx, user, type_id)
  }
}

// Justification: nested case improves clarity for branching logic.
fn update_task_type_with_csrf(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  type_id: String,
) -> wisp.Response {
  case parse_type_id(type_id) {
    Error(resp) -> resp

    Ok(type_id) -> {
      use data <- wisp.require_json(req)

      case decode_task_type_payload(data) {
        Error(resp) -> resp

        Ok(#(name, icon, capability_id)) ->
          update_task_type_db(ctx, user, type_id, name, icon, capability_id)
      }
    }
  }
}

fn update_task_type_db(
  ctx: auth.Ctx,
  user: StoredUser,
  type_id: Int,
  name: String,
  icon: String,
  capability_id: Option(Int),
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  // Justification: nested case maps workflow results into HTTP responses.
  case
    workflow.handle(
      db,
      workflow_types.UpdateTaskType(type_id, user.id, name, icon, capability_id),
    )
  {
    Ok(workflow_types.TaskTypeUpdated(task_type)) ->
      api.ok(
        json.object([
          #("task_type", presenters.task_type_json(task_type)),
        ]),
      )

    Ok(_) -> api.error(500, "INTERNAL", "Unexpected response")
    Error(workflow_types.NotAuthorized) ->
      api.error(403, "FORBIDDEN", "Forbidden")
    Error(workflow_types.ValidationError(msg)) ->
      api.error(422, "VALIDATION_ERROR", msg)
    Error(workflow_types.TaskTypeAlreadyExists) ->
      api.error(422, "VALIDATION_ERROR", "Task type name already exists")
    Error(workflow_types.NotFound) -> api.error(404, "NOT_FOUND", "Not found")
    Error(workflow_types.DbError(_)) ->
      api.error(500, "INTERNAL", "Database error")
    Error(_) -> api.error(500, "INTERNAL", "Unexpected error")
  }
}

fn delete_task_type_for_user(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  type_id: String,
) -> wisp.Response {
  case csrf.require_csrf(req) {
    Error(resp) -> resp
    Ok(Nil) -> delete_task_type_with_csrf(ctx, user, type_id)
  }
}

fn delete_task_type_with_csrf(
  ctx: auth.Ctx,
  user: StoredUser,
  type_id: String,
) -> wisp.Response {
  case parse_type_id(type_id) {
    Error(resp) -> resp
    Ok(type_id) -> delete_task_type_db(ctx, user, type_id)
  }
}

fn delete_task_type_db(
  ctx: auth.Ctx,
  user: StoredUser,
  type_id: Int,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  // Justification: nested case maps workflow results into HTTP responses.
  case workflow.handle(db, workflow_types.DeleteTaskType(type_id, user.id)) {
    Ok(workflow_types.TaskTypeDeleted(_)) -> api.no_content()
    Ok(_) -> api.error(500, "INTERNAL", "Unexpected response")
    Error(workflow_types.NotAuthorized) ->
      api.error(403, "FORBIDDEN", "Forbidden")
    Error(workflow_types.TaskTypeInUse) ->
      api.error(422, "VALIDATION_ERROR", "Task type is in use")
    Error(workflow_types.NotFound) -> api.error(404, "NOT_FOUND", "Not found")
    Error(workflow_types.DbError(_)) ->
      api.error(500, "INTERNAL", "Database error")
    Error(_) -> api.error(500, "INTERNAL", "Unexpected error")
  }
}

// Justification: nested case improves clarity for branching logic.
fn decode_task_type_payload(
  data: dynamic.Dynamic,
) -> Result(#(String, String, Option(Int)), wisp.Response) {
  let decoder = {
    use name <- decode.field("name", decode.string)
    use icon <- decode.field("icon", decode.string)
    use capability_id <- decode.optional_field("capability_id", 0, decode.int)
    decode.success(#(name, icon, capability_id))
  }

  case decode.run(data, decoder) {
    Error(_) -> Error(api.error(400, "VALIDATION_ERROR", "Invalid JSON"))
    Ok(#(name, icon, capability_id)) ->
      Ok(#(
        name,
        icon,
        // Justification: nested case maps optional capability sentinel.
        case capability_id {
          0 -> None
          id -> Some(id)
        },
      ))
  }
}


fn parse_project_id(project_id: String) -> Result(Int, wisp.Response) {
  case int.parse(project_id) {
    Ok(id) -> Ok(id)
    Error(_) -> Error(api.error(404, "NOT_FOUND", "Not found"))
  }
}

fn parse_type_id(type_id: String) -> Result(Int, wisp.Response) {
  case int.parse(type_id) {
    Ok(id) -> Ok(id)
    Error(_) -> Error(api.error(404, "NOT_FOUND", "Not found"))
  }
}
