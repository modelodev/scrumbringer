//// HTTP handlers for project capabilities (skills).
////
//// Provides endpoints for listing, creating, and deleting capabilities within a project,
//// as well as managing project member capability selections.
////
//// Routes:
//// - GET    /api/projects/:id/capabilities - List capabilities for project
//// - POST   /api/projects/:id/capabilities - Create capability (manager only)
//// - DELETE /api/projects/:id/capabilities/:cap_id - Delete capability (manager only)
//// - GET    /api/projects/:id/members/:user_id/capabilities - Get member capabilities
//// - PUT    /api/projects/:id/members/:user_id/capabilities - Set member capabilities

import domain/org_role
import gleam/dynamic/decode
import gleam/http
import gleam/json
import gleam/list
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/services/capabilities_db
import scrumbringer_server/services/projects_db
import scrumbringer_server/services/store_state.{type StoredUser}
import wisp

/// Routes /api/projects/:id/capabilities requests.
pub fn handle_project_capabilities(
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

/// Routes /api/projects/:id/capabilities/:cap_id requests (Story 4.9 AC9).
pub fn handle_capability(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: Int,
  capability_id: Int,
) -> wisp.Response {
  case req.method {
    http.Delete -> handle_delete(req, ctx, project_id, capability_id)
    _ -> wisp.method_not_allowed([http.Delete])
  }
}

/// Routes /api/projects/:id/members/:user_id/capabilities requests.
pub fn handle_member_capabilities(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: Int,
  user_id: Int,
) -> wisp.Response {
  case req.method {
    http.Get -> handle_get_member_capabilities(req, ctx, project_id, user_id)
    http.Put -> handle_put_member_capabilities(req, ctx, project_id, user_id)
    _ -> wisp.method_not_allowed([http.Get, http.Put])
  }
}

fn handle_list(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: Int,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) -> {
      let auth.Ctx(db: db, ..) = ctx

      // Must be a member of the project
      case projects_db.is_project_member(db, project_id, user.id) {
        Ok(True) -> {
          case capabilities_db.list_capabilities_for_project(db, project_id) {
            Ok(capabilities) ->
              api.ok(
                json.object([
                  #("capabilities", json.array(capabilities, of: capability_json)),
                ]),
              )

            Error(_) -> api.error(500, "INTERNAL", "Database error")
          }
        }
        Ok(False) -> api.error(403, "FORBIDDEN", "Not a member of this project")
        Error(_) -> api.error(500, "INTERNAL", "Database error")
      }
    }
  }
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

      // Must be a manager of the project (or org admin)
      case require_project_manager(db, user, project_id) {
        Error(resp) -> resp
        Ok(Nil) -> create_capability(req, ctx, project_id)
      }
    }
  }
}

fn require_project_manager(
  db,
  user: StoredUser,
  project_id: Int,
) -> Result(Nil, wisp.Response) {
  // Org admin has implicit manager access
  case user.org_role {
    org_role.Admin -> Ok(Nil)
    _ -> {
      case projects_db.is_project_manager(db, project_id, user.id) {
        Ok(True) -> Ok(Nil)
        Ok(False) -> Error(api.error(403, "FORBIDDEN", "Not a project manager"))
        Error(_) -> Error(api.error(500, "INTERNAL", "Database error"))
      }
    }
  }
}

/// Story 4.9 AC9: Delete a capability (manager only).
fn handle_delete(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: Int,
  capability_id: Int,
) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) -> {
      let auth.Ctx(db: db, ..) = ctx

      case require_project_manager(db, user, project_id) {
        Error(resp) -> resp
        Ok(Nil) -> delete_capability(req, ctx, project_id, capability_id)
      }
    }
  }
}

