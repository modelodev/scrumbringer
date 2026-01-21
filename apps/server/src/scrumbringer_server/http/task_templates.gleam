//// HTTP handlers for task templates.
////
//// Provides CRUD endpoints for project-scoped templates.

import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import helpers/json as json_helpers
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/authorization
import scrumbringer_server/http/csrf
import scrumbringer_server/services/projects_db
import scrumbringer_server/services/task_templates_db
import wisp

// =============================================================================
// Context + Routing
// =============================================================================

pub fn handle_project_templates(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> wisp.Response {
  case req.method {
    http.Get -> handle_list_project(req, ctx, project_id)
    http.Post -> handle_create_project(req, ctx, project_id)
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}

pub fn handle_template(
  req: wisp.Request,
  ctx: auth.Ctx,
  template_id: String,
) -> wisp.Response {
  case req.method {
    http.Patch -> handle_update(req, ctx, template_id)
    http.Delete -> handle_delete(req, ctx, template_id)
    _ -> wisp.method_not_allowed([http.Patch, http.Delete])
  }
}

// =============================================================================
// Handlers
// =============================================================================

fn handle_list_project(
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

          case projects_db.is_project_manager(db, project_id, user.id) {
            Ok(True) ->
              case task_templates_db.list_project_templates(db, project_id) {
                Ok(templates) ->
                  api.ok(
                    json.object([
                      #("templates", json.array(templates, of: template_json)),
                    ]),
                  )

                Error(_) -> api.error(500, "INTERNAL", "Database error")
              }

            Ok(False) -> api.error(403, "FORBIDDEN", "Forbidden")
            Error(_) -> api.error(500, "INTERNAL", "Database error")
          }
        }
      }
  }
}

fn handle_create_project(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case int.parse(project_id) {
        Error(_) -> api.error(404, "NOT_FOUND", "Not found")

        Ok(project_id) -> {
          let auth.Ctx(db: db, ..) = ctx

          case projects_db.is_project_manager(db, project_id, user.id) {
            Ok(True) ->
              create_template(req, ctx, user.org_id, project_id, user.id)
            Ok(False) -> api.error(403, "FORBIDDEN", "Forbidden")
            Error(_) -> api.error(500, "INTERNAL", "Database error")
          }
        }
      }
  }
}

fn handle_update(
  req: wisp.Request,
  ctx: auth.Ctx,
  template_id: String,
) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case int.parse(template_id) {
        Error(_) -> api.error(404, "NOT_FOUND", "Not found")

        Ok(template_id) -> {
          let auth.Ctx(db: db, ..) = ctx

          case task_templates_db.get_template(db, template_id) {
            Ok(template) ->
              case
                authorization.require_project_manager(
                  db,
                  user,
                  template.org_id,
                  template.project_id,
                )
              {
                Error(resp) -> resp
                Ok(#(org_id, project_id)) ->
                  update_template(req, ctx, template_id, org_id, project_id)
              }

            Error(task_templates_db.UpdateNotFound) ->
              api.error(404, "NOT_FOUND", "Not found")
            Error(task_templates_db.UpdateDbError(_)) ->
              api.error(500, "INTERNAL", "Database error")
            Error(task_templates_db.UpdateInvalidTypeId) ->
              api.error(422, "VALIDATION_ERROR", "Invalid type_id")
          }
        }
      }
  }
}

fn handle_delete(
  req: wisp.Request,
  ctx: auth.Ctx,
  template_id: String,
) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")

    Ok(user) ->
      case int.parse(template_id) {
        Error(_) -> api.error(404, "NOT_FOUND", "Not found")

        Ok(template_id) -> {
          let auth.Ctx(db: db, ..) = ctx

          case task_templates_db.get_template(db, template_id) {
            Ok(template) ->
              case
                authorization.require_project_manager(
                  db,
                  user,
                  template.org_id,
                  template.project_id,
                )
              {
                Error(resp) -> resp
                Ok(#(org_id, _project_id)) ->
                  case csrf.require_double_submit(req) {
                    Error(_) ->
                      api.error(
                        403,
                        "FORBIDDEN",
                        "CSRF token missing or invalid",
                      )
                    Ok(Nil) ->
                      case
                        task_templates_db.delete_template(
                          db,
                          template_id,
                          org_id,
                        )
                      {
                        Ok(Nil) -> api.no_content()
                        Error(task_templates_db.DeleteNotFound) ->
                          api.error(404, "NOT_FOUND", "Not found")
                        Error(task_templates_db.DeleteDbError(_)) ->
                          api.error(500, "INTERNAL", "Database error")
                      }
                  }
              }

            Error(task_templates_db.UpdateNotFound) ->
              api.error(404, "NOT_FOUND", "Not found")
            Error(task_templates_db.UpdateDbError(_)) ->
              api.error(500, "INTERNAL", "Database error")
            Error(task_templates_db.UpdateInvalidTypeId) ->
              api.error(422, "VALIDATION_ERROR", "Invalid type_id")
          }
        }
      }
  }
}

