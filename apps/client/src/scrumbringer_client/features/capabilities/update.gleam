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
import domain/remote.{Failed, Loaded}
import scrumbringer_client/client_state.{
  type Model, type Msg, admin_msg, update_admin,
}
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/admin/capabilities as admin_capabilities
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/helpers/auth as helpers_auth
import scrumbringer_client/helpers/i18n as helpers_i18n
import scrumbringer_client/helpers/toast as helpers_toast
import scrumbringer_client/i18n/text as i18n_text

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
          admin_msg(admin_messages.CapabilityMembersFetched(result))
        })
      })
      |> effect.batch
    opt.None -> effect.none()
  }

  #(
    update_admin(model, fn(admin) {
      update_capabilities(admin, fn(capabilities_state) {
        admin_capabilities.Model(
          ..capabilities_state,
          capabilities: Loaded(capabilities),
        )
      })
    }),
    preload_fx,
  )
}

/// Handle capabilities fetch error.
pub fn handle_capabilities_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  helpers_auth.handle_401_or(model, err, fn() {
    #(
      update_admin(model, fn(admin) {
        update_capabilities(admin, fn(capabilities_state) {
          admin_capabilities.Model(
            ..capabilities_state,
            capabilities: Failed(err),
          )
        })
      }),
      effect.none(),
    )
  })
}

// =============================================================================
// Capability Dialog Handlers
// =============================================================================

/// Handle capability create dialog open.
pub fn handle_capability_dialog_opened(model: Model) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      update_capabilities(admin, fn(capabilities_state) {
        admin_capabilities.Model(
          ..capabilities_state,
          capabilities_dialog_mode: dialog_mode.DialogCreate,
        )
      })
    }),
    effect.none(),
  )
}

/// Handle capability create dialog close.
pub fn handle_capability_dialog_closed(model: Model) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      update_capabilities(admin, fn(capabilities_state) {
        admin_capabilities.Model(
          ..capabilities_state,
          capabilities_dialog_mode: dialog_mode.DialogClosed,
          capabilities_create_name: "",
          capabilities_create_error: opt.None,
        )
      })
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
      update_capabilities(admin, fn(capabilities_state) {
        admin_capabilities.Model(
          ..capabilities_state,
          capabilities_create_name: name,
        )
      })
    }),
    effect.none(),
  )
}