fn delete_capability(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: Int,
  capability_id: Int,
) -> wisp.Response {
  case csrf.require_double_submit(req) {
    Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")

    Ok(Nil) -> {
      let auth.Ctx(db: db, ..) = ctx

      case capabilities_db.delete_capability(db, project_id, capability_id) {
        Ok(True) ->
          api.ok(json.object([#("id", json.int(capability_id))]))

        Ok(False) ->
          api.error(404, "NOT_FOUND", "Capability not found")

        Error(_) -> api.error(500, "INTERNAL", "Database error")
      }
    }
  }
}

fn create_capability(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: Int,
) -> wisp.Response {
  case csrf.require_double_submit(req) {
    Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")

    Ok(Nil) -> {
      use data <- wisp.require_json(req)

      let decoder = {
        use name <- decode.field("name", decode.string)
        decode.success(name)
      }

      case decode.run(data, decoder) {
        Error(_) -> api.error(400, "VALIDATION_ERROR", "Invalid JSON")

        Ok(name) -> {
          let auth.Ctx(db: db, ..) = ctx

          case capabilities_db.create_capability(db, project_id, name) {
            Ok(capability) ->
              api.ok(
                json.object([#("capability", capability_json(capability))]),
              )

            Error(capabilities_db.AlreadyExists) ->
              api.error(
                422,
                "VALIDATION_ERROR",
                "Capability name already exists",
              )

            Error(_) -> api.error(500, "INTERNAL", "Database error")
          }
        }
      }
    }
  }
}

fn handle_get_member_capabilities(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: Int,
  user_id: Int,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) -> {
      let auth.Ctx(db: db, ..) = ctx

      // Must be a member of the project
      case projects_db.is_project_member(db, project_id, user.id) {
        Ok(True) -> {
          case capabilities_db.list_member_capabilities(db, project_id, user_id) {
            Ok(capabilities) -> {
              let ids = list.map(capabilities, fn(c) { c.capability_id })
              api.ok(json.object([#("capability_ids", ids_json(ids))]))
            }
            Error(_) -> api.error(500, "INTERNAL", "Database error")
          }
        }
        Ok(False) -> api.error(403, "FORBIDDEN", "Not a member of this project")
        Error(_) -> api.error(500, "INTERNAL", "Database error")
      }
    }
  }
}

fn handle_put_member_capabilities(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: Int,
  target_user_id: Int,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Put)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) -> {
      // User can update their own capabilities, or manager can update any member
      let auth.Ctx(db: db, ..) = ctx
      let can_update = case user.id == target_user_id {
        True -> projects_db.is_project_member(db, project_id, user.id)
        False -> projects_db.is_project_manager(db, project_id, user.id)
      }

      case can_update {
        Ok(True) -> update_member_capabilities(req, ctx, project_id, target_user_id)
        Ok(False) -> api.error(403, "FORBIDDEN", "Not authorized")
        Error(_) -> api.error(500, "INTERNAL", "Database error")
      }
    }
  }
}

fn update_member_capabilities(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: Int,
  user_id: Int,
) -> wisp.Response {
  case csrf.require_double_submit(req) {
    Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")

    Ok(Nil) -> {
      use data <- wisp.require_json(req)

      let decoder = {
        use ids <- decode.field("capability_ids", decode.list(decode.int))
        decode.success(ids)
      }

      case decode.run(data, decoder) {
        Error(_) -> api.error(400, "VALIDATION_ERROR", "Invalid JSON")

        Ok(new_ids) -> {
          let auth.Ctx(db: db, ..) = ctx

          // First, verify all capability IDs belong to this project
          let validation_result = list.try_map(new_ids, fn(cap_id) {
            case capabilities_db.capability_is_in_project(db, cap_id, project_id) {
              Ok(True) -> Ok(cap_id)
              Ok(False) -> Error("invalid")
              Error(_) -> Error("db_error")
            }
          })

          case validation_result {
            Error("invalid") ->
              api.error(422, "VALIDATION_ERROR", "Invalid capability_id")
            Error(_) ->
              api.error(500, "INTERNAL", "Database error")
            Ok(_) -> {
              // Remove all existing and add new ones
              case capabilities_db.remove_all_member_capabilities(db, project_id, user_id) {
                Error(_) -> api.error(500, "INTERNAL", "Database error")
                Ok(Nil) -> {
                  let add_result = list.try_map(new_ids, fn(cap_id) {
                    capabilities_db.add_member_capability(db, project_id, user_id, cap_id)
                  })
                  case add_result {
                    Ok(_) -> api.ok(json.object([#("capability_ids", ids_json(new_ids))]))
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
}

fn ids_json(values: List(Int)) -> json.Json {
  json.array(values, of: fn(id) { json.int(id) })
}

fn capability_json(capability: capabilities_db.Capability) -> json.Json {
  let capabilities_db.Capability(
    id: id,
    project_id: project_id,
    name: name,
    created_at: created_at,
  ) = capability

  json.object([
    #("id", json.int(id)),
    #("project_id", json.int(project_id)),
    #("name", json.string(name)),
    #("created_at", json.string(created_at)),
  ])
}

// =============================================================================
// Capability Members (Story 4.7 AC20-21) - Reverse direction
// =============================================================================

/// Routes /api/projects/:id/capabilities/:cap_id/members requests.
pub fn handle_capability_members(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: Int,
  capability_id: Int,
) -> wisp.Response {
  case req.method {
    http.Get -> handle_get_capability_members(req, ctx, project_id, capability_id)
    http.Put -> handle_put_capability_members(req, ctx, project_id, capability_id)
    _ -> wisp.method_not_allowed([http.Get, http.Put])
  }
}

fn handle_get_capability_members(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: Int,
  capability_id: Int,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) -> {
      let auth.Ctx(db: db, ..) = ctx

      // Must be a member of the project
      case projects_db.is_project_member(db, project_id, user.id) {
        Ok(True) -> {
          case capabilities_db.list_capability_members(db, project_id, capability_id) {
            Ok(members) -> {
              let ids = list.map(members, fn(m) { m.user_id })
              api.ok(json.object([#("user_ids", ids_json(ids))]))
            }
            Error(_) -> api.error(500, "INTERNAL", "Database error")
          }
        }
        Ok(False) -> api.error(403, "FORBIDDEN", "Not a member of this project")
        Error(_) -> api.error(500, "INTERNAL", "Database error")
      }
    }
  }
}

fn handle_put_capability_members(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: Int,
  capability_id: Int,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Put)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) -> {
      // Only managers can set capability members
      let auth.Ctx(db: db, ..) = ctx

      case require_project_manager(db, user, project_id) {
        Error(resp) -> resp
        Ok(Nil) -> update_capability_members(req, ctx, project_id, capability_id)
      }
    }
  }
}

fn update_capability_members(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: Int,
  capability_id: Int,
) -> wisp.Response {
  case csrf.require_double_submit(req) {
    Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")

    Ok(Nil) -> {
      use data <- wisp.require_json(req)

      let decoder = {
        use ids <- decode.field("user_ids", decode.list(decode.int))
        decode.success(ids)
      }

      case decode.run(data, decoder) {
        Error(_) -> api.error(400, "VALIDATION_ERROR", "Invalid JSON")

        Ok(new_ids) -> {
          let auth.Ctx(db: db, ..) = ctx

          // First, verify all user IDs are project members
          let validation_result = list.try_map(new_ids, fn(user_id) {
            case projects_db.is_project_member(db, project_id, user_id) {
              Ok(True) -> Ok(user_id)
              Ok(False) -> Error("invalid")
              Error(_) -> Error("db_error")
            }
          })

          case validation_result {
            Error("invalid") ->
              api.error(422, "VALIDATION_ERROR", "Invalid user_id (not a project member)")
            Error(_) ->
              api.error(500, "INTERNAL", "Database error")
            Ok(_) -> {
              // Remove all existing and add new ones
              case capabilities_db.remove_all_capability_members(db, project_id, capability_id) {
                Error(_) -> api.error(500, "INTERNAL", "Database error")
                Ok(Nil) -> {
                  let add_result = list.try_map(new_ids, fn(user_id) {
                    capabilities_db.add_member_capability(db, project_id, user_id, capability_id)
                  })
                  case add_result {
                    Ok(_) -> api.ok(json.object([#("user_ids", ids_json(new_ids))]))
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
}
