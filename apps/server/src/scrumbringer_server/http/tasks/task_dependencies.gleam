////
//// Task dependencies HTTP handlers.
////

import gleam/dynamic
import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/list
import gleam/result
import pog

import domain/task.{TaskDependency}
import domain/task_status.{Completed}
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/authorization
import scrumbringer_server/http/csrf
import scrumbringer_server/http/tasks/presenters
import scrumbringer_server/persistence/tasks/mappers.{type Task}
import scrumbringer_server/persistence/tasks/queries as tasks_queries
import scrumbringer_server/services/store_state.{type StoredUser}
import scrumbringer_server/services/task_dependencies_db
import wisp

pub fn handle_task_dependencies(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  case req.method {
    http.Get -> handle_list(req, ctx, task_id)
    http.Post -> handle_create(req, ctx, task_id)
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}

pub fn handle_task_dependency(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
  depends_on_task_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Delete)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")
    Ok(user) -> delete_dependency(req, ctx, user, task_id, depends_on_task_id)
  }
}

fn handle_list(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")
    Ok(user) -> list_dependencies(req, ctx, user, task_id)
  }
}

fn handle_create(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")
    Ok(user) -> create_dependency(req, ctx, user, task_id)
  }
}

fn list_dependencies(
  _req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  task_id: String,
) -> wisp.Response {
  case parse_task_id(task_id) {
    Error(resp) -> resp
    Ok(task_id) -> list_dependencies_for_task(ctx, user, task_id)
  }
}

fn list_dependencies_for_task(
  ctx: auth.Ctx,
  user: StoredUser,
  task_id: Int,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case require_task_access(db, task_id, user.id) {
    Error(resp) -> resp
    Ok(Nil) ->
      case task_dependencies_db.list_dependencies_for_task(db, task_id) {
        Ok(deps) ->
          api.ok(
            json.object([
              #(
                "dependencies",
                json.array(deps, of: presenters.dependency_json),
              ),
            ]),
          )
        Error(task_dependencies_db.ListDbError(_)) ->
          api.error(500, "INTERNAL", "Database error")
      }
  }
}

fn create_dependency(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  task_id: String,
) -> wisp.Response {
  case csrf.require_csrf(req) {
    Error(resp) -> resp
    Ok(Nil) -> create_dependency_with_csrf(req, ctx, user, task_id)
  }
}

fn create_dependency_with_csrf(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  task_id: String,
) -> wisp.Response {
  case parse_task_id(task_id) {
    Error(resp) -> resp
    Ok(task_id) -> {
      use data <- wisp.require_json(req)
      case decode_dependency_payload(data) {
        Error(resp) -> resp
        Ok(depends_on_task_id) ->
          create_dependency_for_task(ctx, user, task_id, depends_on_task_id)
      }
    }
  }
}

fn create_dependency_for_task(
  ctx: auth.Ctx,
  user: StoredUser,
  task_id: Int,
  depends_on_task_id: Int,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case task_id == depends_on_task_id {
    True -> api.error(422, "VALIDATION_ERROR", "Task cannot depend on itself")
    False ->
      case require_task_access(db, task_id, user.id) {
        Error(resp) -> resp
        Ok(Nil) ->
          create_dependency_checked(db, user, task_id, depends_on_task_id)
      }
  }
}

fn create_dependency_checked(
  db: pog.Connection,
  user: StoredUser,
  task_id: Int,
  depends_on_task_id: Int,
) -> wisp.Response {
  case tasks_queries.get_task_for_user(db, task_id, user.id) {
    Error(tasks_queries.NotFound) -> api.error(404, "NOT_FOUND", "Not found")
    Error(tasks_queries.DbError(_)) ->
      api.error(500, "INTERNAL", "Database error")

    Ok(task) ->
      case
        authorization.require_project_manager_with_org_bypass(
          db,
          user,
          task.project_id,
        )
      {
        Error(resp) -> resp
        Ok(Nil) ->
          validate_dependency_target(db, user, task, depends_on_task_id)
      }
  }
}

fn validate_dependency_target(
  db: pog.Connection,
  user: StoredUser,
  task: Task,
  depends_on_task_id: Int,
) -> wisp.Response {
  case tasks_queries.get_task_for_user(db, depends_on_task_id, user.id) {
    Error(tasks_queries.NotFound) -> api.error(404, "NOT_FOUND", "Not found")
    Error(tasks_queries.DbError(_)) ->
      api.error(500, "INTERNAL", "Database error")
    Ok(depends_on_task) ->
      case depends_on_task.project_id != task.project_id {
        True ->
          api.error(
            422,
            "VALIDATION_ERROR",
            "Dependency must be in same project",
          )
        False ->
          case depends_on_task.status {
            Completed ->
              api.error(
                422,
                "VALIDATION_ERROR",
                "Dependency task is already completed",
              )
            _ ->
              validate_dependency_exists(
                db,
                task.id,
                depends_on_task_id,
                user.id,
              )
          }
      }
  }
}

fn validate_dependency_exists(
  db: pog.Connection,
  task_id: Int,
  depends_on_task_id: Int,
  user_id: Int,
) -> wisp.Response {
  case task_dependencies_db.list_dependencies_for_task(db, task_id) {
    Ok(deps) ->
      case
        list.any(deps, fn(dep) {
          let TaskDependency(depends_on_task_id: dep_id, ..) = dep
          dep_id == depends_on_task_id
        })
      {
        True -> api.error(422, "VALIDATION_ERROR", "Dependency already exists")
        False ->
          validate_dependency_cycle(db, task_id, depends_on_task_id, user_id)
      }
    Error(_) -> api.error(500, "INTERNAL", "Database error")
  }
}

