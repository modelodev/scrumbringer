//// HTTP handlers for task templates.
////
//// ## Mission
////
//// Provide CRUD endpoints for project-scoped task templates.
////
//// ## Responsibilities
////
//// - Validate HTTP requests and JSON payloads
//// - Authorize project managers
//// - Serialize template data for responses
////
//// ## Non-responsibilities
////
//// - Template persistence (see `services/task_templates_db.gleam`)
//// - Project authorization rules (see `services/projects_db.gleam`)
////
//// ## Relationships
////
//// - Delegates DB work to `services/task_templates_db.gleam`
//// - Uses `http/auth.gleam` for session identity
//// - Uses `http/csrf.gleam` for mutation protection

import gleam/dynamic
import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/option.{type Option, None}
import helpers/json as json_helpers
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/authorization
import scrumbringer_server/http/csrf
import scrumbringer_server/services/projects_db
import scrumbringer_server/services/store_state.{type StoredUser}
import scrumbringer_server/services/task_templates_db
import wisp

// =============================================================================
// Context + Routing
// =============================================================================

/// Routes requests for project template collections (GET/POST).
///
/// Example:
///   handle_project_templates(req, ctx, project_id)
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

/// Routes requests for a single template (PATCH/DELETE).
///
/// Example:
///   handle_template(req, ctx, template_id)
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
    Ok(user) -> list_project_templates_for_user(ctx, user, project_id)
  }
}

fn handle_create_project(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: String,
) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")
    Ok(user) -> create_project_template_for_user(req, ctx, user, project_id)
  }
}

fn handle_update(
  req: wisp.Request,
  ctx: auth.Ctx,
  template_id: String,
) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")
    Ok(user) -> update_template_for_user(req, ctx, user, template_id)
  }
}

fn handle_delete(
  req: wisp.Request,
  ctx: auth.Ctx,
  template_id: String,
) -> wisp.Response {
  case auth.require_current_user(req, ctx) {
    Error(_) -> api.error(401, "AUTH_REQUIRED", "Authentication required")
    Ok(user) -> delete_template_for_user(req, ctx, user, template_id)
  }
}

// =============================================================================
// Flows
// =============================================================================

fn list_project_templates_for_user(
  ctx: auth.Ctx,
  user: StoredUser,
  project_id: String,
) -> wisp.Response {
  case parse_project_id(project_id) {
    Error(resp) -> resp
    Ok(project_id) -> list_project_templates(ctx, user, project_id)
  }
}

fn list_project_templates(
  ctx: auth.Ctx,
  user: StoredUser,
  project_id: Int,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case projects_db.is_project_manager(db, project_id, user.id) {
    Ok(True) -> list_project_templates_db(db, project_id)
    Ok(False) -> api.error(403, "FORBIDDEN", "Forbidden")
    Error(_) -> api.error(500, "INTERNAL", "Database error")
  }
}

fn list_project_templates_db(
  db: pog.Connection,
  project_id: Int,
) -> wisp.Response {
  case task_templates_db.list_project_templates(db, project_id) {
    Ok(templates) ->
      api.ok(
        json.object([
          #("templates", json.array(templates, of: template_json)),
        ]),
      )

    Error(_) -> api.error(500, "INTERNAL", "Database error")
  }
}

fn create_project_template_for_user(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  project_id: String,
) -> wisp.Response {
  case parse_project_id(project_id) {
    Error(resp) -> resp
    Ok(project_id) -> create_template_for_project(req, ctx, user, project_id)
  }
}

fn create_template_for_project(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  project_id: Int,
) -> wisp.Response {
  case ensure_project_manager(ctx, project_id, user.id) {
    Error(resp) -> resp
    Ok(Nil) -> create_template(req, ctx, user.org_id, project_id, user.id)
  }
}

fn update_template_for_user(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  template_id: String,
) -> wisp.Response {
  case parse_template_id(template_id) {
    Error(resp) -> resp
    Ok(template_id) -> update_template_for_id(req, ctx, user, template_id)
  }
}

// Justification: nested case improves clarity for branching logic.
fn update_template_for_id(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  template_id: Int,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case fetch_template(db, template_id) {
    Error(resp) -> resp

    Ok(template) ->
      // Justification: nested case enforces project-manager authorization.
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
  }
}

fn delete_template_for_user(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  template_id: String,
) -> wisp.Response {
  case parse_template_id(template_id) {
    Error(resp) -> resp
    Ok(template_id) -> delete_template_for_id(req, ctx, user, template_id)
  }
}

// Justification: nested case improves clarity for branching logic.
fn delete_template_for_id(
  req: wisp.Request,
  ctx: auth.Ctx,
  user: StoredUser,
  template_id: Int,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case fetch_template(db, template_id) {
    Error(resp) -> resp

    Ok(template) ->
      // Justification: nested case enforces project-manager authorization.
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
          delete_template(req, ctx, template_id, org_id)
      }
  }
}

fn ensure_project_manager(
  ctx: auth.Ctx,
  project_id: Int,
  user_id: Int,
) -> Result(Nil, wisp.Response) {
  let auth.Ctx(db: db, ..) = ctx

  case projects_db.is_project_manager(db, project_id, user_id) {
    Ok(True) -> Ok(Nil)
    Ok(False) -> Error(api.error(403, "FORBIDDEN", "Forbidden"))
    Error(_) -> Error(api.error(500, "INTERNAL", "Database error"))
  }
}