// =============================================================================
// Shared helpers
// =============================================================================

fn create_template(
  req: wisp.Request,
  ctx: auth.Ctx,
  org_id: Int,
  project_id: Int,
  user_id: Int,
) -> wisp.Response {
  case csrf.require_double_submit(req) {
    Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")

    Ok(Nil) -> {
      use data <- wisp.require_json(req)

      let decoder = {
        use name <- decode.field("name", decode.string)
        use description <- decode.optional_field(
          "description",
          "",
          decode.string,
        )
        use type_id <- decode.field("type_id", decode.int)
        use priority <- decode.optional_field("priority", 3, decode.int)
        decode.success(#(name, description, type_id, priority))
      }

      case decode.run(data, decoder) {
        Error(_) -> api.error(400, "VALIDATION_ERROR", "Invalid JSON")

        Ok(#(name, description, type_id, priority)) -> {
          let auth.Ctx(db: db, ..) = ctx

          case
            task_templates_db.create_template(
              db,
              org_id,
              project_id,
              name,
              description,
              type_id,
              priority,
              user_id,
            )
          {
            Ok(template) ->
              api.ok(json.object([#("template", template_json(template))]))

            Error(task_templates_db.CreateInvalidTypeId) ->
              api.error(422, "VALIDATION_ERROR", "Invalid type_id")
            Error(task_templates_db.CreateDbError(_)) ->
              api.error(500, "INTERNAL", "Database error")
          }
        }
      }
    }
  }
}

fn update_template(
  req: wisp.Request,
  ctx: auth.Ctx,
  template_id: Int,
  org_id: Int,
  project_id: Int,
) -> wisp.Response {
  case csrf.require_double_submit(req) {
    Error(_) -> api.error(403, "FORBIDDEN", "CSRF token missing or invalid")

    Ok(Nil) -> {
      use data <- wisp.require_json(req)

      let decoder = {
        use name <- decode.optional_field("name", "__unset__", decode.string)
        use description <- decode.optional_field(
          "description",
          "__unset__",
          decode.string,
        )
        use type_id <- decode.optional_field("type_id", -1, decode.int)
        use priority <- decode.optional_field("priority", -1, decode.int)
        decode.success(#(name, description, type_id, priority))
      }

      case decode.run(data, decoder) {
        Error(_) -> api.error(400, "VALIDATION_ERROR", "Invalid JSON")

        Ok(#(name, description, type_id, priority)) -> {
          let auth.Ctx(db: db, ..) = ctx

          case
            task_templates_db.update_template(
              db,
              template_id,
              org_id,
              project_id,
              name,
              description,
              type_id,
              priority,
            )
          {
            Ok(template) ->
              api.ok(json.object([#("template", template_json(template))]))

            Error(task_templates_db.UpdateNotFound) ->
              api.error(404, "NOT_FOUND", "Not found")
            Error(task_templates_db.UpdateInvalidTypeId) ->
              api.error(422, "VALIDATION_ERROR", "Invalid type_id")
            Error(task_templates_db.UpdateDbError(_)) ->
              api.error(500, "INTERNAL", "Database error")
          }
        }
      }
    }
  }
}

fn template_json(template: task_templates_db.TaskTemplate) -> json.Json {
  let task_templates_db.TaskTemplate(
    id: id,
    org_id: org_id,
    project_id: project_id,
    name: name,
    description: description,
    type_id: type_id,
    type_name: type_name,
    priority: priority,
    created_by: created_by,
    created_at: created_at,
  ) = template

  json.object([
    #("id", json.int(id)),
    #("org_id", json.int(org_id)),
    #("project_id", json.int(project_id)),
    #("name", json.string(name)),
    #("description", json_helpers.option_string_json(description)),
    #("type_id", json.int(type_id)),
    #("type_name", json.string(type_name)),
    #("priority", json.int(priority)),
    #("created_by", json.int(created_by)),
    #("created_at", json.string(created_at)),
  ])
}