fn validate_dependency_cycle(
  db: pog.Connection,
  task_id: Int,
  depends_on_task_id: Int,
  user_id: Int,
) -> wisp.Response {
  case would_create_cycle(db, task_id, depends_on_task_id) {
    Ok(True) ->
      api.error(422, "VALIDATION_ERROR", "Circular dependency detected")
    Ok(False) -> create_dependency_row(db, task_id, depends_on_task_id, user_id)
    Error(_) -> api.error(500, "INTERNAL", "Database error")
  }
}

fn create_dependency_row(
  db: pog.Connection,
  task_id: Int,
  depends_on_task_id: Int,
  user_id: Int,
) -> wisp.Response {
  case
    task_dependencies_db.create_dependency(
      db,
      task_id,
      depends_on_task_id,
      user_id,
    )
  {
    Ok(dep) ->
      api.ok(json.object([#("dependency", presenters.dependency_json(dep))]))
    Error(task_dependencies_db.UnexpectedEmptyResult) ->
      api.error(500, "INTERNAL", "Database error")
    Error(task_dependencies_db.CreateDbError(_)) ->
      api.error(500, "INTERNAL", "Database error")
  }
}

fn delete_dependency(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  task_id: String,
  depends_on_task_id: String,
) -> wisp.Response {
  case csrf.require_csrf(req) {
    Error(resp) -> resp
    Ok(Nil) ->
      delete_dependency_with_csrf(ctx, user, task_id, depends_on_task_id)
  }
}

fn delete_dependency_with_csrf(
  ctx: auth.Ctx,
  user: StoredUser,
  task_id: String,
  depends_on_task_id: String,
) -> wisp.Response {
  case parse_task_id(task_id) {
    Error(resp) -> resp
    Ok(task_id) ->
      case parse_task_id(depends_on_task_id) {
        Error(resp) -> resp
        Ok(depends_on_task_id) -> {
          let auth.Ctx(db: db, ..) = ctx
          case tasks_queries.get_task_for_user(db, task_id, user.id) {
            Error(tasks_queries.NotFound) ->
              api.error(404, "NOT_FOUND", "Not found")
            Error(tasks_queries.DbError(_)) ->
              api.error(500, "INTERNAL", "Database error")
            Ok(task) ->
              case
                authorization.require_project_manager_with_org_bypass(
                  db,
                  user,
                  task.project_id,
                )
              {
                Error(resp) -> resp
                Ok(Nil) ->
                  case
                    task_dependencies_db.delete_dependency(
                      db,
                      task_id,
                      depends_on_task_id,
                    )
                  {
                    Ok(Nil) -> api.no_content()
                    Error(task_dependencies_db.NotFound) ->
                      api.error(404, "NOT_FOUND", "Not found")
                    Error(task_dependencies_db.DeleteDbError(_)) ->
                      api.error(500, "INTERNAL", "Database error")
                  }
              }
          }
        }
      }
  }
}

fn decode_dependency_payload(
  data: dynamic.Dynamic,
) -> Result(Int, wisp.Response) {
  let decoder = {
    use depends_on_task_id <- decode.field("depends_on_task_id", decode.int)
    decode.success(depends_on_task_id)
  }

  decode.run(data, decoder)
  |> result.map_error(fn(_) {
    api.error(400, "VALIDATION_ERROR", "Invalid JSON")
  })
}

fn parse_task_id(value: String) -> Result(Int, wisp.Response) {
  case int.parse(value) {
    Ok(id) -> Ok(id)
    Error(_) -> Error(api.error(404, "NOT_FOUND", "Not found"))
  }
}

fn require_task_access(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
) -> Result(Nil, wisp.Response) {
  case tasks_queries.get_task_for_user(db, task_id, user_id) {
    Ok(_) -> Ok(Nil)
    Error(tasks_queries.NotFound) ->
      Error(api.error(404, "NOT_FOUND", "Not found"))
    Error(_) -> Error(api.error(500, "INTERNAL", "Database error"))
  }
}

fn would_create_cycle(
  db: pog.Connection,
  task_id: Int,
  depends_on_task_id: Int,
) -> Result(Bool, task_dependencies_db.ListError) {
  walk_dependency_graph(db, task_id, [depends_on_task_id], [])
}

fn walk_dependency_graph(
  db: pog.Connection,
  target_id: Int,
  queue: List(Int),
  visited: List(Int),
) -> Result(Bool, task_dependencies_db.ListError) {
  case queue {
    [] -> Ok(False)
    [current, ..rest] ->
      case current == target_id {
        True -> Ok(True)
        False ->
          case list.contains(visited, current) {
            True -> walk_dependency_graph(db, target_id, rest, visited)
            False ->
              case
                task_dependencies_db.list_dependency_ids_for_task(db, current)
              {
                Ok(next_ids) ->
                  walk_dependency_graph(
                    db,
                    target_id,
                    list.append(rest, next_ids),
                    [current, ..visited],
                  )
                Error(e) -> Error(e)
              }
          }
      }
  }
}
