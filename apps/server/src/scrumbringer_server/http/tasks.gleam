//// Task HTTP handlers for Scrumbringer server.
////
//// ## Mission
////
//// Provides HTTP route handlers for task-related operations including
//// task types, tasks, and task state transitions (claim, release, complete).
////
//// ## Submodules
////
//// - `tasks/validators`: Input validation functions
//// - `tasks/presenters`: JSON serialization functions
//// - `tasks/filters`: Query parameter parsing
//// - `tasks/conflict_handlers`: Conflict resolution

import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/option.{None, Some}
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/http/tasks/conflict_handlers
import scrumbringer_server/http/tasks/filters
import scrumbringer_server/http/tasks/presenters
import scrumbringer_server/http/tasks/validators
import scrumbringer_server/services/task_types_db
import scrumbringer_server/services/tasks_db
import wisp

pub fn handle_task_types(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> wisp.Response {
  case req.method {
    http.Get -> handle_task_types_list(req, ctx, project_id)
    http.Post -> handle_task_types_create(req, ctx, project_id)
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}

pub fn handle_project_tasks(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> wisp.Response {
  case req.method {
    http.Get -> handle_tasks_list(req, ctx, project_id)
    http.Post -> handle_tasks_create(req, ctx, project_id)
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}

pub fn handle_task(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  case req.method {
    http.Get -> handle_task_get(req, ctx, task_id)
    http.Patch -> handle_task_patch(req, ctx, task_id)
    _ -> wisp.method_not_allowed([http.Get, http.Patch])
  }
}

pub fn handle_claim(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)
  handle_task_claim(req, ctx, task_id)
}

pub fn handle_release(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)
  handle_task_release(req, ctx, task_id)
}

pub fn handle_complete(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)
  handle_task_complete(req, ctx, task_id)
}

fn handle_task_types_list(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case int.parse(project_id) {
        Error(_) -> api.error(404, "NOT_FOUND", "Not found")

        Ok(project_id) -> {
          let auth.Ctx(db: db, ..) = ctx

          case validators.require_project_member(db, project_id, user.id) {
            Error(resp) -> resp

            Ok(Nil) ->
              case task_types_db.list_task_types_for_project(db, project_id) {
                Ok(task_types) ->
                  api.ok(
                    json.object([
                      #(
                        "task_types",
                        json.array(task_types, of: presenters.task_type_json),
                      ),
                    ]),
                  )

                Error(_) -> api.error(500, "INTERNAL", "Database error")
              }
          }
        }
      }
  }
}

