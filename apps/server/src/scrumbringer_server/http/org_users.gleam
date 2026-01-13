import gleam/http
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import pog
import scrumbringer_domain/org_role
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/services/org_users_db
import scrumbringer_server/services/projects_db
import wisp

pub fn handle_org_users(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  case req.method {
    http.Get -> handle_list(req, ctx)
    _ -> wisp.method_not_allowed([http.Get])
  }
}

fn handle_list(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) -> {
      let auth.Ctx(db: db, ..) = ctx

      case
        require_org_user_directory_access(
          db,
          user.id,
          user.org_id,
          user.org_role,
        )
      {
        Error(resp) -> resp

        Ok(Nil) -> {
          let query = wisp.get_query(req)

          case parse_q(query) {
            Error(resp) -> resp

            Ok(q) ->
              case org_users_db.list_org_users(db, user.org_id, q) {
                Ok(users) ->
                  api.ok(
                    json.object([#("users", json.array(users, of: user_json))]),
                  )
                Error(_) -> api.error(500, "INTERNAL", "Database error")
              }
          }
        }
      }
    }
  }
}

fn require_org_user_directory_access(
  db: pog.Connection,
  user_id: Int,
  org_id: Int,
  role: org_role.OrgRole,
) -> Result(Nil, wisp.Response) {
  case role {
    org_role.Admin -> Ok(Nil)
    _ ->
      case projects_db.is_any_project_admin_in_org(db, user_id, org_id) {
        Ok(True) -> Ok(Nil)
        Ok(False) -> Error(api.error(403, "FORBIDDEN", "Forbidden"))
        Error(_) -> Error(api.error(500, "INTERNAL", "Database error"))
      }
  }
}

fn parse_q(query: List(#(String, String))) -> Result(String, wisp.Response) {
  case single_query_value(query, "q") {
    Ok(None) -> Ok("")
    Ok(Some(v)) -> Ok(v)
    Error(_) -> Error(api.error(422, "VALIDATION_ERROR", "Invalid q"))
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

fn user_json(user: org_users_db.OrgUser) -> json.Json {
  let org_users_db.OrgUser(
    id: id,
    email: email,
    org_role: org_role,
    created_at: created_at,
  ) = user

  json.object([
    #("id", json.int(id)),
    #("email", json.string(email)),
    #("org_role", json.string(org_role)),
    #("created_at", json.string(created_at)),
  ])
}