// Justification: nested case improves clarity for branching logic.
/// Handle capability create form submission.
pub fn handle_capability_create_submitted(model: Model) -> #(Model, Effect(Msg)) {
  case model.admin.capabilities.capabilities_create_in_flight {
    True -> #(model, effect.none())
    False -> {
      let name = string.trim(model.admin.capabilities.capabilities_create_name)

      case name == "", model.core.selected_project_id {
        True, _ -> #(
          update_admin(model, fn(admin) {
            update_capabilities(admin, fn(capabilities_state) {
              admin_capabilities.Model(
                ..capabilities_state,
                capabilities_create_error: opt.Some(helpers_i18n.i18n_t(
                  model,
                  i18n_text.NameRequired,
                )),
              )
            })
          }),
          effect.none(),
        )
        _, opt.None -> #(model, effect.none())
        False, opt.Some(project_id) -> {
          let model =
            update_admin(model, fn(admin) {
              update_capabilities(admin, fn(capabilities_state) {
                admin_capabilities.Model(
                  ..capabilities_state,
                  capabilities_create_in_flight: True,
                  capabilities_create_error: opt.None,
                )
              })
            })
          #(
            model,
            api_org.create_project_capability(project_id, name, fn(result) {
              admin_msg(admin_messages.CapabilityCreated(result))
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
  let updated = case model.admin.capabilities.capabilities {
    Loaded(capabilities) -> [capability, ..capabilities]
    _ -> [capability]
  }

  let model =
    update_admin(model, fn(admin) {
      update_capabilities(admin, fn(capabilities_state) {
        admin_capabilities.Model(
          ..capabilities_state,
          capabilities: Loaded(updated),
          capabilities_dialog_mode: dialog_mode.DialogClosed,
          capabilities_create_in_flight: False,
          capabilities_create_name: "",
        )
      })
    })
  let toast_fx =
    helpers_toast.toast_success(helpers_i18n.i18n_t(
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
  helpers_auth.handle_401_or(model, err, fn() {
    case err.status {
      403 -> #(
        update_admin(model, fn(admin) {
          update_capabilities(admin, fn(capabilities_state) {
            admin_capabilities.Model(
              ..capabilities_state,
              capabilities_create_in_flight: False,
              capabilities_create_error: opt.Some(helpers_i18n.i18n_t(
                model,
                i18n_text.NotPermitted,
              )),
            )
          })
        }),
        helpers_toast.toast_warning(helpers_i18n.i18n_t(
          model,
          i18n_text.NotPermitted,
        )),
      )
      _ -> #(
        update_admin(model, fn(admin) {
          update_capabilities(admin, fn(capabilities_state) {
            admin_capabilities.Model(
              ..capabilities_state,
              capabilities_create_in_flight: False,
              capabilities_create_error: opt.Some(err.message),
            )
          })
        }),
        effect.none(),
      )
    }
  })
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
      update_capabilities(admin, fn(capabilities_state) {
        admin_capabilities.Model(
          ..capabilities_state,
          capabilities_dialog_mode: dialog_mode.DialogDelete,
          capability_delete_dialog_id: opt.Some(capability_id),
          capability_delete_in_flight: False,
          capability_delete_error: opt.None,
        )
      })
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
      update_capabilities(admin, fn(capabilities_state) {
        admin_capabilities.Model(
          ..capabilities_state,
          capabilities_dialog_mode: dialog_mode.DialogClosed,
          capability_delete_dialog_id: opt.None,
          capability_delete_in_flight: False,
          capability_delete_error: opt.None,
        )
      })
    }),
    effect.none(),
  )
}

/// Handle capability delete form submission.
pub fn handle_capability_delete_submitted(model: Model) -> #(Model, Effect(Msg)) {
  case
    model.admin.capabilities.capability_delete_in_flight,
    model.admin.capabilities.capability_delete_dialog_id,
    model.core.selected_project_id
  {
    True, _, _ -> #(model, effect.none())
    _, opt.None, _ -> #(model, effect.none())
    _, _, opt.None -> #(model, effect.none())
    False, opt.Some(capability_id), opt.Some(project_id) -> {
      let model =
        update_admin(model, fn(admin) {
          update_capabilities(admin, fn(capabilities_state) {
            admin_capabilities.Model(
              ..capabilities_state,
              capability_delete_in_flight: True,
              capability_delete_error: opt.None,
            )
          })
        })
      #(
        model,
        api_org.delete_project_capability(project_id, capability_id, fn(result) {
          admin_msg(admin_messages.CapabilityDeleted(result))
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
  let updated = case model.admin.capabilities.capabilities {
    Loaded(capabilities) ->
      Loaded(list.filter(capabilities, fn(c) { c.id != deleted_id }))
    other -> other
  }

  let model =
    update_admin(model, fn(admin) {
      update_capabilities(admin, fn(capabilities_state) {
        admin_capabilities.Model(
          ..capabilities_state,
          capabilities: updated,
          capabilities_dialog_mode: dialog_mode.DialogClosed,
          capability_delete_dialog_id: opt.None,
          capability_delete_in_flight: False,
          capability_delete_error: opt.None,
        )
      })
    })
  let toast_fx =
    helpers_toast.toast_success(helpers_i18n.i18n_t(
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
  helpers_auth.handle_401_or(model, err, fn() {
    case err.status {
      403 -> #(
        update_admin(model, fn(admin) {
          update_capabilities(admin, fn(capabilities_state) {
            admin_capabilities.Model(
              ..capabilities_state,
              capability_delete_in_flight: False,
              capability_delete_error: opt.Some(helpers_i18n.i18n_t(
                model,
                i18n_text.NotPermitted,
              )),
            )
          })
        }),
        effect.none(),
      )
      _ -> #(
        update_admin(model, fn(admin) {
          update_capabilities(admin, fn(capabilities_state) {
            admin_capabilities.Model(
              ..capabilities_state,
              capability_delete_in_flight: False,
              capability_delete_error: opt.Some(err.message),
            )
          })
        }),
        effect.none(),
      )
    }
  })
}

fn update_capabilities(
  admin: admin_state.AdminModel,
  f: fn(admin_capabilities.Model) -> admin_capabilities.Model,
) -> admin_state.AdminModel {
  admin_state.AdminModel(..admin, capabilities: f(admin.capabilities))
}
