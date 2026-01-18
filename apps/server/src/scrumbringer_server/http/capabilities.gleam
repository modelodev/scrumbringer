//// HTTP handlers for organization capabilities (skills).
////
//// Provides endpoints for listing and creating capabilities,
//// as well as managing user capability selections.

import gleam/dynamic/decode
import gleam/http
import gleam/json
import domain/org_role
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/services/capabilities_db
import scrumbringer_server/services/user_capabilities_db
import wisp

/// Routes /api/capabilities requests (GET list, POST create).
pub fn handle_capabilities(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  case req.method {
    http.Get -> handle_list(req, ctx)
    http.Post -> handle_create(req, ctx)
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}

/// Routes /api/me/capabilities requests (GET/PUT user selections).
pub fn handle_me_capabilities(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  case req.method {
    http.Get -> handle_get_me(req, ctx)
    http.Put -> handle_put_me(req, ctx)
    _ -> wisp.method_not_allowed([http.Get, http.Put])
  }
}

fn handle_list(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) -> {
      let auth.Ctx(db: db, ..) = ctx

      case capabilities_db.list_capabilities_for_org(db, user.org_id) {
        Ok(capabilities) ->
          api.ok(
            json.object([
              #("capabilities", json.array(capabilities, of: capability_json)),
            ]),
          )

        Error(_) -> api.error(500, "INTERNAL", "Database error")
      }
    }
  }
}

fn handle_create(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) -> {
      case user.org_role {
        org_role.Admin -> create_as_admin(req, ctx, user.org_id)
        _ -> api.error(403, "FORBIDDEN", "Forbidden")
      }
    }
  }
}

fn create_as_admin(
  req: wisp.Request,
  ctx: auth.Ctx,
  org_id: Int,
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

          case capabilities_db.create_capability(db, org_id, name) {
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

fn handle_get_me(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) -> {
      let auth.Ctx(db: db, ..) = ctx

      case
        user_capabilities_db.get_selected_capability_ids(
          db,
          user.id,
          user.org_id,
        )
      {
        Ok(ids) -> api.ok(json.object([#("capability_ids", ids_json(ids))]))
        Error(_) -> api.error(500, "INTERNAL", "Database error")
      }
    }
  }
}

fn handle_put_me(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Put)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) -> {
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

            Ok(ids) -> {
              let auth.Ctx(db: db, ..) = ctx

              case
                user_capabilities_db.set_selected_capability_ids(
                  db,
                  user.id,
                  user.org_id,
                  ids,
                )
              {
                Ok(stored) ->
                  api.ok(json.object([#("capability_ids", ids_json(stored))]))

                Error(user_capabilities_db.InvalidCapabilityId(_)) ->
                  api.error(422, "VALIDATION_ERROR", "Invalid capability_id")

                Error(_) -> api.error(500, "INTERNAL", "Database error")
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
    org_id: org_id,
    name: name,
    created_at: created_at,
  ) = capability

  json.object([
    #("id", json.int(id)),
    #("org_id", json.int(org_id)),
    #("name", json.string(name)),
    #("created_at", json.string(created_at)),
  ])
}
