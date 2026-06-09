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

import gleam/http
import gleam/list
import gleam/result
import pog
import scrumbringer_server/http/api
import scrumbringer_server/http/auth
import scrumbringer_server/http/capabilities/payloads as capability_payloads
import scrumbringer_server/http/capabilities/presenters as capability_presenters
import scrumbringer_server/http/csrf
import scrumbringer_server/http/json_payload
import scrumbringer_server/services/authorization
import scrumbringer_server/services/capabilities_db
import scrumbringer_server/services/projects_db
import scrumbringer_server/services/store_state.{type StoredUser}
import wisp

type SelectionValidationError {
  InvalidSelection
  SelectionDatabaseError
}

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

fn require_member_context(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: Int,
) -> Result(#(pog.Connection, StoredUser), wisp.Response) {
  use user <- result.try(auth.require_current_user_response(req, ctx))
  let auth.Ctx(db: db, ..) = ctx
  use _ <- result.try(require_project_member(db, project_id, user.id))
  Ok(#(db, user))
}

fn require_manager_context(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: Int,
) -> Result(#(pog.Connection, StoredUser), wisp.Response) {
  use user <- result.try(auth.require_current_user_response(req, ctx))
  let auth.Ctx(db: db, ..) = ctx
  use _ <- result.try(authorization.require_project_manager_with_org_bypass(
    db,
    user,
    project_id,
  ))
  Ok(#(db, user))
}

fn require_project_member(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
) -> Result(Nil, wisp.Response) {
  case projects_db.is_project_member(db, project_id, user_id) {
    Ok(True) -> Ok(Nil)
    Ok(False) ->
      Error(api.error(403, "FORBIDDEN", "Not a member of this project"))
    Error(_) -> Error(api.error(500, "INTERNAL", "Database error"))
  }
}

fn handle_list(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: Int,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case require_member_context(req, ctx, project_id) {
    Error(resp) -> resp
    Ok(#(db, _user)) -> list_capabilities_for_project(db, project_id)
  }
}

fn list_capabilities_for_project(
  db: pog.Connection,
  project_id: Int,
) -> wisp.Response {
  case capabilities_db.list_capabilities_for_project(db, project_id) {
    Ok(capabilities) ->
      api.ok(capability_presenters.capabilities_response(capabilities))

    Error(_) -> api.error(500, "INTERNAL", "Database error")
  }
}

fn handle_create(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: Int,
) -> wisp.Response {
  case require_manager_context(req, ctx, project_id) {
    Error(resp) -> resp
    Ok(_) -> create_capability(req, ctx, project_id)
  }
}

/// Story 4.9 AC9: Delete a capability (manager only).
fn handle_delete(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: Int,
  capability_id: Int,
) -> wisp.Response {
  case require_manager_context(req, ctx, project_id) {
    Error(resp) -> resp
    Ok(_) -> delete_capability(req, ctx, project_id, capability_id)
  }
}

fn delete_capability(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: Int,
  capability_id: Int,
) -> wisp.Response {
  case csrf.require_csrf(req) {
    Error(resp) -> resp
    Ok(Nil) -> delete_capability_from_project(ctx, project_id, capability_id)
  }
}

fn delete_capability_from_project(
  ctx: auth.Ctx,
  project_id: Int,
  capability_id: Int,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case capabilities_db.delete_capability(db, project_id, capability_id) {
    Ok(True) -> api.ok(capability_presenters.deleted_response(capability_id))
    Ok(False) -> api.error(404, "NOT_FOUND", "Capability not found")
    Error(_) -> api.error(500, "INTERNAL", "Database error")
  }
}

fn create_capability(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: Int,
) -> wisp.Response {
  json_payload.with_csrf(req, capability_payloads.decode_create, fn(payload) {
    create_capability_in_project(ctx, project_id, payload.name)
  })
}

fn create_capability_in_project(
  ctx: auth.Ctx,
  project_id: Int,
  name: String,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case capabilities_db.create_capability(db, project_id, name) {
    Ok(capability) ->
      api.ok(capability_presenters.capability_response(capability))

    Error(capabilities_db.AlreadyExists) ->
      api.error(422, "VALIDATION_ERROR", "Capability name already exists")

    Error(_) -> api.error(500, "INTERNAL", "Database error")
  }
}

fn handle_get_member_capabilities(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: Int,
  user_id: Int,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case require_member_context(req, ctx, project_id) {
    Error(resp) -> resp
    Ok(#(db, _user)) -> list_member_capabilities(db, project_id, user_id)
  }
}

fn list_member_capabilities(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
) -> wisp.Response {
  case capabilities_db.list_member_capabilities(db, project_id, user_id) {
    Ok(capabilities) -> {
      let ids = list.map(capabilities, fn(c) { c.capability_id })
      api.ok(capability_presenters.capability_ids_response(ids))
    }
    Error(_) -> api.error(500, "INTERNAL", "Database error")
  }
}

fn handle_put_member_capabilities(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: Int,
  target_user_id: Int,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Put)

  case auth.require_current_user_response(req, ctx) {
    Error(resp) -> resp
    Ok(user) ->
      update_member_capabilities_with_auth(
        req,
        ctx,
        project_id,
        target_user_id,
        user.id,
      )
  }
}

fn update_member_capabilities_with_auth(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: Int,
  target_user_id: Int,
  acting_user_id: Int,
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  let can_update = case acting_user_id == target_user_id {
    True -> projects_db.is_project_member(db, project_id, acting_user_id)
    False -> projects_db.is_project_manager(db, project_id, acting_user_id)
  }

  case can_update {
    Ok(True) -> update_member_capabilities(req, ctx, project_id, target_user_id)
    Ok(False) -> api.error(403, "FORBIDDEN", "Not authorized")
    Error(_) -> api.error(500, "INTERNAL", "Database error")
  }
}

fn update_member_capabilities(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: Int,
  user_id: Int,
) -> wisp.Response {
  json_payload.with_csrf(
    req,
    capability_payloads.decode_capability_ids,
    fn(payload) {
      update_member_capabilities_with_ids(
        ctx,
        project_id,
        user_id,
        payload.capability_ids,
      )
    },
  )
}

fn update_member_capabilities_with_ids(
  ctx: auth.Ctx,
  project_id: Int,
  user_id: Int,
  new_ids: List(Int),
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case validate_capability_ids(db, project_id, new_ids) {
    Error(response) -> response
    Ok(_) -> replace_member_capabilities(db, project_id, user_id, new_ids)
  }
}

fn validate_capability_ids(
  db: pog.Connection,
  project_id: Int,
  ids: List(Int),
) -> Result(Nil, wisp.Response) {
  let validation_result =
    list.try_map(ids, fn(cap_id) {
      case capabilities_db.capability_is_in_project(db, cap_id, project_id) {
        Ok(True) -> Ok(cap_id)
        Ok(False) -> Error(InvalidSelection)
        Error(_) -> Error(SelectionDatabaseError)
      }
    })

  case validation_result {
    Error(InvalidSelection) ->
      Error(api.error(422, "VALIDATION_ERROR", "Invalid capability_id"))
    Error(SelectionDatabaseError) ->
      Error(api.error(500, "INTERNAL", "Database error"))
    Ok(_) -> Ok(Nil)
  }
}

fn replace_member_capabilities(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
  new_ids: List(Int),
) -> wisp.Response {
  case capabilities_db.remove_all_member_capabilities(db, project_id, user_id) {
    Error(_) -> api.error(500, "INTERNAL", "Database error")
    Ok(Nil) -> add_member_capabilities(db, project_id, user_id, new_ids)
  }
}

fn add_member_capabilities(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
  new_ids: List(Int),
) -> wisp.Response {
  let add_result =
    list.try_map(new_ids, fn(cap_id) {
      capabilities_db.add_member_capability(db, project_id, user_id, cap_id)
    })

  case add_result {
    Ok(_) -> api.ok(capability_presenters.capability_ids_response(new_ids))
    Error(_) -> api.error(500, "INTERNAL", "Database error")
  }
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
    http.Get ->
      handle_get_capability_members(req, ctx, project_id, capability_id)
    http.Put ->
      handle_put_capability_members(req, ctx, project_id, capability_id)
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

  case require_member_context(req, ctx, project_id) {
    Error(resp) -> resp
    Ok(#(db, _user)) -> list_capability_members(db, project_id, capability_id)
  }
}

fn list_capability_members(
  db: pog.Connection,
  project_id: Int,
  capability_id: Int,
) -> wisp.Response {
  case capabilities_db.list_capability_members(db, project_id, capability_id) {
    Ok(members) -> {
      let ids = list.map(members, fn(m) { m.user_id })
      api.ok(capability_presenters.user_ids_response(ids))
    }
    Error(_) -> api.error(500, "INTERNAL", "Database error")
  }
}

fn handle_put_capability_members(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: Int,
  capability_id: Int,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Put)

  case require_manager_context(req, ctx, project_id) {
    Error(resp) -> resp
    Ok(_) -> update_capability_members(req, ctx, project_id, capability_id)
  }
}

fn update_capability_members(
  req: wisp.Request,
  ctx: auth.Ctx,
  project_id: Int,
  capability_id: Int,
) -> wisp.Response {
  json_payload.with_csrf(req, capability_payloads.decode_user_ids, fn(payload) {
    update_capability_members_with_ids(
      ctx,
      project_id,
      capability_id,
      payload.user_ids,
    )
  })
}

fn update_capability_members_with_ids(
  ctx: auth.Ctx,
  project_id: Int,
  capability_id: Int,
  new_ids: List(Int),
) -> wisp.Response {
  let auth.Ctx(db: db, ..) = ctx

  case validate_member_ids(db, project_id, new_ids) {
    Error(response) -> response
    Ok(_) -> replace_capability_members(db, project_id, capability_id, new_ids)
  }
}

fn validate_member_ids(
  db: pog.Connection,
  project_id: Int,
  user_ids: List(Int),
) -> Result(Nil, wisp.Response) {
  let validation_result =
    list.try_map(user_ids, fn(user_id) {
      case projects_db.is_project_member(db, project_id, user_id) {
        Ok(True) -> Ok(user_id)
        Ok(False) -> Error(InvalidSelection)
        Error(_) -> Error(SelectionDatabaseError)
      }
    })

  case validation_result {
    Error(InvalidSelection) ->
      Error(api.error(
        422,
        "VALIDATION_ERROR",
        "Invalid user_id (not a project member)",
      ))
    Error(SelectionDatabaseError) ->
      Error(api.error(500, "INTERNAL", "Database error"))
    Ok(_) -> Ok(Nil)
  }
}

fn replace_capability_members(
  db: pog.Connection,
  project_id: Int,
  capability_id: Int,
  new_ids: List(Int),
) -> wisp.Response {
  case
    capabilities_db.remove_all_capability_members(db, project_id, capability_id)
  {
    Error(_) -> api.error(500, "INTERNAL", "Database error")
    Ok(Nil) -> add_capability_members(db, project_id, capability_id, new_ids)
  }
}

fn add_capability_members(
  db: pog.Connection,
  project_id: Int,
  capability_id: Int,
  new_ids: List(Int),
) -> wisp.Response {
  let add_result =
    list.try_map(new_ids, fn(user_id) {
      capabilities_db.add_member_capability(
        db,
        project_id,
        user_id,
        capability_id,
      )
    })

  case add_result {
    Ok(_) -> api.ok(capability_presenters.user_ids_response(new_ids))
    Error(_) -> api.error(500, "INTERNAL", "Database error")
  }
}
