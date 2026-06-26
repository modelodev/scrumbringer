//// Task list and create HTTP handler helpers.
////
//// ## Mission
////
//// Provide list and create task endpoints.
////
//// ## Responsibilities
////
//// - Parse route params and JSON payloads
//// - Authorize current user
//// - Map task operation results into HTTP responses
////
//// ## Non-responsibilities
////
//// - Task repository (see `repository/tasks/queries.gleam`)
//// - Task operation orchestration (see `use_case/workflows/handlers.gleam`)
////
//// ## Relationships
////
//// - Uses `http/auth.gleam` for user identity
//// - Uses `use_case/workflows/handlers.gleam` for domain operations

import gleam/http
import gleam/option.{type Option, Some}
import gleam/result
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/http/tasks/filters
import scrumbringer_server/http/tasks/payload_responses
import scrumbringer_server/http/tasks/payloads
import scrumbringer_server/http/tasks/presenters
import scrumbringer_server/use_case/store_state.{type StoredUser}
import scrumbringer_server/use_case/workflows/handlers as workflow
import scrumbringer_server/use_case/workflows/types as workflow_types
import wisp

/// Lists tasks for a project.
///
/// Example:
///   handle_tasks_list(req, ctx, "42")
pub fn handle_tasks_list(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case list_tasks_payload(req, ctx, project_id) {
    Ok(resp) -> resp
    Error(resp) -> resp
  }
}

/// Creates a task for a project.
///
/// Example:
///   handle_tasks_create(req, ctx, "42")
pub fn handle_tasks_create(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  with_create_payload(req, ctx, project_id, fn(user, project_id, payload) {
    create_task_payload(ctx, user, project_id, payload)
  })
}

