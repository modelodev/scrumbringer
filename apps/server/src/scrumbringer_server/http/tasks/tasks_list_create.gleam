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
//// - Map workflow results into HTTP responses
////
//// ## Non-responsibilities
////
//// - Task persistence (see `persistence/tasks/queries.gleam`)
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
import scrumbringer_server/http/tasks/filters
import scrumbringer_server/http/tasks/presenters
import scrumbringer_server/services/store_state.{type StoredUser}
import scrumbringer_server/services/workflows/handlers as workflow
import scrumbringer_server/services/workflows/types as workflow_types
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

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")
    Ok(user) -> list_tasks_for_user(req, ctx, user, project_id)
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

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")
    Ok(user) -> create_task_for_user(req, ctx, user, project_id)
  }
}

fn list_tasks_for_user(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  project_id: String,
) -> wisp.Response {
  case parse_project_id(project_id) {
    Error(resp) -> resp
    Ok(project_id) -> list_tasks_for_project(req, ctx, user, project_id)
  }
}

fn list_tasks_for_project(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  project_id: Int,
) -> wisp.Response {
  let query = wisp.get_query(req)

  case filters.parse_task_filters(query) {
    Error(resp) -> resp
    Ok(task_filters) ->
      list_tasks_with_filters(ctx, user, project_id, task_filters)
  }
}

fn list_tasks_with_filters(
  ctx: auth.Ctx,
  user: StoredUser,
  project_id: Int,
  task_filters: workflow_types.TaskFilters,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  // Justification: nested case maps workflow results into HTTP responses.
  case
    workflow.handle(
      db,
      workflow_types.ListTasks(project_id, user.id, task_filters),
    )
  {
    Ok(workflow_types.TasksList(tasks)) ->
      api.ok(
        json.object([#("tasks", json.array(tasks, of: presenters.task_json))]),
      )

    Ok(_) -> api.error(500, "INTERNAL", "Unexpected response")
    Error(workflow_types.NotAuthorized) ->
      api.error(403, "FORBIDDEN", "Forbidden")
    Error(workflow_types.DbError(_)) ->
      api.error(500, "INTERNAL", "Database error")
    Error(_) -> api.error(500, "INTERNAL", "Unexpected error")
  }
}

fn create_task_for_user(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  project_id: String,
) -> wisp.Response {
  case csrf.require_csrf(req) {
    Error(resp) -> resp
    Ok(Nil) -> create_task_with_csrf(req, ctx, user, project_id)
  }
}

fn create_task_with_csrf(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  project_id: String,
) -> wisp.Response {
  case parse_project_id(project_id) {
    Error(resp) -> resp
    Ok(project_id) -> create_task_with_project(req, ctx, user, project_id)
  }
}

fn create_task_with_project(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  project_id: Int,
) -> wisp.Response {
  use data <- wisp.require_json(req)

  case decode_create_payload(data) {
    Error(resp) -> resp

    Ok(#(title, description, priority, type_id, card_id, milestone_id)) ->
      create_task_db(
        ctx,
        user,
        project_id,
        title,
        description,
        priority,
        type_id,
        card_id,
        milestone_id,
      )
  }
}

fn create_task_db(
  ctx: auth.Ctx,
  user: StoredUser,
  project_id: Int,
  title: String,
  description: String,
  priority: Int,
  type_id: Int,
  card_id: Option(Int),
  milestone_id: Option(Int),
) -> wisp.Response {
  case card_id, milestone_id {
    Some(_), Some(_) ->
      api.error(
        422,
        "TASK_MILESTONE_INHERITED_FROM_CARD",
        "Task milestone is inherited from card",
      )
    _, _ ->
      create_task_db_insert(
        ctx,
        user,
        project_id,
        title,
        description,
        priority,
        type_id,
        card_id,
        milestone_id,
      )
  }
}

fn create_task_db_insert(
  ctx: auth.Ctx,
  user: StoredUser,
  project_id: Int,
  title: String,
  description: String,
  priority: Int,
  type_id: Int,
  card_id: Option(Int),
  milestone_id: Option(Int),
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  // Justification: nested case maps workflow results into HTTP responses.
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
        milestone_id,
      ),
    )
  {
    Ok(workflow_types.TaskResult(task)) ->
      api.ok(json.object([#("task", presenters.task_json(task))]))

    Ok(_) -> api.error(500, "INTERNAL", "Unexpected response")
    Error(workflow_types.NotAuthorized) ->
      api.error(403, "FORBIDDEN", "Forbidden")
    Error(workflow_types.ValidationError(msg)) ->
      api.error(422, "VALIDATION_ERROR", msg)
    Error(workflow_types.DbError(_)) ->
      api.error(500, "INTERNAL", "Database error")
    Error(_) -> api.error(500, "INTERNAL", "Unexpected error")
  }
}

fn decode_create_payload(
  data: dynamic.Dynamic,
) -> Result(
  #(String, String, Int, Int, Option(Int), Option(Int)),
  wisp.Response,
) {
  let decoder = {
    use title <- decode.field("title", decode.string)
    use description <- decode.optional_field("description", "", decode.string)
    use priority <- decode.field("priority", decode.int)
    use type_id <- decode.field("type_id", decode.int)
    use card_id <- decode.optional_field(
      "card_id",
      None,
      decode.optional(decode.int),
    )
    use milestone_id <- decode.optional_field(
      "milestone_id",
      None,
      decode.optional(decode.int),
    )
    decode.success(#(
      title,
      description,
      priority,
      type_id,
      card_id,
      milestone_id,
    ))
  }

  case decode.run(data, decoder) {
    Error(_) -> Error(api.error(400, "VALIDATION_ERROR", "Invalid JSON"))
    Ok(payload) -> Ok(payload)
  }
}

fn parse_project_id(project_id: String) -> Result(Int, wisp.Response) {
  case int.parse(project_id) {
    Ok(id) -> Ok(id)
    Error(_) -> Error(api.error(404, "NOT_FOUND", "Not found"))
  }
}
