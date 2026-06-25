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
//// - Map task operation responses into HTTP responses
////
//// ## Non-responsibilities
////
//// - Task type repository (see `use_case/task_types_db.gleam`)
//// - Task operation orchestration (see `use_case/workflows/handlers.gleam`)
////
//// ## Relationships
////
//// - Uses `http/auth.gleam` for user identity
//// - Uses `use_case/workflows/handlers.gleam` for domain operations

import gleam/http
import gleam/result
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/http/tasks/payload_responses
import scrumbringer_server/http/tasks/payloads
import scrumbringer_server/http/tasks/presenters
import scrumbringer_server/use_case/store_state.{type StoredUser}
import scrumbringer_server/use_case/workflows/handlers as workflow
import scrumbringer_server/use_case/workflows/types as workflow_types
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

  case list_task_types_payload(req, ctx, project_id) {
    Ok(resp) -> resp
    Error(resp) -> resp
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

  with_task_type_payload(req, ctx, project_id, fn(user, project_id, payload) {
    create_task_type_payload(ctx, user, project_id, payload)
  })
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
  with_task_type_payload(req, ctx, type_id, fn(user, type_id, payload) {
    update_task_type_payload(ctx, user, type_id, payload)
  })
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
  case delete_task_type_payload(req, ctx, type_id) {
    Ok(Nil) -> api.no_content()
    Error(resp) -> resp
  }
}

fn list_task_types_payload(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> Result(wisp.Response, wisp.Response) {
  let auth.Ctx(db: db, ..) = ctx

  use user <- result.try(auth.require_current_user_response(req, ctx))
  use project_id <- result.try(api.parse_id(project_id))

  case workflow.handle(db, workflow_types.ListTaskTypes(project_id, user.id)) {
    Ok(response) -> list_task_types_response(response)
    Error(error) -> Error(list_task_types_error_response(error))
  }
}

fn create_task_type_payload(
  ctx: auth.Ctx,
  user: StoredUser,
  project_id: Int,
  payload: payloads.TaskTypePayload,
) -> Result(wisp.Response, wisp.Response) {
  let auth.Ctx(db: db, ..) = ctx
  let payloads.TaskTypePayload(
    name: name,
    icon: icon,
    capability_id: capability_id,
  ) = payload

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
    Ok(response) -> create_task_type_response(response)
    Error(error) -> Error(create_task_type_error_response(error))
  }
}

fn update_task_type_payload(
  ctx: auth.Ctx,
  user: StoredUser,
  type_id: Int,
  payload: payloads.TaskTypePayload,
) -> Result(wisp.Response, wisp.Response) {
  let auth.Ctx(db: db, ..) = ctx
  let payloads.TaskTypePayload(
    name: name,
    icon: icon,
    capability_id: capability_id,
  ) = payload

  case
    workflow.handle(
      db,
      workflow_types.UpdateTaskType(type_id, user.id, name, icon, capability_id),
    )
  {
    Ok(response) -> update_task_type_response(response)
    Error(error) -> Error(update_task_type_error_response(error))
  }
}

fn delete_task_type_payload(
  req: wisp.Request,
  ctx: auth.Ctx,
  type_id: String,
) -> Result(Nil, wisp.Response) {
  let auth.Ctx(db: db, ..) = ctx

  use #(user, type_id) <- result.try(require_write_context(req, ctx, type_id))

  case workflow.handle(db, workflow_types.DeleteTaskType(type_id, user.id)) {
    Ok(response) -> delete_task_type_response(response)
    Error(error) -> Error(delete_task_type_error_response(error))
  }
}

