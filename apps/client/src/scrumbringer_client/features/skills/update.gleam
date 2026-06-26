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
//// - API request construction (see `api/member_capabilities.gleam`)
//// - Capability selection state used by pool/capability flows
////
//// ## Relations
////
//// - **features/pool/update.gleam**: Applies local transitions to the root model
//// - **api/member_capabilities.gleam**: Provides capability API functions

import gleam/dict
import gleam/option as opt

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError, type ApiResult}
import domain/capability.{type Capability}
import domain/remote.{Failed, Loaded}
import scrumbringer_client/api/member_capabilities as capabilities_api
import scrumbringer_client/client_state/member/skills as member_skills
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/helpers/dicts as helpers_dicts

pub type Context(parent_msg) {
  Context(
    selected_project_id: opt.Option(Int),
    user_id: opt.Option(Int),
    on_my_capability_ids_fetched: fn(ApiResult(List(Int))) -> parent_msg,
    on_my_capability_ids_saved: fn(ApiResult(List(Int))) -> parent_msg,
    skills_saved: String,
    on_success_toast: fn(String) -> Effect(parent_msg),
    on_error_toast: fn(String) -> Effect(parent_msg),
  )
}

pub type AuthPolicy {
  NoAuthCheck
  CheckAuth(ApiError)
}

pub type Update(parent_msg) {
  Update(member_skills.Model, Effect(parent_msg), AuthPolicy)
}

pub fn try_update(
  model: member_skills.Model,
  inner: pool_messages.Msg,
  context: Context(parent_msg),
) -> opt.Option(Update(parent_msg)) {
  case inner {
    pool_messages.MemberMyCapabilityIdsFetched(Ok(ids)) -> {
      let #(next, fx) = handle_my_capability_ids_fetched_ok(model, ids)
      opt.Some(Update(next, fx, NoAuthCheck))
    }
    pool_messages.MemberMyCapabilityIdsFetched(Error(err)) -> {
      let #(next, fx) = handle_my_capability_ids_fetched_error(model, err)
      opt.Some(Update(next, fx, CheckAuth(err)))
    }
    pool_messages.MemberProjectCapabilitiesFetched(Ok(capabilities)) -> {
      let #(next, fx) =
        handle_project_capabilities_fetched_ok(model, capabilities)
      opt.Some(Update(next, fx, NoAuthCheck))
    }
    pool_messages.MemberProjectCapabilitiesFetched(Error(err)) -> {
      let #(next, fx) = handle_project_capabilities_fetched_error(model, err)
      opt.Some(Update(next, fx, NoAuthCheck))
    }
    pool_messages.MemberToggleCapability(id) -> {
      let #(next, fx) = handle_toggle_capability(model, id)
      opt.Some(Update(next, fx, NoAuthCheck))
    }
    pool_messages.MemberSaveCapabilitiesClicked -> {
      let #(next, fx) = handle_save_capabilities_clicked(model, context)
      opt.Some(Update(next, fx, NoAuthCheck))
    }
    pool_messages.MemberMyCapabilityIdsSaved(Ok(ids)) -> {
      let #(next, fx) = handle_save_capabilities_ok(model, ids, context)
      opt.Some(Update(next, fx, NoAuthCheck))
    }
    pool_messages.MemberMyCapabilityIdsSaved(Error(err)) -> {
      let #(next, fx) = handle_save_capabilities_error(model, err, context)
      opt.Some(Update(next, fx, CheckAuth(err)))
    }
    _ -> opt.None
  }
}

// =============================================================================
// Fetch Handlers
// =============================================================================

/// Handle successful my capability IDs fetch.
fn handle_my_capability_ids_fetched_ok(
  model: member_skills.Model,
  ids: List(Int),
) -> #(member_skills.Model, Effect(parent_msg)) {
  #(
    member_skills.Model(
      ..model,
      member_my_capability_ids: Loaded(ids),
      member_my_capability_ids_edit: helpers_dicts.ids_to_bool_dict(ids),
    ),
    effect.none(),
  )
}

