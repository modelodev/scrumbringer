import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/services/projects_db
import scrumbringer_server/services/task_types_db
import scrumbringer_server/services/tasks_db
import scrumbringer_server/sql
import wisp

const unset_string = "__unset__"

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

          case require_project_member(db, project_id, user.id) {
            Error(resp) -> resp

            Ok(Nil) ->
              case task_types_db.list_task_types_for_project(db, project_id) {
                Ok(task_types) ->
                  api.ok(
                    json.object([
                      #(
                        "task_types",
                        json.array(task_types, of: task_type_json),
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

              case require_project_admin(db, project_id, user.id) {
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
                        validate_capability_in_org(db, cap_opt, user.org_id)
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
                                  #("task_type", task_type_json(task_type)),
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

          case require_project_member(db, project_id, user.id) {
            Error(resp) -> resp

            Ok(Nil) -> {
              let query = wisp.get_query(req)

              case parse_task_filters(query) {
                Error(resp) -> resp

                Ok(filters) -> {
                  case
                    tasks_db.list_tasks_for_project(
                      db,
                      project_id,
                      filters.status,
                      filters.type_id,
                      filters.capability_id,
                      filters.q,
                    )
                  {
                    Ok(tasks) ->
                      api.ok(
                        json.object([
                          #("tasks", json.array(tasks, of: task_json)),
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

              case require_project_member(db, project_id, user.id) {
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
                      case validate_task_title(title) {
                        Error(resp) -> resp

                        Ok(title) ->
                          case validate_priority(priority) {
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
                                          #("task", task_json(task)),
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
            Ok(task) -> api.ok(json.object([#("task", task_json(task))]))
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
                  unset_string,
                  decode.string,
                )
                use description <- decode.optional_field(
                  "description",
                  unset_string,
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
                  case validate_optional_priority(priority) {
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
                                    validate_type_update(
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
                                              #("task", task_json(task)),
                                            ]),
                                          )

                                        Error(tasks_db.NotFound) ->
                                          handle_version_or_claim_conflict(
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
                              api.ok(json.object([#("task", task_json(task))]))

                            Error(tasks_db.NotFound) ->
                              handle_claim_conflict(db, task_id, user.id)

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
                                    json.object([#("task", task_json(task))]),
                                  )

                                Error(tasks_db.NotFound) ->
                                  handle_version_or_claim_conflict(
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
                                    json.object([#("task", task_json(task))]),
                                  )

                                Error(tasks_db.NotFound) ->
                                  handle_version_or_claim_conflict(
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

pub type TaskFilters {
  TaskFilters(status: String, type_id: Int, capability_id: Int, q: String)
}

fn parse_task_filters(
  query: List(#(String, String)),
) -> Result(TaskFilters, wisp.Response) {
  use status <- result.try(parse_status_filter(query))
  use type_id <- result.try(parse_int_filter(query, "type_id"))
  use capability_id <- result.try(parse_capability_filter(query))
  use q <- result.try(parse_string_filter(query, "q"))
  Ok(TaskFilters(
    status: status,
    type_id: type_id,
    capability_id: capability_id,
    q: q,
  ))
}

fn parse_status_filter(
  query: List(#(String, String)),
) -> Result(String, wisp.Response) {
  case single_query_value(query, "status") {
    Ok(None) -> Ok("")

    Ok(Some(value)) ->
      case value {
        "available" | "claimed" | "completed" -> Ok(value)
        _ -> Error(api.error(422, "VALIDATION_ERROR", "Invalid status"))
      }

    Error(_) -> Error(api.error(422, "VALIDATION_ERROR", "Invalid status"))
  }
}

fn parse_capability_filter(
  query: List(#(String, String)),
) -> Result(Int, wisp.Response) {
  case single_query_value(query, "capability_id") {
    Ok(None) -> Ok(0)

    Ok(Some(value)) ->
      case string.contains(value, ",") {
        True ->
          Error(api.error(422, "VALIDATION_ERROR", "Invalid capability_id"))
        False ->
          case int.parse(value) {
            Ok(id) -> Ok(id)
            Error(_) ->
              Error(api.error(422, "VALIDATION_ERROR", "Invalid capability_id"))
          }
      }

    Error(_) ->
      Error(api.error(422, "VALIDATION_ERROR", "Invalid capability_id"))
  }
}

fn parse_int_filter(
  query: List(#(String, String)),
  key: String,
) -> Result(Int, wisp.Response) {
  case single_query_value(query, key) {
    Ok(None) -> Ok(0)

    Ok(Some(value)) ->
      case int.parse(value) {
        Ok(id) -> Ok(id)
        Error(_) -> Error(api.error(422, "VALIDATION_ERROR", "Invalid " <> key))
      }

    Error(_) -> Error(api.error(422, "VALIDATION_ERROR", "Invalid " <> key))
  }
}

fn parse_string_filter(
  query: List(#(String, String)),
  key: String,
) -> Result(String, wisp.Response) {
  case single_query_value(query, key) {
    Ok(None) -> Ok("")
    Ok(Some(value)) -> Ok(value)
    Error(_) -> Error(api.error(422, "VALIDATION_ERROR", "Invalid " <> key))
  }
}

fn single_query_value(
  query: List(#(String, String)),
  key: String,
) -> Result(Option(String), Nil) {
  let values =
    query
    |> list.filter_map(fn(pair) {
      case pair.0 == key {
        True -> Ok(pair.1)
        False -> Error(Nil)
      }
    })

  case values {
    [] -> Ok(None)
    [value] -> Ok(Some(value))
    _ -> Error(Nil)
  }
}

const max_task_title_chars = 56

fn validate_task_title(title: String) -> Result(String, wisp.Response) {
  let title = string.trim(title)

  case title == "" {
    True -> Error(api.error(422, "VALIDATION_ERROR", "Title is required"))
    False ->
      case string.length(title) <= max_task_title_chars {
        True -> Ok(title)
        False ->
          Error(api.error(
            422,
            "VALIDATION_ERROR",
            "Title too long (max 56 characters)",
          ))
      }
  }
}

fn validate_priority(priority: Int) -> Result(Nil, wisp.Response) {
  case priority >= 1 && priority <= 5 {
    True -> Ok(Nil)
    False -> Error(api.error(422, "VALIDATION_ERROR", "Invalid priority"))
  }
}

fn validate_optional_priority(priority: Int) -> Result(Nil, wisp.Response) {
  case priority {
    -1 -> Ok(Nil)
    _ -> validate_priority(priority)
  }
}

fn validate_type_update(
  db: pog.Connection,
  type_id: Int,
  project_id: Int,
) -> Result(Nil, wisp.Response) {
  case type_id {
    -1 -> Ok(Nil)
    id ->
      case task_types_db.is_task_type_in_project(db, id, project_id) {
        Ok(True) -> Ok(Nil)
        Ok(False) ->
          Error(api.error(422, "VALIDATION_ERROR", "Invalid type_id"))
        Error(_) -> Error(api.error(500, "INTERNAL", "Database error"))
      }
  }
}

fn validate_capability_in_org(
  db: pog.Connection,
  capability_id: Option(Int),
  org_id: Int,
) -> Result(Nil, wisp.Response) {
  case capability_id {
    None -> Ok(Nil)

    Some(id) ->
      case sql.capabilities_is_in_org(db, id, org_id) {
        Ok(pog.Returned(rows: [row, ..], ..)) ->
          case row.ok {
            True -> Ok(Nil)
            False ->
              Error(api.error(422, "VALIDATION_ERROR", "Invalid capability_id"))
          }

        Ok(pog.Returned(rows: [], ..)) ->
          Error(api.error(422, "VALIDATION_ERROR", "Invalid capability_id"))

        Error(_) -> Error(api.error(500, "INTERNAL", "Database error"))
      }
  }
}

fn handle_claim_conflict(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
) -> wisp.Response {
  case tasks_db.get_task_for_user(db, task_id, user_id) {
    Error(tasks_db.NotFound) -> api.error(404, "NOT_FOUND", "Not found")
    Error(_) -> api.error(500, "INTERNAL", "Database error")

    Ok(current) ->
      case current.status {
        "claimed" -> api.error(409, "CONFLICT_CLAIMED", "Task already claimed")
        "completed" -> api.error(422, "VALIDATION_ERROR", "Invalid transition")
        _ -> api.error(409, "CONFLICT_VERSION", "Version conflict")
      }
  }
}

fn handle_version_or_claim_conflict(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
) -> wisp.Response {
  case tasks_db.get_task_for_user(db, task_id, user_id) {
    Error(tasks_db.NotFound) -> api.error(404, "NOT_FOUND", "Not found")
    Error(_) -> api.error(500, "INTERNAL", "Database error")

    Ok(current) ->
      case current.status != "claimed" {
        True -> api.error(422, "VALIDATION_ERROR", "Invalid transition")
        False ->
          case current.claimed_by {
            Some(id) if id == user_id ->
              api.error(409, "CONFLICT_VERSION", "Version conflict")
            _ -> api.error(403, "FORBIDDEN", "Forbidden")
          }
      }
  }
}

fn require_project_member(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
) -> Result(Nil, wisp.Response) {
  case projects_db.is_project_member(db, project_id, user_id) {
    Ok(True) -> Ok(Nil)
    Ok(False) -> Error(api.error(403, "FORBIDDEN", "Forbidden"))
    Error(_) -> Error(api.error(500, "INTERNAL", "Database error"))
  }
}

fn require_project_admin(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
) -> Result(Nil, wisp.Response) {
  case projects_db.is_project_admin(db, project_id, user_id) {
    Ok(True) -> Ok(Nil)
    Ok(False) -> Error(api.error(403, "FORBIDDEN", "Forbidden"))
    Error(_) -> Error(api.error(500, "INTERNAL", "Database error"))
  }
}

fn task_type_json(task_type: task_types_db.TaskType) -> json.Json {
  let task_types_db.TaskType(
    id: id,
    project_id: project_id,
    name: name,
    icon: icon,
    capability_id: capability_id,
  ) = task_type

  json.object([
    #("id", json.int(id)),
    #("project_id", json.int(project_id)),
    #("name", json.string(name)),
    #("icon", json.string(icon)),
    #("capability_id", option_int_json(capability_id)),
  ])
}

fn task_json(task: tasks_db.Task) -> json.Json {
  let tasks_db.Task(
    id: id,
    project_id: project_id,
    type_id: type_id,
    title: title,
    description: description,
    priority: priority,
    status: status,
    created_by: created_by,
    claimed_by: claimed_by,
    claimed_at: claimed_at,
    completed_at: completed_at,
    created_at: created_at,
    version: version,
  ) = task

  json.object([
    #("id", json.int(id)),
    #("project_id", json.int(project_id)),
    #("type_id", json.int(type_id)),
    #("title", json.string(title)),
    #("description", option_string_json(description)),
    #("priority", json.int(priority)),
    #("status", json.string(status)),
    #("created_by", json.int(created_by)),
    #("claimed_by", option_int_json(claimed_by)),
    #("claimed_at", option_string_json(claimed_at)),
    #("completed_at", option_string_json(completed_at)),
    #("created_at", json.string(created_at)),
    #("version", json.int(version)),
  ])
}

fn option_int_json(value: Option(Int)) -> json.Json {
  case value {
    None -> json.null()
    Some(v) -> json.int(v)
  }
}

fn option_string_json(value: Option(String)) -> json.Json {
  case value {
    None -> json.null()
    Some(v) -> json.string(v)
  }
}