fn handle_task_types_create(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case csrf.require_double_submit(req) {
        Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")

        Ok(Nil) ->
          case int.parse(project_id) {
            Error(_) -> api.error(404, "NOT_FOUND", "Not found")

            Ok(project_id) -> {
              let auth.Ctx(db: db, ..) = ctx

              case validators.require_project_admin(db, project_id, user.id) {
                Error(resp) -> resp

                Ok(Nil) -> {
                  use data <- wisp.require_json(req)

                  let decoder = {
                    use name <- decode.field("name", decode.string)
                    use icon <- decode.field("icon", decode.string)
                    use capability_id <- decode.optional_field(
                      "capability_id",
                      0,
                      decode.int,
                    )
                    decode.success(#(name, icon, capability_id))
                  }

                  case decode.run(data, decoder) {
                    Error(_) ->
                      api.error(400, "VALIDATION_ERROR", "Invalid JSON")

                    Ok(#(name, icon, capability_id)) -> {
                      let cap_opt = case capability_id {
                        0 -> None
                        id -> Some(id)
                      }

                      case
                        validators.validate_capability_in_org(db, cap_opt, user.org_id)
                      {
                        Error(resp) -> resp

                        Ok(Nil) ->
                          case
                            task_types_db.create_task_type(
                              db,
                              project_id,
                              name,
                              icon,
                              cap_opt,
                            )
                          {
                            Ok(task_type) ->
                              api.ok(
                                json.object([
                                  #("task_type", presenters.task_type_json(task_type)),
                                ]),
                              )

                            Error(task_types_db.AlreadyExists) ->
                              api.error(
                                422,
                                "VALIDATION_ERROR",
                                "Task type name already exists",
                              )

                            Error(task_types_db.InvalidCapabilityId) ->
                              api.error(
                                422,
                                "VALIDATION_ERROR",
                                "Invalid capability_id",
                              )

                            Error(_) ->
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
  }
}

fn handle_tasks_list(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case int.parse(project_id) {
        Error(_) -> api.error(404, "NOT_FOUND", "Not found")

        Ok(project_id) -> {
          let auth.Ctx(db: db, ..) = ctx

          case validators.require_project_member(db, project_id, user.id) {
            Error(resp) -> resp

            Ok(Nil) -> {
              let query = wisp.get_query(req)

              case filters.parse_task_filters(query) {
                Error(resp) -> resp

                Ok(filters) -> {
                  case
                    tasks_db.list_tasks_for_project(
                      db,
                      project_id,
                      user.id,
                      filters.status,
                      filters.type_id,
                      filters.capability_id,
                      filters.q,
                    )
                  {
                    Ok(tasks) ->
                      api.ok(
                        json.object([
                          #("tasks", json.array(tasks, of: presenters.task_json)),
                        ]),
                      )

                    Error(_) -> api.error(500, "INTERNAL", "Database error")
                  }
                }
              }
            }
          }
        }
      }
  }
}

fn handle_tasks_create(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case csrf.require_double_submit(req) {
        Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")

        Ok(Nil) ->
          case int.parse(project_id) {
            Error(_) -> api.error(404, "NOT_FOUND", "Not found")

            Ok(project_id) -> {
              let auth.Ctx(db: db, ..) = ctx

              case validators.require_project_member(db, project_id, user.id) {
                Error(resp) -> resp

                Ok(Nil) -> {
                  use data <- wisp.require_json(req)

                  let decoder = {
                    use title <- decode.field("title", decode.string)
                    use description <- decode.optional_field(
                      "description",
                      "",
                      decode.string,
                    )
                    use priority <- decode.field("priority", decode.int)
                    use type_id <- decode.field("type_id", decode.int)
                    decode.success(#(title, description, priority, type_id))
                  }

                  case decode.run(data, decoder) {
                    Error(_) ->
                      api.error(400, "VALIDATION_ERROR", "Invalid JSON")

                    Ok(#(title, description, priority, type_id)) -> {
                      case validators.validate_task_title(title) {
                        Error(resp) -> resp

                        Ok(title) ->
                          case validators.validate_priority(priority) {
                            Error(resp) -> resp

                            Ok(Nil) ->
                              case
                                task_types_db.is_task_type_in_project(
                                  db,
                                  type_id,
                                  project_id,
                                )
                              {
                                Ok(True) ->
                                  case
                                    tasks_db.create_task(
                                      db,
                                      user.org_id,
                                      type_id,
                                      project_id,
                                      title,
                                      description,
                                      priority,
                                      user.id,
                                    )
                                  {
                                    Ok(task) ->
                                      api.ok(
                                        json.object([
                                          #("task", presenters.task_json(task)),
                                        ]),
                                      )

                                    Error(tasks_db.InvalidTypeId) ->
                                      api.error(
                                        422,
                                        "VALIDATION_ERROR",
                                        "Invalid type_id",
                                      )

                                    Error(_) ->
                                      api.error(
                                        500,
                                        "INTERNAL",
                                        "Database error",
                                      )
                                  }

                                Ok(False) ->
                                  api.error(
                                    422,
                                    "VALIDATION_ERROR",
                                    "Invalid type_id",
                                  )
                                Error(_) ->
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
      }
  }
}

fn handle_task_get(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case int.parse(task_id) {
        Error(_) -> api.error(404, "NOT_FOUND", "Not found")

        Ok(task_id) -> {
          let auth.Ctx(db: db, ..) = ctx

          case tasks_db.get_task_for_user(db, task_id, user.id) {
            Ok(task) -> api.ok(json.object([#("task", presenters.task_json(task))]))
            Error(tasks_db.NotFound) -> api.error(404, "NOT_FOUND", "Not found")
            Error(_) -> api.error(500, "INTERNAL", "Database error")
          }
        }
      }
  }
}

fn handle_task_patch(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Patch)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case csrf.require_double_submit(req) {
        Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")

        Ok(Nil) ->
          case int.parse(task_id) {
            Error(_) -> api.error(404, "NOT_FOUND", "Not found")

            Ok(task_id) -> {
              let auth.Ctx(db: db, ..) = ctx

              use data <- wisp.require_json(req)

              let decoder = {
                use version <- decode.field("version", decode.int)
                use title <- decode.optional_field(
                  "title",
                  validators.unset_string,
                  decode.string,
                )
                use description <- decode.optional_field(
                  "description",
                  validators.unset_string,
                  decode.string,
                )
                use priority <- decode.optional_field(
                  "priority",
                  -1,
                  decode.int,
                )
                use type_id <- decode.optional_field("type_id", -1, decode.int)
                decode.success(#(version, title, description, priority, type_id))
              }

              case decode.run(data, decoder) {
                Error(_) -> api.error(400, "VALIDATION_ERROR", "Invalid JSON")

                Ok(#(version, title, description, priority, type_id)) -> {
                  case validators.validate_optional_priority(priority) {
                    Error(resp) -> resp

                    Ok(Nil) ->
                      case tasks_db.get_task_for_user(db, task_id, user.id) {
                        Error(tasks_db.NotFound) ->
                          api.error(404, "NOT_FOUND", "Not found")
                        Error(_) -> api.error(500, "INTERNAL", "Database error")

                        Ok(current) -> {
                          case current.status != "claimed" {
                            True -> api.error(403, "FORBIDDEN", "Forbidden")
                            False ->
                              case current.claimed_by {
                                Some(id) if id == user.id ->
                                  case
                                    validators.validate_type_update(
                                      db,
                                      type_id,
                                      current.project_id,
                                    )
                                  {
                                    Error(resp) -> resp

                                    Ok(Nil) ->
                                      case
                                        tasks_db.update_task_claimed_by_user(
                                          db,
                                          task_id,
                                          user.id,
                                          title,
                                          description,
                                          priority,
                                          type_id,
                                          version,
                                        )
                                      {
                                        Ok(task) ->
                                          api.ok(
                                            json.object([
                                              #("task", presenters.task_json(task)),
                                            ]),
                                          )

                                        Error(tasks_db.NotFound) ->
                                          conflict_handlers.handle_version_or_claim_conflict(
                                            db,
                                            task_id,
                                            user.id,
                                          )

                                        Error(_) ->
                                          api.error(
                                            500,
                                            "INTERNAL",
                                            "Database error",
                                          )
                                      }
                                  }

                                _ -> api.error(403, "FORBIDDEN", "Forbidden")
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
}

fn handle_task_claim(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case csrf.require_double_submit(req) {
        Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")

        Ok(Nil) ->
          case int.parse(task_id) {
            Error(_) -> api.error(404, "NOT_FOUND", "Not found")

            Ok(task_id) -> {
              let auth.Ctx(db: db, ..) = ctx

              use data <- wisp.require_json(req)

              let decoder = {
                use version <- decode.field("version", decode.int)
                decode.success(version)
              }

              case decode.run(data, decoder) {
                Error(_) -> api.error(400, "VALIDATION_ERROR", "Invalid JSON")

                Ok(version) ->
                  case tasks_db.get_task_for_user(db, task_id, user.id) {
                    Error(tasks_db.NotFound) ->
                      api.error(404, "NOT_FOUND", "Not found")
                    Error(_) -> api.error(500, "INTERNAL", "Database error")

                    Ok(current) ->
                      case current.status {
                        "claimed" ->
                          api.error(
                            409,
                            "CONFLICT_CLAIMED",
                            "Task already claimed",
                          )
                        "completed" ->
                          api.error(
                            422,
                            "VALIDATION_ERROR",
                            "Invalid transition",
                          )
                        _ ->
                          case
                            tasks_db.claim_task(
                              db,
                              user.org_id,
                              task_id,
                              user.id,
                              version,
                            )
                          {
                            Ok(task) ->
                              api.ok(json.object([#("task", presenters.task_json(task))]))

                            Error(tasks_db.NotFound) ->
                              conflict_handlers.handle_claim_conflict(db, task_id, user.id)

                            Error(_) ->
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

fn handle_task_release(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case csrf.require_double_submit(req) {
        Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")

        Ok(Nil) ->
          case int.parse(task_id) {
            Error(_) -> api.error(404, "NOT_FOUND", "Not found")

            Ok(task_id) -> {
              let auth.Ctx(db: db, ..) = ctx

              use data <- wisp.require_json(req)

              let decoder = {
                use version <- decode.field("version", decode.int)
                decode.success(version)
              }

              case decode.run(data, decoder) {
                Error(_) -> api.error(400, "VALIDATION_ERROR", "Invalid JSON")

                Ok(version) ->
                  case tasks_db.get_task_for_user(db, task_id, user.id) {
                    Error(tasks_db.NotFound) ->
                      api.error(404, "NOT_FOUND", "Not found")
                    Error(_) -> api.error(500, "INTERNAL", "Database error")

                    Ok(current) ->
                      case current.status != "claimed" {
                        True ->
                          api.error(
                            422,
                            "VALIDATION_ERROR",
                            "Invalid transition",
                          )
                        False ->
                          case current.claimed_by {
                            Some(id) if id == user.id ->
                              case
                                tasks_db.release_task(
                                  db,
                                  user.org_id,
                                  task_id,
                                  user.id,
                                  version,
                                )
                              {
                                Ok(task) ->
                                  api.ok(
                                    json.object([#("task", presenters.task_json(task))]),
                                  )

                                Error(tasks_db.NotFound) ->
                                  conflict_handlers.handle_version_or_claim_conflict(
                                    db,
                                    task_id,
                                    user.id,
                                  )

                                Error(_) ->
                                  api.error(500, "INTERNAL", "Database error")
                              }

                            _ -> api.error(403, "FORBIDDEN", "Forbidden")
                          }
                      }
                  }
              }
            }
          }
      }
  }
}

fn handle_task_complete(
  req: wisp.Request,
  ctx: auth.Ctx,
  task_id: String,
) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case csrf.require_double_submit(req) {
        Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")

        Ok(Nil) ->
          case int.parse(task_id) {
            Error(_) -> api.error(404, "NOT_FOUND", "Not found")

            Ok(task_id) -> {
              let auth.Ctx(db: db, ..) = ctx

              use data <- wisp.require_json(req)

              let decoder = {
                use version <- decode.field("version", decode.int)
                decode.success(version)
              }

              case decode.run(data, decoder) {
                Error(_) -> api.error(400, "VALIDATION_ERROR", "Invalid JSON")

                Ok(version) ->
                  case tasks_db.get_task_for_user(db, task_id, user.id) {
                    Error(tasks_db.NotFound) ->
                      api.error(404, "NOT_FOUND", "Not found")
                    Error(_) -> api.error(500, "INTERNAL", "Database error")

                    Ok(current) ->
                      case current.status != "claimed" {
                        True ->
                          api.error(
                            422,
                            "VALIDATION_ERROR",
                            "Invalid transition",
                          )
                        False ->
                          case current.claimed_by {
                            Some(id) if id == user.id ->
                              case
                                tasks_db.complete_task(
                                  db,
                                  user.org_id,
                                  task_id,
                                  user.id,
                                  version,
                                )
                              {
                                Ok(task) ->
                                  api.ok(
                                    json.object([#("task", presenters.task_json(task))]),
                                  )

                                Error(tasks_db.NotFound) ->
                                  conflict_handlers.handle_version_or_claim_conflict(
                                    db,
                                    task_id,
                                    user.id,
                                  )

                                Error(_) ->
                                  api.error(500, "INTERNAL", "Database error")
                              }

                            _ -> api.error(403, "FORBIDDEN", "Forbidden")
                          }
                      }
                  }
              }
            }
          }
      }
  }
}
