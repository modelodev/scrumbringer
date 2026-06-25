////
//// domain_task.Task dependencies HTTP handlers.
////

import gleam/http
import gleam/list
import gleam/result
import pog

import domain/task as domain_task
import domain/task/state as task_state
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/authorization
import scrumbringer_server/http/csrf
import scrumbringer_server/http/service_error_response
import scrumbringer_server/http/tasks/payload_responses
import scrumbringer_server/http/tasks/payloads
import scrumbringer_server/http/tasks/presenters
import scrumbringer_server/repository/tasks/queries as tasks_queries
import scrumbringer_server/use_case/service_error
import scrumbringer_server/use_case/store_state.{type StoredUser}
import scrumbringer_server/use_case/task_dependencies_db
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

  case delete_dependency_payload(req, ctx, task_id, depends_on_task_id) {
    Ok(Nil) -> api.no_content()
    Error(resp) -> resp
  }
}

fn handle_list(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case list_dependencies_payload(req, ctx, task_id) {
    Ok(resp) -> resp
    Error(resp) -> resp
  }
}

fn handle_create(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  case require_create_context(req, ctx, task_id) {
    Error(resp) -> resp
    Ok(#(user, task_id)) -> {
      use data <- wisp.require_json(req)
      case decode_dependency_payload(data) {
        Error(resp) -> resp
        Ok(payload) ->
          case create_dependency_payload(ctx, user, task_id, payload) {
            Ok(resp) -> resp
            Error(resp) -> resp
          }
      }
    }
  }
}

