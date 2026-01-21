//// HTTP handlers for project management.
////
//// ## Mission
////
//// Provides HTTP endpoints for CRUD operations on projects and project members.
////
//// ## Responsibilities
////
//// - List projects for authenticated user
//// - Create projects (org admin only)
//// - List, add, and remove project members (project admin only)
////
//// ## Non-responsibilities
////
//// - Database operations (see `services/projects_db.gleam`)
//// - Authentication (see `http/auth.gleam`)

import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import pog
import domain/org_role
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/services/projects_db
import wisp

pub fn handle_projects(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  case req.method {
    http.Get -> handle_list(req, ctx)
    http.Post -> handle_create(req, ctx)
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}

pub fn handle_members(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> wisp.Response {
  case req.method {
    http.Get -> handle_members_list(req, ctx, project_id)
    http.Post -> handle_members_add(req, ctx, project_id)
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}

pub fn handle_member_remove(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
  user_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Delete)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) -> {
      case csrf.require_double_submit(req) {
        Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")

        Ok(Nil) -> {
          case int.parse(project_id) {
            Error(_) -> api.error(404, "NOT_FOUND", "Not found")

            Ok(project_id) ->
              case int.parse(user_id) {
                Error(_) -> api.error(404, "NOT_FOUND", "Not found")

                Ok(target_user_id) -> {
                  let auth.Ctx(db: db, ..) = ctx

                  case require_project_admin(db, project_id, user.id) {
                    Error(resp) -> resp

                    Ok(Nil) -> {
                      case
                        projects_db.remove_member(
                          db,
                          project_id,
                          target_user_id,
                        )
                      {
                        Ok(Nil) -> api.no_content()

                        Error(projects_db.MembershipNotFound) ->
                          api.error(404, "NOT_FOUND", "Membership not found")

                        Error(projects_db.CannotRemoveLastManager) ->
                          api.error(
                            422,
                            "VALIDATION_ERROR",
                            "Cannot remove last project admin",
                          )

                        Error(projects_db.RemoveDbError(_)) ->
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

fn handle_create(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) -> {
      case user.org_role {
        org_role.Admin -> create_as_admin(req, ctx, user.id, user.org_id)
        _ -> api.error(403, "FORBIDDEN", "Forbidden")
      }
    }
  }
}

fn create_as_admin(
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
        use name <- decode.field("name", decode.string)
        decode.success(name)
      }

      case decode.run(data, decoder) {
        Error(_) -> api.error(400, "VALIDATION_ERROR", "Invalid JSON")

        Ok(name) -> {
          let auth.Ctx(db: db, ..) = ctx

          case projects_db.create_project(db, org_id, user_id, name) {
            Ok(project) ->
              api.ok(json.object([#("project", project_json(project))]))
            Error(_) -> api.error(500, "INTERNAL", "Database error")
          }
        }
      }
    }
  }
}

fn handle_list(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) -> {
      let auth.Ctx(db: db, ..) = ctx

      case projects_db.list_projects_for_user(db, user.id) {
        Ok(projects) ->
          api.ok(
            json.object([
              #("projects", projects |> list_to_json(fn(p) { project_json(p) })),
            ]),
          )
        Error(_) -> api.error(500, "INTERNAL", "Database error")
      }
    }
  }
}

fn handle_members_list(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) -> {
      case int.parse(project_id) {
        Error(_) -> api.error(404, "NOT_FOUND", "Not found")

        Ok(project_id) -> {
          let auth.Ctx(db: db, ..) = ctx

          case require_project_admin(db, project_id, user.id) {
            Error(resp) -> resp

            Ok(Nil) -> {
              case projects_db.list_members(db, project_id) {
                Ok(members) ->
                  api.ok(
                    json.object([
                      #(
                        "members",
                        members |> list_to_json(fn(m) { member_json(m) }),
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
  }
}

fn handle_members_add(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) -> {
      case csrf.require_double_submit(req) {
        Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")

        Ok(Nil) -> {
          case int.parse(project_id) {
            Error(_) -> api.error(404, "NOT_FOUND", "Not found")

            Ok(project_id) -> {
              let auth.Ctx(db: db, ..) = ctx

              case require_project_admin(db, project_id, user.id) {
                Error(resp) -> resp

                Ok(Nil) -> {
                  use data <- wisp.require_json(req)

                  let decoder = {
                    use user_id <- decode.field("user_id", decode.int)
                    use role <- decode.field("role", decode.string)
                    decode.success(#(user_id, role))
                  }

                  case decode.run(data, decoder) {
                    Error(_) ->
                      api.error(400, "VALIDATION_ERROR", "Invalid JSON")

                    Ok(#(target_user_id, role)) -> {
                      case
                        projects_db.add_member(
                          db,
                          project_id,
                          target_user_id,
                          role,
                        )
                      {
                        Ok(member) ->
                          api.ok(
                            json.object([#("member", member_json(member))]),
                          )

                        Error(projects_db.ProjectNotFound) ->
                          api.error(404, "NOT_FOUND", "Project not found")

                        Error(projects_db.TargetUserNotFound) ->
                          api.error(404, "NOT_FOUND", "User not found")

                        Error(projects_db.TargetUserWrongOrg) ->
                          api.error(
                            422,
                            "VALIDATION_ERROR",
                            "User must be in same organization",
                          )

                        Error(projects_db.AlreadyMember) ->
                          api.error(
                            422,
                            "VALIDATION_ERROR",
                            "User is already a member",
                          )

                        Error(projects_db.InvalidRole) ->
                          api.error(422, "VALIDATION_ERROR", "Invalid role")

                        Error(projects_db.DbError(_)) ->
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

fn require_project_admin(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
) -> Result(Nil, wisp.Response) {
  case projects_db.is_project_manager(db, project_id, user_id) {
    Ok(True) -> Ok(Nil)
    Ok(False) -> Error(api.error(403, "FORBIDDEN", "Forbidden"))
    Error(_) -> Error(api.error(500, "INTERNAL", "Database error"))
  }
}

fn list_to_json(values: List(a), f: fn(a) -> json.Json) -> json.Json {
  json.array(values, of: f)
}

fn project_json(project: projects_db.Project) -> json.Json {
  let projects_db.Project(
    id: id,
    org_id: org_id,
    name: name,
    created_at: created_at,
    my_role: my_role,
  ) = project

  json.object([
    #("id", json.int(id)),
    #("org_id", json.int(org_id)),
    #("name", json.string(name)),
    #("created_at", json.string(created_at)),
    #("my_role", json.string(my_role)),
  ])
}

fn member_json(member: projects_db.ProjectMember) -> json.Json {
  let projects_db.ProjectMember(
    project_id: project_id,
    user_id: user_id,
    role: role,
    created_at: created_at,
  ) = member

  json.object([
    #("project_id", json.int(project_id)),
    #("user_id", json.int(user_id)),
    #("role", json.string(role)),
    #("created_at", json.string(created_at)),
  ])
}
