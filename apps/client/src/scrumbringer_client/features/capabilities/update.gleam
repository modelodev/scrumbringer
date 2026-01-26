//// Capabilities feature update handlers.
////
//// ## Mission
////
//// Handles capability (skill) creation, deletion, and listing.
////
//// ## Responsibilities
////
//// - Capability create form state and submission
//// - Capability delete dialog and submission (Story 4.9 AC9)
//// - Capability fetch responses
////
//// ## Non-responsibilities
////
//// - API calls (see `api/org.gleam`)
//// - User capability assignment (see member pool handlers)
////
//// ## Relations
////
//// - **client_update.gleam**: Dispatches capability messages to handlers here
//// - **api/org.gleam**: Provides API effects for capability operations

import gleam/list
import gleam/option as opt
import gleam/string

import lustre/effect.{type Effect}

// API modules
import scrumbringer_client/api/org as api_org
import scrumbringer_client/api/projects as api_projects

// Domain types
import domain/api_error.{type ApiError}
import domain/capability.{type Capability}
import scrumbringer_client/client_state.{
  type Model, type Msg, AdminModel, CapabilityCreated, CapabilityMembersFetched,
  Failed, Loaded, admin_msg, update_admin,
}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/update_helpers

// =============================================================================
// Capabilities Fetch Handlers
// =============================================================================

/// Handle capabilities fetch success.
/// Also preloads member counts for each capability (AC16 optimization).
pub fn handle_capabilities_fetched_ok(
  model: Model,
  capabilities: List(Capability),
) -> #(Model, Effect(Msg)) {
  // Preload member counts for all capabilities
  let preload_fx = case model.core.selected_project_id {
    opt.Some(project_id) ->
      capabilities
      |> list.map(fn(c) {
        api_projects.get_capability_members(project_id, c.id, fn(result) {
          admin_msg(CapabilityMembersFetched(result))
        })
      })
      |> effect.batch
    opt.None -> effect.none()
  }

  #(
    update_admin(model, fn(admin) {
      AdminModel(..admin, capabilities: Loaded(capabilities))
    }),
    preload_fx,
  )
}

/// Handle capabilities fetch error.
pub fn handle_capabilities_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status == 401 {
    True -> update_helpers.reset_to_login(model)
    False -> #(
      update_admin(model, fn(admin) {
        AdminModel(..admin, capabilities: Failed(err))
      }),
      effect.none(),
    )
  }
}

// =============================================================================
// Capability Dialog Handlers
// =============================================================================

/// Handle capability create dialog open.
pub fn handle_capability_dialog_opened(model: Model) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      AdminModel(..admin, capabilities_create_dialog_open: True)
    }),
    effect.none(),
  )
}

/// Handle capability create dialog close.
pub fn handle_capability_dialog_closed(model: Model) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      AdminModel(
        ..admin,
        capabilities_create_dialog_open: False,
        capabilities_create_name: "",
        capabilities_create_error: opt.None,
      )
    }),
    effect.none(),
  )
}

// =============================================================================
// Capability Create Handlers
// =============================================================================

/// Handle capability create name input change.
pub fn handle_capability_create_name_changed(
  model: Model,
  name: String,
) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      AdminModel(..admin, capabilities_create_name: name)
    }),
    effect.none(),
  )
}

// Justification: nested case improves clarity for branching logic.
/// Handle capability create form submission.
pub fn handle_capability_create_submitted(model: Model) -> #(Model, Effect(Msg)) {
  case model.admin.capabilities_create_in_flight {
    True -> #(model, effect.none())
    False -> {
      let name = string.trim(model.admin.capabilities_create_name)

      case name == "", model.core.selected_project_id {
        True, _ -> #(
          update_admin(model, fn(admin) {
            AdminModel(
              ..admin,
              capabilities_create_error: opt.Some(update_helpers.i18n_t(
                model,
                i18n_text.NameRequired,
              )),
            )
          }),
          effect.none(),
        )
        _, opt.None -> #(model, effect.none())
        False, opt.Some(project_id) -> {
          let model =
            update_admin(model, fn(admin) {
              AdminModel(
                ..admin,
                capabilities_create_in_flight: True,
                capabilities_create_error: opt.None,
              )
            })
          #(
            model,
            api_org.create_project_capability(project_id, name, fn(result) {
              admin_msg(CapabilityCreated(result))
            }),
          )
        }
      }
    }
  }
}

