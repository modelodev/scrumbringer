//// HTTP handlers for organization user management.
////
//// ## Mission
////
//// Provides endpoints for listing and managing organization members.
////
//// ## Responsibilities
////
//// - List users in an organization
//// - Update user roles (admin only)
//// - Remove users from organizations

import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import pog
import domain/org_role
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/csrf
import scrumbringer_server/services/org_users_db
import scrumbringer_server/services/projects_db
import scrumbringer_server/sql
import wisp

pub fn handle_org_users(req: wisp.Request, ctx: auth.Ctx) -> wisp.Response {
  case req.method {
    http.Get -> handle_list(req, ctx)
    _ -> wisp.method_not_allowed([http.Get])
  }
}

pub fn handle_org_user(
  req: wisp.Request,
  ctx: auth.Ctx,
  user_id: String,
) -> wisp.Response {
  case req.method {
    http.Patch -> handle_update(req, ctx, user_id)
    _ -> wisp.method_not_allowed([http.Patch])
  }
}

fn handle_update(
  req: wisp.Request,
  ctx: auth.Ctx,
  user_id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Patch)
  use data <- wisp.require_json(req)

  case int.parse(user_id) {
    Error(_) -> api.error(422, "VALIDATION_ERROR", "Invalid user_id")

    Ok(target_user_id) -> {
      let decoder = {
        use role <- decode.field("org_role", decode.string)
        decode.success(role)
      }

      case decode.run(data, decoder) {
        Error(_) -> api.error(422, "VALIDATION_ERROR", "Invalid JSON")

        Ok(new_role) -> {
          case auth.require_current_user(req, ctx) {
            Error(_) ->
              api.error(401, "AUTH_REQUIRED", "Authentication required")

            Ok(user) -> {
              case user.org_role {
                org_role.Admin -> {
                  case csrf.require_double_submit(req) {
                    Error(_) ->
                      api.error(
                        403,
                        "FORBIDDEN",
                        "CSRF token missing or invalid",
                      )

                    Ok(Nil) -> {
                      let auth.Ctx(db: db, ..) = ctx

                      case
                        org_users_db.update_org_role(
                          db,
                          user.org_id,
                          target_user_id,
                          new_role,
                        )
                      {
                        Ok(updated) ->
                          api.ok(json.object([#("user", user_json(updated))]))

                        Error(org_users_db.InvalidRole) ->
                          api.error(422, "VALIDATION_ERROR", "Invalid org_role")

                        Error(org_users_db.UserNotFound) ->
                          api.error(404, "NOT_FOUND", "User not found")

                        Error(org_users_db.CannotDemoteLastAdmin) ->
                          api.error(
                            409,
                            "CONFLICT_LAST_ORG_ADMIN",
                            "Cannot demote last org admin",
                          )

                        Error(org_users_db.DbError(_)) ->
                          api.error(500, "INTERNAL", "Database error")
                      }
                    }
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

// =============================================================================
// User Projects Handlers
// =============================================================================

/// Handle GET/POST for /api/v1/org/users/:user_id/projects
pub fn handle_user_projects(
  req: wisp.Request,
  ctx: auth.Ctx,
  user_id: String,
) -> wisp.Response {
  case req.method {
    http.Get -> handle_list_user_projects(req, ctx, user_id)
    http.Post -> handle_add_user_to_project(req, ctx, user_id)
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}

/// Handle DELETE for /api/v1/org/users/:user_id/projects/:project_id
pub fn handle_user_project(
  req: wisp.Request,
  ctx: auth.Ctx,
  user_id: String,
  project_id: String,
) -> wisp.Response {
  case req.method {
    http.Delete -> handle_remove_user_from_project(req, ctx, user_id, project_id)
    _ -> wisp.method_not_allowed([http.Delete])
  }
}

fn handle_list_user_projects(
  req: wisp.Request,
  ctx: auth.Ctx,
  user_id_str: String,
) -> wisp.Response {
  case int.parse(user_id_str) {
    Error(_) -> api.error(422, "VALIDATION_ERROR", "Invalid user_id")

    Ok(target_user_id) -> {
      case auth.require_current_user(req, ctx) {
        Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

        Ok(user) -> {
          // Only org admins can view other users' projects
          case user.org_role {
            org_role.Admin -> {
              let auth.Ctx(db: db, ..) = ctx

              // Verify target user is in the same org
              case verify_same_org(db, target_user_id, user.org_id) {
                Error(resp) -> resp
                Ok(Nil) -> {
                  case projects_db.list_projects_for_user(db, target_user_id) {
                    Ok(projects) ->
                      api.ok(
                        json.object([
                          #("projects", json.array(projects, of: project_json)),
                        ]),
                      )
                    Error(_) -> api.error(500, "INTERNAL", "Database error")
                  }
                }
              }
            }

            _ -> api.error(403, "FORBIDDEN", "Only org admins can manage user projects")
          }
        }
      }
    }
  }
}

fn handle_add_user_to_project(
  req: wisp.Request,
  ctx: auth.Ctx,
  user_id_str: String,
) -> wisp.Response {
  use data <- wisp.require_json(req)

  case int.parse(user_id_str) {
    Error(_) -> api.error(422, "VALIDATION_ERROR", "Invalid user_id")

    Ok(target_user_id) -> {
      let decoder = {
        use project_id <- decode.field("project_id", decode.int)
        decode.success(project_id)
      }

      case decode.run(data, decoder) {
        Error(_) -> api.error(422, "VALIDATION_ERROR", "Invalid JSON: project_id required")

        Ok(project_id) -> {
          case auth.require_current_user(req, ctx) {
            Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

            Ok(user) -> {
              case user.org_role {
                org_role.Admin -> {
                  case csrf.require_double_submit(req) {
                    Error(_) ->
                      api.error(403, "FORBIDDEN", "CSRF token missing or invalid")

                    Ok(Nil) -> {
                      let auth.Ctx(db: db, ..) = ctx

                      case projects_db.add_member(db, project_id, target_user_id, "member") {
                        Ok(member) ->
                          api.ok(
                            json.object([
                              #("project", project_member_json(project_id, member)),
                            ]),
                          )

                        Error(projects_db.ProjectNotFound) ->
                          api.error(404, "NOT_FOUND", "Project not found")

                        Error(projects_db.TargetUserNotFound) ->
                          api.error(404, "NOT_FOUND", "User not found")

                        Error(projects_db.TargetUserWrongOrg) ->
                          api.error(403, "FORBIDDEN", "User not in same organization")

                        Error(projects_db.AlreadyMember) ->
                          api.error(409, "CONFLICT", "User is already a member of this project")

                        Error(projects_db.InvalidRole) ->
                          api.error(422, "VALIDATION_ERROR", "Invalid role")

                        Error(projects_db.DbError(_)) ->
                          api.error(500, "INTERNAL", "Database error")
                      }
                    }
                  }
                }

                _ -> api.error(403, "FORBIDDEN", "Only org admins can add users to projects")
              }
            }
          }
        }
      }
    }
  }
}

fn handle_remove_user_from_project(
  req: wisp.Request,
  ctx: auth.Ctx,
  user_id_str: String,
  project_id_str: String,
) -> wisp.Response {
  case int.parse(user_id_str), int.parse(project_id_str) {
    Error(_), _ -> api.error(422, "VALIDATION_ERROR", "Invalid user_id")
    _, Error(_) -> api.error(422, "VALIDATION_ERROR", "Invalid project_id")

    Ok(target_user_id), Ok(project_id) -> {
      case auth.require_current_user(req, ctx) {
        Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

        Ok(user) -> {
          case user.org_role {
            org_role.Admin -> {
              case csrf.require_double_submit(req) {
                Error(_) ->
                  api.error(403, "FORBIDDEN", "CSRF token missing or invalid")

                Ok(Nil) -> {
                  let auth.Ctx(db: db, ..) = ctx

                  case projects_db.remove_member(db, project_id, target_user_id) {
                    Ok(Nil) -> api.ok(json.object([]))

                    Error(projects_db.MembershipNotFound) ->
                      api.error(404, "NOT_FOUND", "Membership not found")

                    Error(projects_db.CannotRemoveLastAdmin) ->
                      api.error(409, "CONFLICT", "Cannot remove last project admin")

                    Error(projects_db.RemoveDbError(_)) ->
                      api.error(500, "INTERNAL", "Database error")
                  }
                }
              }
            }

            _ -> api.error(403, "FORBIDDEN", "Only org admins can remove users from projects")
          }
        }
      }
    }
  }
}

fn verify_same_org(
  db: pog.Connection,
  user_id: Int,
  org_id: Int,
) -> Result(Nil, wisp.Response) {
  case sql.users_org_id(db, user_id) {
    Ok(pog.Returned(rows: [row, ..], ..)) ->
      case row.org_id == org_id {
        True -> Ok(Nil)
        False -> Error(api.error(404, "NOT_FOUND", "User not found"))
      }
    Ok(pog.Returned(rows: [], ..)) ->
      Error(api.error(404, "NOT_FOUND", "User not found"))
    Error(_) ->
      Error(api.error(500, "INTERNAL", "Database error"))
  }
}

fn project_json(project: projects_db.Project) -> json.Json {
  json.object([
    #("id", json.int(project.id)),
    #("name", json.string(project.name)),
    #("role", json.string(project.my_role)),
  ])
}

fn project_member_json(project_id: Int, member: projects_db.ProjectMember) -> json.Json {
  // We need to fetch project name - for now return minimal info
  json.object([
    #("id", json.int(project_id)),
    #("name", json.string("")),  // Would need separate query
    #("role", json.string(member.role)),
  ])
}