/// Handle failed my capability IDs fetch.
fn handle_my_capability_ids_fetched_error(
  model: member_skills.Model,
  err: ApiError,
) -> #(member_skills.Model, Effect(parent_msg)) {
  #(
    member_skills.Model(..model, member_my_capability_ids: Failed(err)),
    effect.none(),
  )
}

/// Handle successful project capabilities fetch.
fn handle_project_capabilities_fetched_ok(
  model: member_skills.Model,
  capabilities: List(Capability),
) -> #(member_skills.Model, Effect(parent_msg)) {
  #(
    member_skills.Model(..model, member_capabilities: Loaded(capabilities)),
    effect.none(),
  )
}

/// Handle failed project capabilities fetch.
fn handle_project_capabilities_fetched_error(
  model: member_skills.Model,
  err: ApiError,
) -> #(member_skills.Model, Effect(parent_msg)) {
  #(
    member_skills.Model(..model, member_capabilities: Failed(err)),
    effect.none(),
  )
}

// =============================================================================
// Toggle Handlers
// =============================================================================

/// Toggle a capability checkbox in the edit state.
fn handle_toggle_capability(
  model: member_skills.Model,
  id: Int,
) -> #(member_skills.Model, Effect(parent_msg)) {
  let next = case dict.get(model.member_my_capability_ids_edit, id) {
    Ok(v) -> !v
    Error(_) -> True
  }

  #(
    member_skills.Model(
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
fn handle_save_capabilities_clicked(
  model: member_skills.Model,
  context: Context(parent_msg),
) -> #(member_skills.Model, Effect(parent_msg)) {
  case
    model.member_my_capabilities_in_flight,
    context.selected_project_id,
    context.user_id
  {
    True, _, _ -> #(model, effect.none())
    _, opt.None, _ -> #(model, effect.none())
    _, _, opt.None -> #(model, effect.none())
    False, opt.Some(project_id), opt.Some(user_id) -> {
      let ids =
        helpers_dicts.bool_dict_to_ids(model.member_my_capability_ids_edit)
      let model =
        member_skills.Model(
          ..model,
          member_my_capabilities_in_flight: True,
          member_my_capabilities_error: opt.None,
        )
      #(
        model,
        capabilities_api.put_member_capability_ids(
          project_id,
          user_id,
          ids,
          context.on_my_capability_ids_saved,
        ),
      )
    }
  }
}

/// Handle successful save capabilities response.
fn handle_save_capabilities_ok(
  model: member_skills.Model,
  ids: List(Int),
  context: Context(parent_msg),
) -> #(member_skills.Model, Effect(parent_msg)) {
  let model =
    member_skills.Model(
      ..model,
      member_my_capabilities_in_flight: False,
      member_my_capability_ids: Loaded(ids),
      member_my_capability_ids_edit: helpers_dicts.ids_to_bool_dict(ids),
    )
  #(model, context.on_success_toast(context.skills_saved))
}

/// Handle failed save capabilities response.
fn handle_save_capabilities_error(
  model: member_skills.Model,
  err: ApiError,
  context: Context(parent_msg),
) -> #(member_skills.Model, Effect(parent_msg)) {
  #(
    member_skills.Model(
      ..model,
      member_my_capabilities_in_flight: False,
      member_my_capabilities_error: opt.Some(err.message),
    ),
    effect.batch([
      refetch_member_capability_ids_effect(context),
      context.on_error_toast(err.message),
    ]),
  )
}

fn refetch_member_capability_ids_effect(
  context: Context(parent_msg),
) -> Effect(parent_msg) {
  case context.selected_project_id, context.user_id {
    opt.Some(project_id), opt.Some(user_id) ->
      capabilities_api.get_member_capability_ids(
        project_id,
        user_id,
        context.on_my_capability_ids_fetched,
      )
    _, _ -> effect.none()
  }
}
