//// HTTP handlers for milestones.

import domain/milestone as milestone_domain
import gleam/http
import gleam/list
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/http/json_payload
import scrumbringer_server/http/milestones/payloads as milestone_payloads
import scrumbringer_server/http/milestones/presenters as milestone_presenters
import scrumbringer_server/http/query
import scrumbringer_server/services/authorization
import scrumbringer_server/services/metrics_db
import scrumbringer_server/services/milestones_db
import wisp

fn milestone_not_found_response(include_metrics: Bool) -> wisp.Response {
  case include_metrics {
    True -> api.error(404, "not_found", "Milestone not found")
    False -> api.error(404, "NOT_FOUND", "Milestone not found")
  }
}

fn forbidden_project_member_response(include_metrics: Bool) -> wisp.Response {
  case include_metrics {
    True -> api.error(403, "forbidden", "Not a member of this project")
    False -> api.error(403, "FORBIDDEN", "Not a member of this project")
  }
}

fn milestone_error_response(
  error: milestones_db.MilestoneError,
) -> wisp.Response {
  case error {
    milestones_db.NotFound -> api.error(404, "NOT_FOUND", "Milestone not found")
    milestones_db.DeleteNotAllowed ->
      api.error(500, "INTERNAL", "Unexpected error")
    milestones_db.InvalidState(_) -> milestone_state_data_error()
    milestones_db.DbError(_) -> api.error(500, "INTERNAL", "Database error")
  }
}

