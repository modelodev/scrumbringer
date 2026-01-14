import gleam/dynamic/decode
import gleam/http
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/string
import scrumbringer_domain/org_role
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/services/org_invite_links_db
import wisp

pub fn handle_invite_links(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  case req.method {
    http.Get -> handle_list(req, ctx)
    http.Post -> handle_upsert(req, ctx)
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}

pub fn handle_regenerate(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)
  handle_upsert(req, ctx)
}

fn handle_list(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case user.org_role {
        org_role.Admin -> {
          let auth.Ctx(db: db, ..) = ctx

          case org_invite_links_db.list_invite_links(db, user.org_id) {
            Ok(links) ->
              api.ok(
                json.object([
                  #("invite_links", json.array(links, of: invite_link_json)),
                ]),
              )
            Error(_) -> api.error(500, "INTERNAL", "Database error")
          }
        }

        _ -> api.error(403, "FORBIDDEN", "Forbidden")
      }
  }
}

fn handle_upsert(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) -> {
      case user.org_role {
        org_role.Admin -> upsert_as_admin(req, ctx, user.id, user.org_id)
        _ -> api.error(403, "FORBIDDEN", "Forbidden")
      }
    }
  }
}

fn upsert_as_admin(
  req: wisp.Request,
  ctx: auth.Ctx,
  user_id: Int,
  org_id: Int,
) -> wisp.Response {
  case csrf.require_double_submit(req) {
    Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")

    Ok(Nil) -> {
      use data <- wisp.require_json(req)

      let decoder = {
        use email <- decode.field("email", decode.string)
        decode.success(email)
      }

      case decode.run(data, decoder) {
        Error(_) -> api.error(400, "VALIDATION_ERROR", "Invalid JSON")

        Ok(email_raw) -> {
          let email = normalize_email(email_raw)

          case validate_email(email) {
            Error(_) -> api.error(422, "VALIDATION_ERROR", "Invalid email")

            Ok(Nil) -> {
              let auth.Ctx(db: db, ..) = ctx

              case
                org_invite_links_db.upsert_invite_link(
                  db,
                  org_id,
                  user_id,
                  email,
                )
              {
                Ok(link) ->
                  api.ok(
                    json.object([#("invite_link", invite_link_json(link))]),
                  )

                Error(org_invite_links_db.NoRowReturned) ->
                  api.error(500, "INTERNAL", "Database error")

                Error(org_invite_links_db.DbError(_)) ->
                  api.error(500, "INTERNAL", "Database error")
              }
            }
          }
        }
      }
    }
  }
}

fn normalize_email(email: String) -> String {
  email
  |> string.trim
  |> string.lowercase
}

fn validate_email(email: String) -> Result(Nil, Nil) {
  case string.contains(email, "@") {
    False -> Error(Nil)

    True -> {
      case string.split_once(email, "@") {
        Error(_) -> Error(Nil)
        Ok(#(local, domain)) ->
          case local == "" || domain == "" {
            True -> Error(Nil)
            False ->
              case string.contains(domain, ".") {
                True -> Ok(Nil)
                False -> Error(Nil)
              }
          }
      }
    }
  }
}

fn invite_link_json(link: org_invite_links_db.OrgInviteLink) -> json.Json {
  let org_invite_links_db.OrgInviteLink(
    email: email,
    token: token,
    state: state,
    created_at: created_at,
    used_at: used_at,
    invalidated_at: invalidated_at,
  ) = link

  json.object([
    #("email", json.string(email)),
    #("token", json.string(token)),
    #("url_path", json.string(org_invite_links_db.url_path(token))),
    #("state", json.string(org_invite_links_db.state_to_string(state))),
    #("created_at", json.string(created_at)),
    #("used_at", option_string_json(used_at)),
    #("invalidated_at", option_string_json(invalidated_at)),
  ])
}

fn option_string_json(value: Option(String)) -> json.Json {
  case value {
    None -> json.null()
    Some(v) -> json.string(v)
  }
}
