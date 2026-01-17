//// Capabilities workflow handlers.
////
//// ## Mission
////
//// Handles capability (skill) creation and listing.
////
//// ## Responsibilities
////
//// - Capability create form state and submission
//// - Capability fetch responses
////
//// ## Non-responsibilities
////
//// - API calls (see `api.gleam`)
//// - User capability assignment (see member pool handlers)

import gleam/option as opt
import gleam/string

import lustre/effect.{type Effect}

import scrumbringer_client/api
import scrumbringer_client/client_state.{
  type Model, type Msg, CapabilityCreated, Failed, Loaded, Model,
}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/update_helpers

// =============================================================================
// Capabilities Fetch Handlers
// =============================================================================

/// Handle capabilities fetch success.
pub fn handle_capabilities_fetched_ok(
  model: Model,
  capabilities: List(api.Capability),
) -> #(Model, Effect(Msg)) {
  #(Model(..model, capabilities: Loaded(capabilities)), effect.none())
}

/// Handle capabilities fetch error.
pub fn handle_capabilities_fetched_error(
  model: Model,
  err: api.ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status == 401 {
    True -> update_helpers.reset_to_login(model)
    False -> #(Model(..model, capabilities: Failed(err)), effect.none())
  }
}

// =============================================================================
// Capability Create Handlers
// =============================================================================

/// Handle capability create name input change.
pub fn handle_capability_create_name_changed(
  model: Model,
  name: String,
) -> #(Model, Effect(Msg)) {
  #(Model(..model, capabilities_create_name: name), effect.none())
}

/// Handle capability create form submission.
pub fn handle_capability_create_submitted(model: Model) -> #(Model, Effect(Msg)) {
  case model.capabilities_create_in_flight {
    True -> #(model, effect.none())
    False -> {
      let name = string.trim(model.capabilities_create_name)

      case name == "" {
        True -> #(
          Model(
            ..model,
            capabilities_create_error: opt.Some(update_helpers.i18n_t(
              model,
              i18n_text.NameRequired,
            )),
          ),
          effect.none(),
        )
        False -> {
          let model =
            Model(
              ..model,
              capabilities_create_in_flight: True,
              capabilities_create_error: opt.None,
            )
          #(model, api.create_capability(name, CapabilityCreated))
        }
      }
    }
  }
}

/// Handle capability created success.
pub fn handle_capability_created_ok(
  model: Model,
  capability: api.Capability,
) -> #(Model, Effect(Msg)) {
  let updated = case model.capabilities {
    Loaded(capabilities) -> [capability, ..capabilities]
    _ -> [capability]
  }

  #(
    Model(
      ..model,
      capabilities: Loaded(updated),
      capabilities_create_in_flight: False,
      capabilities_create_name: "",
      toast: opt.Some(update_helpers.i18n_t(
        model,
        i18n_text.CapabilityCreated,
      )),
    ),
    effect.none(),
  )
}

/// Handle capability created error.
pub fn handle_capability_created_error(
  model: Model,
  err: api.ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    403 -> #(
      Model(
        ..model,
        capabilities_create_in_flight: False,
        capabilities_create_error: opt.Some(update_helpers.i18n_t(
          model,
          i18n_text.NotPermitted,
        )),
        toast: opt.Some(update_helpers.i18n_t(model, i18n_text.NotPermitted)),
      ),
      effect.none(),
    )
    _ -> #(
      Model(
        ..model,
        capabilities_create_in_flight: False,
        capabilities_create_error: opt.Some(err.message),
      ),
      effect.none(),
    )
  }
}
