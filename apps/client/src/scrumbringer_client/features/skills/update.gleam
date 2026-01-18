//// Skills feature update handlers for Scrumbringer client.
////
//// ## Mission
////
//// Handle member skill/capability selection and persistence.
////
//// ## Responsibilities
////
//// - Handle my capability IDs fetch responses
//// - Handle capability toggle events
//// - Handle save capabilities button clicks
//// - Handle save capabilities responses
////
//// ## Non-responsibilities
////
//// - API request construction (see `api/tasks.gleam`)
//// - View rendering (see `features/skills/view.gleam`)
////
//// ## Relations
////
//// - **client_state.gleam**: Provides Model, Msg types
//// - **client_update.gleam**: Delegates skills messages here
//// - **api/tasks.gleam**: Provides capability API functions

import gleam/dict
import gleam/option as opt

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError}
import scrumbringer_client/api/tasks as api_tasks
import scrumbringer_client/client_state.{
  type Model, type Msg, Failed, Loaded, MemberMyCapabilityIdsFetched,
  MemberMyCapabilityIdsSaved, Model,
}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/update_helpers

// =============================================================================
// Fetch Handlers
// =============================================================================

/// Handle successful my capability IDs fetch.
pub fn handle_my_capability_ids_fetched_ok(
  model: Model,
  ids: List(Int),
) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      member_my_capability_ids: Loaded(ids),
      member_my_capability_ids_edit: update_helpers.ids_to_bool_dict(ids),
    ),
    effect.none(),
  )
}

/// Handle failed my capability IDs fetch.
pub fn handle_my_capability_ids_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    _ -> #(
      Model(..model, member_my_capability_ids: Failed(err)),
      effect.none(),
    )
  }
}

// =============================================================================
// Toggle Handlers
// =============================================================================

/// Toggle a capability checkbox in the edit state.
pub fn handle_toggle_capability(
  model: Model,
  id: Int,
) -> #(Model, Effect(Msg)) {
  let next = case dict.get(model.member_my_capability_ids_edit, id) {
    Ok(v) -> !v
    Error(_) -> True
  }

  #(
    Model(
      ..model,
      member_my_capability_ids_edit: dict.insert(
        model.member_my_capability_ids_edit,
        id,
        next,
      ),
    ),
    effect.none(),
  )
}

// =============================================================================
// Save Handlers
// =============================================================================

/// Handle save capabilities button click.
pub fn handle_save_capabilities_clicked(model: Model) -> #(Model, Effect(Msg)) {
  case model.member_my_capabilities_in_flight {
    True -> #(model, effect.none())
    False -> {
      let ids =
        update_helpers.bool_dict_to_ids(model.member_my_capability_ids_edit)
      let model =
        Model(
          ..model,
          member_my_capabilities_in_flight: True,
          member_my_capabilities_error: opt.None,
        )
      #(model, api_tasks.put_me_capability_ids(ids, MemberMyCapabilityIdsSaved))
    }
  }
}

/// Handle successful save capabilities response.
pub fn handle_save_capabilities_ok(
  model: Model,
  ids: List(Int),
) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      member_my_capabilities_in_flight: False,
      member_my_capability_ids: Loaded(ids),
      member_my_capability_ids_edit: update_helpers.ids_to_bool_dict(ids),
      toast: opt.Some(update_helpers.i18n_t(model, i18n_text.SkillsSaved)),
    ),
    effect.none(),
  )
}

/// Handle failed save capabilities response.
pub fn handle_save_capabilities_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    _ -> #(
      Model(
        ..model,
        member_my_capabilities_in_flight: False,
        member_my_capabilities_error: opt.Some(err.message),
        toast: opt.Some(err.message),
      ),
      api_tasks.get_me_capability_ids(MemberMyCapabilityIdsFetched),
    )
  }
}