fn require_create_context(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> Result(#(StoredUser, Int), wisp.Response) {
  use user <- result.try(auth.require_current_user_response(req, ctx))
  use Nil <- result.try(csrf.require_csrf(req))
  use task_id <- result.try(api.parse_id(task_id))

  Ok(#(user, task_id))
}

fn list_dependencies_payload(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> Result(wisp.Response, wisp.Response) {
  let auth.Ctx(db: db, ..) = ctx

  use user <- result.try(auth.require_current_user_response(req, ctx))
  use task_id <- result.try(api.parse_id(task_id))
  use Nil <- result.try(require_task_access(db, task_id, user.id))
  use deps <- result.try(fetch_dependencies(db, task_id))

  Ok(api.ok(presenters.dependencies_response(deps)))
}

fn create_dependency_payload(
  ctx: auth.Ctx,
  user: StoredUser,
  task_id: Int,
  payload: payloads.DependencyPayload,
) -> Result(wisp.Response, wisp.Response) {
  let auth.Ctx(db: db, ..) = ctx
  let payloads.DependencyPayload(depends_on_task_id: depends_on_task_id) =
    payload

  use Nil <- result.try(require_not_self_dependency(task_id, depends_on_task_id))
  use task <- result.try(fetch_task_database_response(db, task_id, user.id))
  use Nil <- result.try(authorization.require_project_manager_with_org_bypass(
    db,
    user,
    task.project_id,
  ))
  use depends_on_task <- result.try(fetch_task(db, depends_on_task_id, user.id))
  use Nil <- result.try(require_same_project(task, depends_on_task))
  use Nil <- result.try(require_dependency_open(depends_on_task))
  use Nil <- result.try(require_dependency_absent(
    db,
    task.id,
    depends_on_task_id,
  ))
  use Nil <- result.try(require_no_dependency_cycle(
    db,
    task_id,
    depends_on_task_id,
  ))
  use dependency <- result.try(create_dependency_row(
    db,
    task_id,
    depends_on_task_id,
    user.id,
  ))

  Ok(api.ok(presenters.dependency_response(dependency)))
}

fn create_dependency_row(
  db: pog.Connection,
  task_id: Int,
  depends_on_task_id: Int,
  user_id: Int,
) -> Result(domain_task.TaskDependency, wisp.Response) {
  case
    task_dependencies_db.create_dependency(
      db,
      task_id,
      depends_on_task_id,
      user_id,
    )
  {
    Ok(dep) -> Ok(dep)
    Error(error) -> Error(service_error_response.to_database_response(error))
  }
}

fn delete_dependency_payload(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
  depends_on_task_id: String,
) -> Result(Nil, wisp.Response) {
  let auth.Ctx(db: db, ..) = ctx

  use user <- result.try(auth.require_current_user_response(req, ctx))
  use Nil <- result.try(csrf.require_csrf(req))
  use task_id <- result.try(api.parse_id(task_id))
  use depends_on_task_id <- result.try(api.parse_id(depends_on_task_id))
  use task <- result.try(fetch_task(db, task_id, user.id))
  use Nil <- result.try(authorization.require_project_manager_with_org_bypass(
    db,
    user,
    task.project_id,
  ))

  delete_dependency_row(db, task_id, depends_on_task_id)
}

fn decode_dependency_payload(
  data,
) -> Result(payloads.DependencyPayload, wisp.Response) {
  payloads.decode_dependency(data)
  |> result.map_error(payload_responses.decode_error)
}

fn require_task_access(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
) -> Result(Nil, wisp.Response) {
  case tasks_queries.get_task_for_user(db, task_id, user_id) {
    Ok(_) -> Ok(Nil)
    Error(error) -> Error(service_error_response.to_database_response(error))
  }
}

fn fetch_task(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
) -> Result(domain_task.Task, wisp.Response) {
  case tasks_queries.get_task_for_user(db, task_id, user_id) {
    Ok(task) -> Ok(task)
    Error(error) -> Error(service_error_response.to_response(error))
  }
}

fn fetch_task_database_response(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
) -> Result(domain_task.Task, wisp.Response) {
  case tasks_queries.get_task_for_user(db, task_id, user_id) {
    Ok(task) -> Ok(task)
    Error(error) -> Error(service_error_response.to_database_response(error))
  }
}

fn fetch_dependencies(
  db: pog.Connection,
  task_id: Int,
) -> Result(List(domain_task.TaskDependency), wisp.Response) {
  case task_dependencies_db.list_dependencies_for_task(db, task_id) {
    Ok(deps) -> Ok(deps)
    Error(error) -> Error(service_error_response.to_response(error))
  }
}

fn require_not_self_dependency(
  task_id: Int,
  depends_on_task_id: Int,
) -> Result(Nil, wisp.Response) {
  case task_id == depends_on_task_id {
    True ->
      Error(api.error(
        422,
        "VALIDATION_ERROR",
        "domain_task.Task cannot depend on itself",
      ))
    False -> Ok(Nil)
  }
}

fn require_same_project(
  task: domain_task.Task,
  depends_on_task: domain_task.Task,
) -> Result(Nil, wisp.Response) {
  case depends_on_task.project_id != task.project_id {
    True ->
      Error(api.error(
        422,
        "VALIDATION_ERROR",
        "Dependency must be in same project",
      ))
    False -> Ok(Nil)
  }
}

fn require_dependency_open(
  depends_on_task: domain_task.Task,
) -> Result(Nil, wisp.Response) {
  case depends_on_task.state {
    task_state.Closed(..) ->
      Error(api.error(
        422,
        "VALIDATION_ERROR",
        "Dependency task is already closed",
      ))
    task_state.Available | task_state.Claimed(..) -> Ok(Nil)
  }
}

fn require_dependency_absent(
  db: pog.Connection,
  task_id: Int,
  depends_on_task_id: Int,
) -> Result(Nil, wisp.Response) {
  use deps <- result.try(fetch_dependencies_for_validation(db, task_id))

  case
    list.any(deps, fn(dep) {
      let domain_task.TaskDependency(depends_on_task_id: dep_id, ..) = dep
      dep_id == depends_on_task_id
    })
  {
    True ->
      Error(api.error(422, "VALIDATION_ERROR", "Dependency already exists"))
    False -> Ok(Nil)
  }
}

fn fetch_dependencies_for_validation(
  db: pog.Connection,
  task_id: Int,
) -> Result(List(domain_task.TaskDependency), wisp.Response) {
  case task_dependencies_db.list_dependencies_for_task(db, task_id) {
    Ok(deps) -> Ok(deps)
    Error(_) -> Error(database_error_response())
  }
}

fn require_no_dependency_cycle(
  db: pog.Connection,
  task_id: Int,
  depends_on_task_id: Int,
) -> Result(Nil, wisp.Response) {
  case would_create_cycle(db, task_id, depends_on_task_id) {
    Ok(True) ->
      Error(api.error(422, "VALIDATION_ERROR", "Circular dependency detected"))
    Ok(False) -> Ok(Nil)
    Error(_) -> Error(database_error_response())
  }
}

fn delete_dependency_row(
  db: pog.Connection,
  task_id: Int,
  depends_on_task_id: Int,
) -> Result(Nil, wisp.Response) {
  case task_dependencies_db.delete_dependency(db, task_id, depends_on_task_id) {
    Ok(Nil) -> Ok(Nil)
    Error(error) -> Error(service_error_response.to_response(error))
  }
}

fn database_error_response() -> wisp.Response {
  api.error(500, "INTERNAL", "Database error")
}

fn would_create_cycle(
  db: pog.Connection,
  task_id: Int,
  depends_on_task_id: Int,
) -> Result(Bool, service_error.ServiceError) {
  walk_dependency_graph(db, task_id, [depends_on_task_id], [])
}

fn walk_dependency_graph(
  db: pog.Connection,
  target_id: Int,
  queue: List(Int),
  visited: List(Int),
) -> Result(Bool, service_error.ServiceError) {
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
