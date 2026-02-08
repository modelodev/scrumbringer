//// HTTP handlers for milestones.

import domain/milestone as milestone_domain
import gleam/dynamic
import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/services/authorization
import scrumbringer_server/services/metrics_db
import scrumbringer_server/services/milestones_db
import wisp

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
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")
    Ok(user) -> {
      let auth.Ctx(db: db, ..) = ctx
      case authorization.is_project_member(db, user.id, project_id) {
        False -> api.error(403, "FORBIDDEN", "Not a member of this project")
        True ->
          case milestones_db.list_milestones(db, project_id) {
            Error(milestones_db.DbError(_)) ->
              api.error(500, "INTERNAL", "Database error")
            Error(_) -> api.error(500, "INTERNAL", "Unexpected error")
            Ok(rows) ->
              api.ok(
                json.object([
                  #("milestones", json.array(rows, of: milestone_progress_json)),
                ]),
              )
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

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")
    Ok(user) -> {
      let auth.Ctx(db: db, ..) = ctx
      case milestones_db.get_milestone(db, milestone_id) {
        Error(milestones_db.NotFound) ->
          case include_metrics {
            True -> api.error(404, "not_found", "Milestone not found")
            False -> api.error(404, "NOT_FOUND", "Milestone not found")
          }
        Error(milestones_db.DeleteNotAllowed) ->
          api.error(500, "INTERNAL", "Unexpected error")
        Error(milestones_db.DbError(_)) ->
          api.error(500, "INTERNAL", "Database error")
        Ok(milestone) -> {
          case
            authorization.is_project_member(db, user.id, milestone.project_id)
          {
            False ->
              case include_metrics {
                True ->
                  api.error(403, "forbidden", "Not a member of this project")
                False ->
                  api.error(403, "FORBIDDEN", "Not a member of this project")
              }
            True -> {
              case include_metrics {
                True ->
                  case metrics_db.get_milestone_metrics(db, milestone.id) {
                    Ok(metrics) ->
                      api.ok(
                        json.object([
                          #("id", json.string(int.to_string(milestone.id))),
                          #("metrics", milestone_metrics_json(metrics)),
                        ]),
                      )
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
                  api.ok(
                    json.object([#("milestone", milestone_json(milestone))]),
                  )
              }
            }
          }
        }
      }
    }
  }
}

fn wants_metrics(req: wisp.Request) -> Bool {
  wisp.get_query(req)
  |> list.any(fn(pair) { pair.0 == "include" && pair.1 == "metrics" })
}

fn handle_create(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: Int,
) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")
    Ok(user) -> {
      let auth.Ctx(db: db, ..) = ctx
      case authorization.is_project_manager(db, user.id, project_id) {
        False -> api.error(403, "FORBIDDEN", "Project admin role required")
        True -> {
          case csrf.require_double_submit(req) {
            Error(_) ->
              api.error(403, "FORBIDDEN", "CSRF token missing or invalid")
            Ok(Nil) -> {
              use data <- wisp.require_json(req)
              case decode_create_payload(data) {
                Error(resp) -> resp
                Ok(#(name, description)) ->
                  case
                    milestones_db.create_milestone(
                      db,
                      project_id,
                      name,
                      description,
                      user.id,
                    )
                  {
                    Error(milestones_db.DbError(_)) ->
                      api.error(500, "INTERNAL", "Database error")
                    Error(_) -> api.error(500, "INTERNAL", "Unexpected error")
                    Ok(milestone) ->
                      api.ok(
                        json.object([#("milestone", milestone_json(milestone))]),
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

fn handle_activate_post(
  req: wisp.Request,
  ctx: auth.Ctx,
  milestone_id: Int,
) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")
    Ok(user) -> {
      let auth.Ctx(db: db, ..) = ctx

      case milestones_db.get_milestone(db, milestone_id) {
        Error(milestones_db.NotFound) ->
          api.error(404, "NOT_FOUND", "Milestone not found")
        Error(milestones_db.DeleteNotAllowed) ->
          api.error(500, "INTERNAL", "Unexpected error")
        Error(milestones_db.DbError(_)) ->
          api.error(500, "INTERNAL", "Database error")
        Ok(milestone) -> {
          case
            authorization.is_project_manager(db, user.id, milestone.project_id)
          {
            False -> api.error(403, "FORBIDDEN", "Project admin role required")
            True -> {
              case csrf.require_double_submit(req) {
                Error(_) ->
                  api.error(403, "FORBIDDEN", "CSRF token missing or invalid")
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
        Error(milestones_db.DeleteNotAllowed) ->
          api.error(500, "INTERNAL", "Unexpected error")
        Error(milestones_db.DbError(_)) ->
          api.error(500, "INTERNAL", "Database error")
        Ok(snapshot) ->
          api.ok(
            json.object([
              #("milestone", milestone_json(snapshot.milestone)),
              #(
                "activated_at",
                option_string_json(snapshot.milestone.activated_at),
              ),
              #("cards_released", json.int(snapshot.cards_released)),
              #("tasks_released", json.int(snapshot.tasks_released)),
            ]),
          )
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

fn decode_create_payload(
  data: dynamic.Dynamic,
) -> Result(#(String, Option(String)), wisp.Response) {
  let decoder = {
    use name <- decode.field("name", decode.string)
    use description <- decode.optional_field(
      "description",
      None,
      decode.optional(decode.string),
    )
    decode.success(#(name, description))
  }

  case decode.run(data, decoder) {
    Ok(result) -> Ok(result)
    Error(_) -> Error(api.error(400, "VALIDATION_ERROR", "Invalid JSON"))
  }
}

fn handle_patch(
  req: wisp.Request,
  ctx: auth.Ctx,
  milestone_id: Int,
) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")
    Ok(user) -> {
      let auth.Ctx(db: db, ..) = ctx
      case milestones_db.get_milestone(db, milestone_id) {
        Error(milestones_db.NotFound) ->
          api.error(404, "NOT_FOUND", "Milestone not found")
        Error(milestones_db.DbError(_)) ->
          api.error(500, "INTERNAL", "Database error")
        Error(milestones_db.DeleteNotAllowed) ->
          api.error(500, "INTERNAL", "Unexpected error")
        Ok(milestone) -> {
          case
            authorization.is_project_manager(db, user.id, milestone.project_id)
          {
            False -> api.error(403, "FORBIDDEN", "Project admin role required")
            True -> {
              case csrf.require_double_submit(req) {
                Error(_) ->
                  api.error(403, "FORBIDDEN", "CSRF token missing or invalid")
                Ok(Nil) -> {
                  use data <- wisp.require_json(req)
                  case decode_patch_payload(data) {
                    Error(resp) -> resp
                    Ok(#(name, description)) ->
                      case
                        milestones_db.update_milestone(
                          db,
                          milestone_id,
                          name,
                          description,
                        )
                      {
                        Ok(updated) ->
                          api.ok(
                            json.object([
                              #("milestone", milestone_json(updated)),
                            ]),
                          )
                        Error(milestones_db.NotFound) ->
                          api.error(404, "NOT_FOUND", "Milestone not found")
                        Error(milestones_db.DbError(_)) ->
                          api.error(500, "INTERNAL", "Database error")
                        Error(milestones_db.DeleteNotAllowed) ->
                          api.error(500, "INTERNAL", "Unexpected error")
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
}

fn handle_delete(
  req: wisp.Request,
  ctx: auth.Ctx,
  milestone_id: Int,
) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")
    Ok(user) -> {
      let auth.Ctx(db: db, ..) = ctx
      case milestones_db.get_milestone(db, milestone_id) {
        Error(milestones_db.NotFound) ->
          api.error(404, "NOT_FOUND", "Milestone not found")
        Error(milestones_db.DbError(_)) ->
          api.error(500, "INTERNAL", "Database error")
        Error(milestones_db.DeleteNotAllowed) ->
          api.error(500, "INTERNAL", "Unexpected error")
        Ok(milestone) -> {
          case
            authorization.is_project_manager(db, user.id, milestone.project_id)
          {
            False -> api.error(403, "FORBIDDEN", "Project admin role required")
            True -> {
              case csrf.require_double_submit(req) {
                Error(_) ->
                  api.error(403, "FORBIDDEN", "CSRF token missing or invalid")
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
                    Error(milestones_db.DbError(_)) ->
                      api.error(500, "INTERNAL", "Database error")
                  }
              }
            }
          }
        }
      }
    }
  }
}

fn decode_patch_payload(
  data: dynamic.Dynamic,
) -> Result(#(Option(String), Option(String)), wisp.Response) {
  let decoder = {
    use name <- decode.optional_field(
      "name",
      None,
      decode.optional(decode.string),
    )
    use description <- decode.optional_field(
      "description",
      None,
      decode.optional(decode.string),
    )
    decode.success(#(name, description))
  }

  case decode.run(data, decoder) {
    Ok(result) -> Ok(result)
    Error(_) -> Error(api.error(400, "VALIDATION_ERROR", "Invalid JSON"))
  }
}

fn milestone_progress_json(
  row: milestones_db.MilestoneWithProgress,
) -> json.Json {
  json.object([
    #("milestone", milestone_json(row.milestone)),
    #("cards_total", json.int(row.cards_total)),
    #("cards_completed", json.int(row.cards_completed)),
    #("tasks_total", json.int(row.tasks_total)),
    #("tasks_completed", json.int(row.tasks_completed)),
    #("is_completed", json.bool(milestones_db.is_completed(row))),
  ])
}

fn milestone_json(m: milestone_domain.Milestone) -> json.Json {
  json.object([
    #("id", json.int(m.id)),
    #("project_id", json.int(m.project_id)),
    #("name", json.string(m.name)),
    #("description", option_string_json(m.description)),
    #("state", json.string(milestone_domain.state_to_string(m.state))),
    #("position", json.int(m.position)),
    #("created_by", json.int(m.created_by)),
    #("created_at", json.string(m.created_at)),
    #("activated_at", option_string_json(m.activated_at)),
    #("completed_at", option_string_json(m.completed_at)),
  ])
}

fn option_string_json(value: Option(String)) -> json.Json {
  case value {
    None -> json.null()
    Some(v) -> json.string(v)
  }
}

fn milestone_metrics_json(metrics: metrics_db.MilestoneMetrics) -> json.Json {
  let metrics_db.MilestoneMetrics(
    cards_total: cards_total,
    cards_completed: cards_completed,
    tasks_total: tasks_total,
    tasks_completed: tasks_completed,
    tasks_available: tasks_available,
    tasks_claimed: tasks_claimed,
    tasks_ongoing: tasks_ongoing,
    health: health,
    workflows: workflows,
    most_activated: most_activated,
  ) = metrics

  let metrics_db.ExecutionHealth(
    avg_rebotes: avg_rebotes,
    avg_pool_lifetime_s: avg_pool_lifetime_s,
    avg_executors: avg_executors,
  ) = health

  json.object([
    #(
      "progress",
      json.object([
        #("cards_total", json.int(cards_total)),
        #("cards_completed", json.int(cards_completed)),
        #(
          "cards_percent",
          json.int(metrics_db.percent(cards_completed, cards_total)),
        ),
        #("tasks_total", json.int(tasks_total)),
        #("tasks_completed", json.int(tasks_completed)),
        #(
          "tasks_percent",
          json.int(metrics_db.percent(tasks_completed, tasks_total)),
        ),
      ]),
    ),
    #(
      "states",
      json.object([
        #("available", json.int(tasks_available)),
        #("claimed", json.int(tasks_claimed)),
        #("ongoing", json.int(tasks_ongoing)),
        #("completed", json.int(tasks_completed)),
      ]),
    ),
    #(
      "health",
      json.object([
        #("avg_rebotes", json.int(avg_rebotes)),
        #("avg_pool_lifetime_s", json.int(avg_pool_lifetime_s)),
        #("avg_executors", json.int(avg_executors)),
      ]),
    ),
    #(
      "workflows",
      json.object([
        #("items", json.array(workflows, of: workflow_count_json)),
        #("most_activated", option_string_json(most_activated)),
      ]),
    ),
  ])
}

fn workflow_count_json(value: metrics_db.WorkflowCount) -> json.Json {
  let metrics_db.WorkflowCount(name: name, count: count) = value
  json.object([
    #("name", json.string(metrics_db.workflow_name_or_default(name))),
    #("count", json.int(count)),
  ])
}