/// Handle capability created success.
pub fn handle_capability_created_ok(
  model: Model,
  capability: Capability,
) -> #(Model, Effect(Msg)) {
  let updated = case model.admin.capabilities {
    Loaded(capabilities) -> [capability, ..capabilities]
    _ -> [capability]
  }

  let model =
    update_admin(model, fn(admin) {
      AdminModel(
        ..admin,
        capabilities: Loaded(updated),
        capabilities_create_dialog_open: False,
        capabilities_create_in_flight: False,
        capabilities_create_name: "",
      )
    })
  let toast_fx =
    update_helpers.toast_success(update_helpers.i18n_t(
      model,
      i18n_text.CapabilityCreated,
    ))
  #(model, toast_fx)
}

/// Handle capability created error.
pub fn handle_capability_created_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    403 -> #(
      update_admin(model, fn(admin) {
        AdminModel(
          ..admin,
          capabilities_create_in_flight: False,
          capabilities_create_error: opt.Some(update_helpers.i18n_t(
            model,
            i18n_text.NotPermitted,
          )),
        )
      }),
      update_helpers.toast_warning(update_helpers.i18n_t(
        model,
        i18n_text.NotPermitted,
      )),
    )
    _ -> #(
      update_admin(model, fn(admin) {
        AdminModel(
          ..admin,
          capabilities_create_in_flight: False,
          capabilities_create_error: opt.Some(err.message),
        )
      }),
      effect.none(),
    )
  }
}

// =============================================================================
// Capability Delete Handlers (Story 4.9 AC9)
// =============================================================================

/// Handle capability delete dialog open.
pub fn handle_capability_delete_dialog_opened(
  model: Model,
  capability_id: Int,
) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      AdminModel(
        ..admin,
        capability_delete_dialog_id: opt.Some(capability_id),
        capability_delete_in_flight: False,
        capability_delete_error: opt.None,
      )
    }),
    effect.none(),
  )
}

/// Handle capability delete dialog close.
pub fn handle_capability_delete_dialog_closed(
  model: Model,
) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      AdminModel(
        ..admin,
        capability_delete_dialog_id: opt.None,
        capability_delete_in_flight: False,
        capability_delete_error: opt.None,
      )
    }),
    effect.none(),
  )
}

/// Handle capability delete form submission.
pub fn handle_capability_delete_submitted(model: Model) -> #(Model, Effect(Msg)) {
  case
    model.admin.capability_delete_in_flight,
    model.admin.capability_delete_dialog_id,
    model.core.selected_project_id
  {
    True, _, _ -> #(model, effect.none())
    _, opt.None, _ -> #(model, effect.none())
    _, _, opt.None -> #(model, effect.none())
    False, opt.Some(capability_id), opt.Some(project_id) -> {
      let model =
        update_admin(model, fn(admin) {
          AdminModel(
            ..admin,
            capability_delete_in_flight: True,
            capability_delete_error: opt.None,
          )
        })
      #(
        model,
        api_org.delete_project_capability(project_id, capability_id, fn(result) {
          admin_msg(client_state.CapabilityDeleted(result))
        }),
      )
    }
  }
}

/// Handle capability deleted success.
pub fn handle_capability_deleted_ok(
  model: Model,
  deleted_id: Int,
) -> #(Model, Effect(Msg)) {
  let updated = case model.admin.capabilities {
    Loaded(capabilities) ->
      Loaded(list.filter(capabilities, fn(c) { c.id != deleted_id }))
    other -> other
  }

  let model =
    update_admin(model, fn(admin) {
      AdminModel(
        ..admin,
        capabilities: updated,
        capability_delete_dialog_id: opt.None,
        capability_delete_in_flight: False,
        capability_delete_error: opt.None,
      )
    })
  let toast_fx =
    update_helpers.toast_success(update_helpers.i18n_t(
      model,
      i18n_text.CapabilityDeleted,
    ))
  #(model, toast_fx)
}

/// Handle capability deleted error.
pub fn handle_capability_deleted_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    403 -> #(
      update_admin(model, fn(admin) {
        AdminModel(
          ..admin,
          capability_delete_in_flight: False,
          capability_delete_error: opt.Some(update_helpers.i18n_t(
            model,
            i18n_text.NotPermitted,
          )),
        )
      }),
      effect.none(),
    )
    _ -> #(
      update_admin(model, fn(admin) {
        AdminModel(
          ..admin,
          capability_delete_in_flight: False,
          capability_delete_error: opt.Some(err.message),
        )
      }),
      effect.none(),
    )
  }
}