pub fn handle_project_milestones(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: Int,
) -> wisp.Response {
  case req.method {
    http.Get -> handle_list(req, ctx, project_id)
    http.Post -> handle_create(req, ctx, project_id)
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}

pub fn handle_milestone(
  req: wisp.Request,
  ctx: auth.Ctx,
  milestone_id: Int,
) -> wisp.Response {
  case req.method {
    http.Get -> handle_get(req, ctx, milestone_id)
    http.Patch -> handle_patch(req, ctx, milestone_id)
    http.Delete -> handle_delete(req, ctx, milestone_id)
    _ -> wisp.method_not_allowed([http.Get, http.Patch, http.Delete])
  }
}

pub fn handle_activate(
  req: wisp.Request,
  ctx: auth.Ctx,
  milestone_id: Int,
) -> wisp.Response {
  case req.method {
    http.Post -> handle_activate_post(req, ctx, milestone_id)
    _ -> wisp.method_not_allowed([http.Post])
  }
}

fn handle_list(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: Int,
) -> wisp.Response {
  case auth.require_current_user_response(req, ctx) {
    Error(resp) -> resp
    Ok(user) -> {
      let auth.Ctx(db: db, ..) = ctx
      case authorization.is_project_member(db, user.id, project_id) {
        False -> api.error(403, "FORBIDDEN", "Not a member of this project")
        True ->
          case milestones_db.list_milestones(db, project_id) {
            Error(error) -> milestone_error_response(error)
            Ok(rows) -> api.ok(milestone_presenters.milestones_response(rows))
          }
      }
    }
  }
}

fn handle_get(
  req: wisp.Request,
  ctx: auth.Ctx,
  milestone_id: Int,
) -> wisp.Response {
  let include_metrics = wants_metrics(req)

  case auth.require_current_user_response(req, ctx) {
    Error(resp) -> resp
    Ok(user) -> {
      let auth.Ctx(db: db, ..) = ctx
      case milestones_db.get_milestone(db, milestone_id) {
        Error(milestones_db.NotFound) ->
          milestone_not_found_response(include_metrics)
        Error(error) -> milestone_error_response(error)
        Ok(milestone) -> {
          case
            authorization.is_project_member(db, user.id, milestone.project_id)
          {
            False -> forbidden_project_member_response(include_metrics)
            True -> {
              case include_metrics {
                True ->
                  case metrics_db.get_milestone_metrics(db, milestone.id) {
                    Ok(metrics) ->
                      api.ok(milestone_presenters.milestone_metrics_response(
                        milestone.id,
                        metrics,
                      ))
                    Error(metrics_db.NotFound) ->
                      api.error(404, "not_found", "Milestone not found")
                    Error(metrics_db.MetricsUnavailable) ->
                      api.error(
                        409,
                        "metrics_unavailable",
                        "Metrics unavailable",
                      )
                    Error(metrics_db.DbError(_)) ->
                      api.error(500, "internal", "Database error")
                  }
                False ->
                  api.ok(milestone_presenters.milestone_response(milestone))
              }
            }
          }
        }
      }
    }
  }
}

fn wants_metrics(req: wisp.Request) -> Bool {
  query.has_value(wisp.get_query(req), "include", "metrics")
}

fn handle_create(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: Int,
) -> wisp.Response {
  case auth.require_current_user_response(req, ctx) {
    Error(resp) -> resp
    Ok(user) -> {
      let auth.Ctx(db: db, ..) = ctx
      case authorization.is_project_manager(db, user.id, project_id) {
        False -> api.error(403, "FORBIDDEN", "Project admin role required")
        True -> {
          case csrf.require_csrf(req) {
            Error(resp) -> resp
            Ok(Nil) -> {
              json_payload.with_response(
                req,
                decode_create_payload,
                fn(payload) {
                  create_milestone_in_project(db, project_id, payload, user.id)
                },
              )
            }
          }
        }
      }
    }
  }
}

fn handle_activate_post(
  req: wisp.Request,
  ctx: auth.Ctx,
  milestone_id: Int,
) -> wisp.Response {
  case auth.require_current_user_response(req, ctx) {
    Error(resp) -> resp
    Ok(user) -> {
      let auth.Ctx(db: db, ..) = ctx

      case milestones_db.get_milestone(db, milestone_id) {
        Error(error) -> milestone_error_response(error)
        Ok(milestone) -> {
          case
            authorization.is_project_manager(db, user.id, milestone.project_id)
          {
            False -> api.error(403, "FORBIDDEN", "Project admin role required")
            True -> {
              case csrf.require_csrf(req) {
                Error(resp) -> resp
                Ok(Nil) -> {
                  case milestone.state {
                    milestone_domain.Ready ->
                      activate_ready_milestone(
                        db,
                        milestone_id,
                        milestone.project_id,
                      )
                    _ ->
                      api.error(
                        409,
                        "MILESTONE_ACTIVATION_IRREVERSIBLE",
                        "Milestone cannot be activated",
                      )
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

fn activate_ready_milestone(
  db: pog.Connection,
  milestone_id: Int,
  project_id: Int,
) -> wisp.Response {
  case has_other_active_milestone(db, milestone_id, project_id) {
    True ->
      api.error(
        409,
        "MILESTONE_ALREADY_ACTIVE",
        "Another milestone is already active",
      )
    False ->
      case milestones_db.activate_milestone(db, milestone_id, project_id) {
        Error(milestones_db.NotFound) ->
          api.error(
            409,
            "MILESTONE_ALREADY_ACTIVE",
            "Another milestone is already active",
          )
        Error(error) -> milestone_error_response(error)
        Ok(snapshot) ->
          api.ok(milestone_presenters.activation_response(snapshot))
      }
  }
}

fn has_other_active_milestone(
  db: pog.Connection,
  milestone_id: Int,
  project_id: Int,
) -> Bool {
  case milestones_db.list_milestones(db, project_id) {
    Error(_) -> False
    Ok(rows) ->
      rows
      |> list.any(fn(row) {
        row.milestone.id != milestone_id
        && row.milestone.state == milestone_domain.Active
      })
  }
}

fn handle_patch(
  req: wisp.Request,
  ctx: auth.Ctx,
  milestone_id: Int,
) -> wisp.Response {
  case auth.require_current_user_response(req, ctx) {
    Error(resp) -> resp
    Ok(user) -> {
      let auth.Ctx(db: db, ..) = ctx
      case milestones_db.get_milestone(db, milestone_id) {
        Error(error) -> milestone_error_response(error)
        Ok(milestone) -> {
          case
            authorization.is_project_manager(db, user.id, milestone.project_id)
          {
            False -> api.error(403, "FORBIDDEN", "Project admin role required")
            True -> {
              case csrf.require_csrf(req) {
                Error(resp) -> resp
                Ok(Nil) -> {
                  json_payload.with_response(
                    req,
                    decode_patch_payload,
                    fn(payload) {
                      update_milestone_in_db(db, milestone_id, payload)
                    },
                  )
                }
              }
            }
          }
        }
      }
    }
  }
}

fn handle_delete(
  req: wisp.Request,
  ctx: auth.Ctx,
  milestone_id: Int,
) -> wisp.Response {
  case auth.require_current_user_response(req, ctx) {
    Error(resp) -> resp
    Ok(user) -> {
      let auth.Ctx(db: db, ..) = ctx
      case milestones_db.get_milestone(db, milestone_id) {
        Error(error) -> milestone_error_response(error)
        Ok(milestone) -> {
          case
            authorization.is_project_manager(db, user.id, milestone.project_id)
          {
            False -> api.error(403, "FORBIDDEN", "Project admin role required")
            True -> {
              case csrf.require_csrf(req) {
                Error(resp) -> resp
                Ok(Nil) ->
                  case milestones_db.delete_milestone(db, milestone_id) {
                    Ok(Nil) -> api.no_content()
                    Error(milestones_db.NotFound) ->
                      api.error(404, "NOT_FOUND", "Milestone not found")
                    Error(milestones_db.DeleteNotAllowed) ->
                      api.error(
                        409,
                        "MILESTONE_DELETE_NOT_ALLOWED",
                        "Milestone must be ready and empty",
                      )
                    Error(error) -> milestone_error_response(error)
                  }
              }
            }
          }
        }
      }
    }
  }
}

fn milestone_state_data_error() -> wisp.Response {
  api.error(500, "INTERNAL", "Invalid milestone state in database")
}

fn create_milestone_in_project(
  db: pog.Connection,
  project_id: Int,
  payload: milestone_payloads.CreatePayload,
  user_id: Int,
) -> wisp.Response {
  case
    milestones_db.create_milestone(
      db,
      project_id,
      payload.name,
      payload.description,
      user_id,
    )
  {
    Error(error) -> milestone_error_response(error)
    Ok(milestone) -> api.ok(milestone_presenters.milestone_response(milestone))
  }
}

fn update_milestone_in_db(
  db: pog.Connection,
  milestone_id: Int,
  payload: milestone_payloads.PatchPayload,
) -> wisp.Response {
  case
    milestones_db.update_milestone(
      db,
      milestone_id,
      payload.name,
      payload.description,
    )
  {
    Ok(updated) -> api.ok(milestone_presenters.milestone_response(updated))
    Error(milestones_db.NotFound) ->
      api.error(404, "NOT_FOUND", "Milestone not found")
    Error(error) -> milestone_error_response(error)
  }
}

fn decode_create_payload(
  data,
) -> Result(milestone_payloads.CreatePayload, wisp.Response) {
  case milestone_payloads.decode_create(data) {
    Ok(result) -> Ok(result)
    Error(_) -> Error(api.error(400, "VALIDATION_ERROR", "Invalid JSON"))
  }
}

fn decode_patch_payload(
  data,
) -> Result(milestone_payloads.PatchPayload, wisp.Response) {
  case milestone_payloads.decode_patch(data) {
    Ok(result) -> Ok(result)
    Error(_) -> Error(api.error(400, "VALIDATION_ERROR", "Invalid JSON"))
  }
}
