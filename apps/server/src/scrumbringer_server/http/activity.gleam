//// HTTP handlers for card and task activity feeds.

import domain/card.{type Card}
import domain/project/id as project_id
import domain/project/permissions
import domain/project_role
import domain/task.{type Task}
import domain/user/id as user_id
import gleam/http
import gleam/option
import gleam/result
import pog
import scrumbringer_server/http/activity/presenters
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/query
import scrumbringer_server/http/service_error_response
import scrumbringer_server/repository/tasks/queries as tasks_queries
import scrumbringer_server/use_case/activity_db
import scrumbringer_server/use_case/authorization
import scrumbringer_server/use_case/cards_db
import scrumbringer_server/use_case/store_state.{type StoredUser}
import wisp

const default_limit = 30

const min_limit = 1

const max_limit = 100

pub fn handle_task_activity(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case auth.require_current_user_response(req, ctx) {
    Error(resp) -> resp
    Ok(user) -> handle_task_activity_for_user(req, ctx, user, task_id)
  }
}

pub fn handle_card_activity(
  req: wisp.Request,
  ctx: auth.Ctx,
  card_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case auth.require_current_user_response(req, ctx) {
    Error(resp) -> resp
    Ok(user) -> handle_card_activity_for_user(req, ctx, user, card_id)
  }
}

fn handle_task_activity_for_user(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  task_id: String,
) -> wisp.Response {
  case api.parse_id(task_id), parse_limit(req) {
    Error(resp), _ -> resp
    _, Error(resp) -> resp
    Ok(task_id), Ok(limit) -> list_task_activity(ctx, user, task_id, limit)
  }
}

fn handle_card_activity_for_user(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  card_id: String,
) -> wisp.Response {
  case api.parse_id(card_id), parse_limit(req) {
    Error(resp), _ -> resp
    _, Error(resp) -> resp
    Ok(card_id), Ok(limit) -> list_card_activity(ctx, user, card_id, limit)
  }
}

fn parse_limit(req: wisp.Request) -> Result(Int, wisp.Response) {
  case
    query.bounded_int(
      wisp.get_query(req),
      "limit",
      default_limit,
      min_limit,
      max_limit,
    )
  {
    Ok(limit) -> Ok(limit)
    Error(_) -> Error(api.error(400, "BAD_REQUEST", "Invalid limit"))
  }
}

fn list_task_activity(
  ctx: auth.Ctx,
  user: StoredUser,
  task_id: Int,
  limit: Int,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case task_activity_payload(db, user, task_id, limit) {
    Ok(resp) -> resp
    Error(resp) -> resp
  }
}

fn task_activity_payload(
  db: pog.Connection,
  user: StoredUser,
  task_id: Int,
  limit: Int,
) -> Result(wisp.Response, wisp.Response) {
  use task <- result.try(require_task_access(db, task_id, user.id))
  use _ <- result.try(require_read_history(db, user, task.project_id))

  case activity_db.list_for_task(db, task_id, limit) {
    Ok(events) -> Ok(api.ok(presenters.activity_response(events)))
    Error(error) -> Error(activity_error_response(error))
  }
}

fn list_card_activity(
  ctx: auth.Ctx,
  user: StoredUser,
  card_id: Int,
  limit: Int,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case card_activity_payload(db, user, card_id, limit) {
    Ok(resp) -> resp
    Error(resp) -> resp
  }
}

fn card_activity_payload(
  db: pog.Connection,
  user: StoredUser,
  card_id: Int,
  limit: Int,
) -> Result(wisp.Response, wisp.Response) {
  use card <- result.try(require_card_access(db, card_id, user.id))
  use _ <- result.try(require_read_history(db, user, card.project_id))

  case activity_db.list_for_card(db, card_id, limit) {
    Ok(events) -> Ok(api.ok(presenters.activity_response(events)))
    Error(error) -> Error(activity_error_response(error))
  }
}

fn require_task_access(
  db: pog.Connection,
  task_id: Int,
  viewer_id: Int,
) -> Result(Task, wisp.Response) {
  case tasks_queries.get_task_for_user(db, task_id, viewer_id) {
    Ok(task) -> Ok(task)
    Error(error) -> Error(service_error_response.to_database_response(error))
  }
}

fn require_card_access(
  db: pog.Connection,
  card_id: Int,
  viewer_id: Int,
) -> Result(Card, wisp.Response) {
  case cards_db.get_card(db, card_id, viewer_id) {
    Ok(card) ->
      case authorization.is_project_member(db, viewer_id, card.project_id) {
        True -> Ok(card)
        False -> Error(not_found_response())
      }
    Error(cards_db.CardNotFound) -> Error(not_found_response())
    Error(_) -> Error(database_error_response())
  }
}

fn require_read_history(
  db: pog.Connection,
  user: StoredUser,
  target_project_id: Int,
) -> Result(Nil, wisp.Response) {
  let actor =
    permissions.project_actor(
      user_id.new(user.id),
      project_id.new(target_project_id),
      user.org_role,
      project_role_for_member(db, user.id, target_project_id),
    )

  case
    permissions.require_read_history(actor, project_id.new(target_project_id))
  {
    Ok(_) -> Ok(Nil)
    Error(permissions.NotProjectMember) -> Error(not_found_response())
    Error(permissions.InsufficientProjectPrivilege) ->
      Error(api.error(403, "FORBIDDEN", "Forbidden"))
  }
}

fn project_role_for_member(
  db: pog.Connection,
  viewer_id: Int,
  target_project_id: Int,
) -> option.Option(project_role.ProjectRole) {
  case authorization.is_project_member(db, viewer_id, target_project_id) {
    True -> option.Some(project_role.Member)
    False -> option.None
  }
}

fn activity_error_response(error: activity_db.ActivityError) -> wisp.Response {
  case error {
    activity_db.DbError(_) -> database_error_response()
    activity_db.UnknownAuditKind(_) -> database_error_response()
    activity_db.InvalidSubject(_) -> database_error_response()
  }
}

fn not_found_response() -> wisp.Response {
  api.error(404, "NOT_FOUND", "Not found")
}

fn database_error_response() -> wisp.Response {
  api.error(500, "INTERNAL", "Database error")
}