fn fetch_template(
  db: pog.Connection,
  template_id: Int,
) -> Result(task_templates_db.TaskTemplate, wisp.Response) {
  case task_templates_db.get_template(db, template_id) {
    Ok(template) -> Ok(template)
    Error(task_templates_db.UpdateNotFound) ->
      Error(api.error(404, "NOT_FOUND", "Not found"))
    Error(task_templates_db.UpdateDbError(_)) ->
      Error(api.error(500, "INTERNAL", "Database error"))
    Error(task_templates_db.UpdateInvalidTypeId) ->
      Error(api.error(422, "VALIDATION_ERROR", "Invalid type_id"))
  }
}

fn parse_project_id(value: String) -> Result(Int, wisp.Response) {
  case int.parse(value) {
    Ok(id) -> Ok(id)
    Error(_) -> Error(api.error(404, "NOT_FOUND", "Not found"))
  }
}

fn parse_template_id(value: String) -> Result(Int, wisp.Response) {
  case int.parse(value) {
    Ok(id) -> Ok(id)
    Error(_) -> Error(api.error(404, "NOT_FOUND", "Not found"))
  }
}

// =============================================================================
// Shared helpers
// =============================================================================

// Justification: nested case improves clarity for branching logic.
fn create_template(
  req: wisp.Request,
  ctx: auth.Ctx,
  org_id: Int,
  project_id: Int,
  user_id: Int,
) -> wisp.Response {
  case require_csrf(req) {
    Error(resp) -> resp

    Ok(Nil) -> {
      use data <- wisp.require_json(req)

      // Justification: nested case validates payload before persistence.
      case decode_create_payload(data) {
        Error(resp) -> resp

        Ok(#(name, description, type_id, priority)) ->
          create_template_db(
            ctx,
            org_id,
            project_id,
            name,
            description,
            type_id,
            priority,
            user_id,
          )
      }
    }
  }
}

fn create_template_db(
  ctx: auth.Ctx,
  org_id: Int,
  project_id: Int,
  name: String,
  description: String,
  type_id: Int,
  priority: Int,
  user_id: Int,
) -> wisp.Response {
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

// Justification: nested case improves clarity for branching logic.
fn update_template(
  req: wisp.Request,
  ctx: auth.Ctx,
  template_id: Int,
  org_id: Int,
  project_id: Int,
) -> wisp.Response {
  case require_csrf(req) {
    Error(resp) -> resp

    Ok(Nil) -> {
      use data <- wisp.require_json(req)

      // Justification: nested case validates payload before persistence.
      case decode_update_payload(data) {
        Error(resp) -> resp

        Ok(#(name, description, type_id, priority)) ->
          update_template_db(
            ctx,
            template_id,
            org_id,
            project_id,
            name,
            description,
            type_id,
            priority,
          )
      }
    }
  }
}

fn update_template_db(
  ctx: auth.Ctx,
  template_id: Int,
  org_id: Int,
  project_id: Int,
  name: Option(String),
  description: Option(String),
  type_id: Option(Int),
  priority: Option(Int),
) -> wisp.Response {
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

fn delete_template(
  req: wisp.Request,
  ctx: auth.Ctx,
  template_id: Int,
  org_id: Int,
) -> wisp.Response {
  case require_csrf(req) {
    Error(resp) -> resp

    Ok(Nil) -> delete_template_db(ctx, template_id, org_id)
  }
}

fn delete_template_db(
  ctx: auth.Ctx,
  template_id: Int,
  org_id: Int,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case task_templates_db.delete_template(db, template_id, org_id) {
    Ok(Nil) -> api.no_content()
    Error(task_templates_db.DeleteNotFound) ->
      api.error(404, "NOT_FOUND", "Not found")
    Error(task_templates_db.DeleteDbError(_)) ->
      api.error(500, "INTERNAL", "Database error")
  }
}

fn decode_create_payload(
  data: dynamic.Dynamic,
) -> Result(#(String, String, Int, Int), wisp.Response) {
  let decoder = {
    use name <- decode.field("name", decode.string)
    use description <- decode.optional_field("description", "", decode.string)
    use type_id <- decode.field("type_id", decode.int)
    use priority <- decode.optional_field("priority", 3, decode.int)
    decode.success(#(name, description, type_id, priority))
  }

  case decode.run(data, decoder) {
    Error(_) -> Error(api.error(400, "VALIDATION_ERROR", "Invalid JSON"))
    Ok(payload) -> Ok(payload)
  }
}

fn decode_update_payload(
  data: dynamic.Dynamic,
) -> Result(
  #(Option(String), Option(String), Option(Int), Option(Int)),
  wisp.Response,
) {
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
    use type_id <- decode.optional_field(
      "type_id",
      None,
      decode.optional(decode.int),
    )
    use priority <- decode.optional_field(
      "priority",
      None,
      decode.optional(decode.int),
    )
    decode.success(#(name, description, type_id, priority))
  }

  case decode.run(data, decoder) {
    Error(_) -> Error(api.error(400, "VALIDATION_ERROR", "Invalid JSON"))
    Ok(payload) -> Ok(payload)
  }
}

fn require_csrf(req: wisp.Request) -> Result(Nil, wisp.Response) {
  case csrf.require_double_submit(req) {
    Ok(Nil) -> Ok(Nil)
    Error(_) ->
      Error(api.error(403, "FORBIDDEN", "CSRF token missing or invalid"))
  }
}

/// Story 4.9 AC20: Added rules_count field.
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
    rules_count: rules_count,
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
    #("rules_count", json.int(rules_count)),
  ])
}