fn require_write_context(
  req: wisp.Request,
  ctx: auth.Ctx,
  id: String,
) -> Result(#(StoredUser, Int), wisp.Response) {
  use user <- result.try(auth.require_current_user_response(req, ctx))
  use Nil <- result.try(csrf.require_csrf(req))
  use id <- result.try(api.parse_id(id))

  Ok(#(user, id))
}

fn with_task_type_payload(
  req: wisp.Request,
  ctx: auth.Ctx,
  id: String,
  handle_payload: fn(StoredUser, Int, payloads.TaskTypePayload) ->
    Result(wisp.Response, wisp.Response),
) -> wisp.Response {
  case require_write_context(req, ctx, id) {
    Error(resp) -> resp
    Ok(#(user, id)) -> {
      use data <- wisp.require_json(req)
      case decode_task_type_payload(data) {
        Error(resp) -> resp
        Ok(payload) ->
          case handle_payload(user, id, payload) {
            Ok(resp) -> resp
            Error(resp) -> resp
          }
      }
    }
  }
}

fn decode_task_type_payload(
  data,
) -> Result(payloads.TaskTypePayload, wisp.Response) {
  payloads.decode_task_type(data)
  |> result.map_error(payload_responses.decode_error)
}

fn list_task_types_response(
  response: workflow_types.Response,
) -> Result(wisp.Response, wisp.Response) {
  case response {
    workflow_types.TaskTypesList(task_types) ->
      Ok(api.ok(presenters.task_types_response(task_types)))
    workflow_types.TaskTypeCreated(_)
    | workflow_types.TaskTypeUpdated(_)
    | workflow_types.TaskTypeDeleted(_)
    | workflow_types.TaskDeleted(_)
    | workflow_types.TasksList(_)
    | workflow_types.TaskResult(_) -> Error(unexpected_response())
  }
}

fn create_task_type_response(
  response: workflow_types.Response,
) -> Result(wisp.Response, wisp.Response) {
  case response {
    workflow_types.TaskTypeCreated(task_type) ->
      Ok(api.ok(presenters.task_type_response(task_type)))
    workflow_types.TaskTypesList(_)
    | workflow_types.TaskTypeUpdated(_)
    | workflow_types.TaskTypeDeleted(_)
    | workflow_types.TaskDeleted(_)
    | workflow_types.TasksList(_)
    | workflow_types.TaskResult(_) -> Error(unexpected_response())
  }
}

fn update_task_type_response(
  response: workflow_types.Response,
) -> Result(wisp.Response, wisp.Response) {
  case response {
    workflow_types.TaskTypeUpdated(task_type) ->
      Ok(api.ok(presenters.task_type_response(task_type)))
    workflow_types.TaskTypesList(_)
    | workflow_types.TaskTypeCreated(_)
    | workflow_types.TaskTypeDeleted(_)
    | workflow_types.TaskDeleted(_)
    | workflow_types.TasksList(_)
    | workflow_types.TaskResult(_) -> Error(unexpected_response())
  }
}

fn delete_task_type_response(
  response: workflow_types.Response,
) -> Result(Nil, wisp.Response) {
  case response {
    workflow_types.TaskTypeDeleted(_) -> Ok(Nil)
    workflow_types.TaskTypesList(_)
    | workflow_types.TaskTypeCreated(_)
    | workflow_types.TaskTypeUpdated(_)
    | workflow_types.TaskDeleted(_)
    | workflow_types.TasksList(_)
    | workflow_types.TaskResult(_) -> Error(unexpected_response())
  }
}

fn list_task_types_error_response(error: workflow_types.Error) -> wisp.Response {
  case error {
    workflow_types.NotAuthorized -> forbidden_response()
    workflow_types.DbError(_) -> database_error_response()
    workflow_types.NotFound
    | workflow_types.ValidationError(_)
    | workflow_types.TaskParentCardInheritedFromCard
    | workflow_types.CardHasChildCards
    | workflow_types.InvalidMovePoolToParentCard
    | workflow_types.TaskTypeAlreadyExists
    | workflow_types.TaskTypeInUse
    | workflow_types.AlreadyClaimed
    | workflow_types.TaskBlockedByDependencies(_)
    | workflow_types.TaskNotClaimable
    | workflow_types.TaskHasOperationalHistory
    | workflow_types.InvalidTransition
    | workflow_types.VersionConflict
    | workflow_types.ClaimOwnershipConflict(_) -> unexpected_error()
  }
}

fn create_task_type_error_response(error: workflow_types.Error) -> wisp.Response {
  case error {
    workflow_types.NotAuthorized -> forbidden_response()
    workflow_types.TaskTypeAlreadyExists ->
      api.error(422, "VALIDATION_ERROR", "Task type name already exists")
    workflow_types.ValidationError(message) ->
      api.error(422, "VALIDATION_ERROR", message)
    workflow_types.DbError(_) -> database_error_response()
    workflow_types.NotFound
    | workflow_types.TaskParentCardInheritedFromCard
    | workflow_types.CardHasChildCards
    | workflow_types.InvalidMovePoolToParentCard
    | workflow_types.TaskTypeInUse
    | workflow_types.AlreadyClaimed
    | workflow_types.TaskBlockedByDependencies(_)
    | workflow_types.TaskNotClaimable
    | workflow_types.TaskHasOperationalHistory
    | workflow_types.InvalidTransition
    | workflow_types.VersionConflict
    | workflow_types.ClaimOwnershipConflict(_) -> unexpected_error()
  }
}

fn update_task_type_error_response(error: workflow_types.Error) -> wisp.Response {
  case error {
    workflow_types.NotAuthorized -> forbidden_response()
    workflow_types.ValidationError(message) ->
      api.error(422, "VALIDATION_ERROR", message)
    workflow_types.TaskTypeAlreadyExists ->
      api.error(422, "VALIDATION_ERROR", "Task type name already exists")
    workflow_types.NotFound -> not_found_response()
    workflow_types.DbError(_) -> database_error_response()
    workflow_types.TaskParentCardInheritedFromCard
    | workflow_types.CardHasChildCards
    | workflow_types.InvalidMovePoolToParentCard
    | workflow_types.TaskTypeInUse
    | workflow_types.AlreadyClaimed
    | workflow_types.TaskBlockedByDependencies(_)
    | workflow_types.TaskNotClaimable
    | workflow_types.TaskHasOperationalHistory
    | workflow_types.InvalidTransition
    | workflow_types.VersionConflict
    | workflow_types.ClaimOwnershipConflict(_) -> unexpected_error()
  }
}

fn delete_task_type_error_response(error: workflow_types.Error) -> wisp.Response {
  case error {
    workflow_types.NotAuthorized -> forbidden_response()
    workflow_types.TaskTypeInUse ->
      api.error(422, "VALIDATION_ERROR", "Task type is in use")
    workflow_types.NotFound -> not_found_response()
    workflow_types.DbError(_) -> database_error_response()
    workflow_types.ValidationError(_)
    | workflow_types.TaskParentCardInheritedFromCard
    | workflow_types.CardHasChildCards
    | workflow_types.InvalidMovePoolToParentCard
    | workflow_types.TaskTypeAlreadyExists
    | workflow_types.AlreadyClaimed
    | workflow_types.TaskBlockedByDependencies(_)
    | workflow_types.TaskNotClaimable
    | workflow_types.TaskHasOperationalHistory
    | workflow_types.InvalidTransition
    | workflow_types.VersionConflict
    | workflow_types.ClaimOwnershipConflict(_) -> unexpected_error()
  }
}

fn forbidden_response() -> wisp.Response {
  api.error(403, "FORBIDDEN", "Forbidden")
}

fn not_found_response() -> wisp.Response {
  api.error(404, "NOT_FOUND", "Not found")
}

fn database_error_response() -> wisp.Response {
  api.error(500, "INTERNAL", "Database error")
}

fn unexpected_response() -> wisp.Response {
  api.error(500, "INTERNAL", "Unexpected response")
}

fn unexpected_error() -> wisp.Response {
  api.error(500, "INTERNAL", "Unexpected error")
}