fn list_tasks_payload(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> Result(wisp.Response, wisp.Response) {
  let auth.Ctx(db: db, ..) = ctx
  let query = wisp.get_query(req)
  use user <- result.try(auth.require_current_user_response(req, ctx))
  use project_id <- result.try(api.parse_id(project_id))
  use task_filters <- result.try(filters.parse_task_filters(query))

  case
    workflow.handle(
      db,
      workflow_types.ListTasks(project_id, user.id, task_filters),
    )
  {
    Ok(response) -> list_tasks_response(response)
    Error(error) -> Error(list_tasks_error_response(error))
  }
}

fn create_task_payload(
  ctx: auth.Ctx,
  user: StoredUser,
  project_id: Int,
  payload: payloads.CreateTaskPayload,
) -> Result(wisp.Response, wisp.Response) {
  let auth.Ctx(db: db, ..) = ctx
  let payloads.CreateTaskPayload(
    title: title,
    description: description,
    priority: priority,
    type_id: type_id,
    card_id: card_id,
    parent_card_id: parent_card_id,
  ) = payload

  use Nil <- result.try(require_parent_card_not_inherited(
    card_id,
    parent_card_id,
  ))

  case
    workflow.handle(
      db,
      workflow_types.CreateTask(
        project_id,
        user.id,
        user.org_id,
        title,
        description,
        priority,
        type_id,
        card_id,
        parent_card_id,
      ),
    )
  {
    Ok(response) -> create_task_response(response)
    Error(error) -> Error(create_task_error_response(error))
  }
}

fn require_create_context(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> Result(#(StoredUser, Int), wisp.Response) {
  use user <- result.try(auth.require_current_user_response(req, ctx))
  use Nil <- result.try(csrf.require_csrf(req))
  use project_id <- result.try(api.parse_id(project_id))

  Ok(#(user, project_id))
}

fn with_create_payload(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
  handle_payload: fn(StoredUser, Int, payloads.CreateTaskPayload) ->
    Result(wisp.Response, wisp.Response),
) -> wisp.Response {
  case require_create_context(req, ctx, project_id) {
    Error(resp) -> resp
    Ok(#(user, project_id)) -> {
      use data <- wisp.require_json(req)
      case decode_create_payload(data) {
        Error(resp) -> resp
        Ok(payload) ->
          case handle_payload(user, project_id, payload) {
            Ok(resp) -> resp
            Error(resp) -> resp
          }
      }
    }
  }
}

fn require_parent_card_not_inherited(
  card_id: Option(Int),
  parent_card_id: Option(Int),
) -> Result(Nil, wisp.Response) {
  case card_id, parent_card_id {
    Some(_), Some(_) ->
      Error(api.error(
        422,
        "TASK_PARENT_CARD_CONFLICT",
        "Task cannot specify both card_id and parent_card_id",
      ))
    _, _ -> Ok(Nil)
  }
}

fn decode_create_payload(
  data,
) -> Result(payloads.CreateTaskPayload, wisp.Response) {
  payloads.decode_create_task(data)
  |> result.map_error(payload_responses.decode_error)
}

fn list_tasks_response(
  response: workflow_types.Response,
) -> Result(wisp.Response, wisp.Response) {
  case response {
    workflow_types.TasksList(tasks) ->
      Ok(api.ok(presenters.tasks_response(tasks)))
    workflow_types.TaskTypesList(_)
    | workflow_types.TaskTypeCreated(_)
    | workflow_types.TaskTypeUpdated(_)
    | workflow_types.TaskTypeDeleted(_)
    | workflow_types.TaskDeleted(_)
    | workflow_types.TaskResult(_) -> Error(unexpected_response())
  }
}

fn create_task_response(
  response: workflow_types.Response,
) -> Result(wisp.Response, wisp.Response) {
  case response {
    workflow_types.TaskResult(task) ->
      Ok(api.ok(presenters.task_response(task)))
    workflow_types.TaskTypesList(_)
    | workflow_types.TaskTypeCreated(_)
    | workflow_types.TaskTypeUpdated(_)
    | workflow_types.TaskTypeDeleted(_)
    | workflow_types.TaskDeleted(_)
    | workflow_types.TasksList(_) -> Error(unexpected_response())
  }
}

fn list_tasks_error_response(error: workflow_types.Error) -> wisp.Response {
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
    | workflow_types.TaskCardNotActive
    | workflow_types.TaskHasOperationalHistory
    | workflow_types.InvalidTransition
    | workflow_types.VersionConflict
    | workflow_types.ClaimOwnershipConflict(_) -> unexpected_error()
  }
}

fn create_task_error_response(error: workflow_types.Error) -> wisp.Response {
  case error {
    workflow_types.NotAuthorized -> forbidden_response()
    workflow_types.ValidationError(message) ->
      api.error(422, "VALIDATION_ERROR", message)
    workflow_types.TaskParentCardInheritedFromCard ->
      inherited_parent_card_response()
    workflow_types.CardHasChildCards -> card_has_child_cards_response()
    workflow_types.DbError(_) -> database_error_response()
    workflow_types.NotFound
    | workflow_types.InvalidMovePoolToParentCard
    | workflow_types.TaskTypeAlreadyExists
    | workflow_types.TaskTypeInUse
    | workflow_types.AlreadyClaimed
    | workflow_types.TaskBlockedByDependencies(_)
    | workflow_types.TaskNotClaimable
    | workflow_types.TaskCardNotActive
    | workflow_types.TaskHasOperationalHistory
    | workflow_types.InvalidTransition
    | workflow_types.VersionConflict
    | workflow_types.ClaimOwnershipConflict(_) -> unexpected_error()
  }
}

fn inherited_parent_card_response() -> wisp.Response {
  api.error(
    422,
    "TASK_PARENT_CARD_CONFLICT",
    "Task cannot specify both card_id and parent_card_id",
  )
}

fn card_has_child_cards_response() -> wisp.Response {
  api.error(422, "CARD_HAS_CHILD_CARDS", "Card already contains child cards")
}

fn forbidden_response() -> wisp.Response {
  api.error(403, "FORBIDDEN", "Forbidden")
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
