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

import gleam/dict
import gleam/list
import gleam/option as opt
import gleam/string

import lustre/effect.{type Effect}

// API modules
import scrumbringer_client/api/org as api_org
import scrumbringer_client/api/projects as api_projects

// Domain types
import domain/api_error.{type ApiError, type ApiResult}
import domain/capability.{type Capability}
import domain/remote.{Failed, Loaded}
import scrumbringer_client/client_state/admin/capabilities as admin_capabilities
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/features/admin/msg as admin_messages

pub type Context(parent_msg) {
  Context(
    selected_project_id: opt.Option(Int),
    on_member_capabilities_fetched: fn(
      ApiResult(api_projects.MemberCapabilities),
    ) ->
      parent_msg,
    on_member_capabilities_saved: fn(ApiResult(api_projects.MemberCapabilities)) ->
      parent_msg,
    on_capability_members_fetched: fn(ApiResult(api_projects.CapabilityMembers)) ->
      parent_msg,
    on_capability_members_saved: fn(ApiResult(api_projects.CapabilityMembers)) ->
      parent_msg,
    on_capability_created: fn(ApiResult(Capability)) -> parent_msg,
    on_capability_deleted: fn(ApiResult(Int)) -> parent_msg,
    name_required: String,
  )
}

pub type Success {
  CapabilityCreated
  CapabilityDeleted
  MemberCapabilitiesSaved
  CapabilityMembersSaved
}

pub type FeedbackContext(parent_msg) {
  FeedbackContext(
    capability_created: String,
    capability_deleted: String,
    member_capabilities_saved: String,
    capability_members_saved: String,
    on_success_toast: fn(String) -> Effect(parent_msg),
  )
}

pub type ErrorFeedbackContext(parent_msg) {
  ErrorFeedbackContext(
    not_permitted: String,
    on_warning_toast: fn(String) -> Effect(parent_msg),
  )
}

pub type AuthPolicy {
  NoAuthCheck
  CheckAuth(ApiError)
}

pub type Update(parent_msg) {
  Update(admin_capabilities.Model, Effect(parent_msg), AuthPolicy)
}

pub fn try_update(
  model: admin_capabilities.Model,
  inner: admin_messages.Msg,
  context: Context(parent_msg),
  feedback: FeedbackContext(parent_msg),
  error_feedback: ErrorFeedbackContext(parent_msg),
) -> opt.Option(Update(parent_msg)) {
  case inner {
    admin_messages.CapabilitiesFetched(Ok(capabilities)) ->
      handle_capabilities_fetched_ok(model, capabilities, context)
      |> without_auth_check

    admin_messages.CapabilitiesFetched(Error(err)) ->
      handle_capabilities_fetched_error(model, err)
      |> with_auth_check(err)

    admin_messages.CapabilityCreateDialogOpened ->
      handle_capability_dialog_opened(model)
      |> without_auth_check

    admin_messages.CapabilityCreateDialogClosed ->
      handle_capability_dialog_closed(model)
      |> without_auth_check

    admin_messages.CapabilityCreateNameChanged(name) ->
      handle_capability_create_name_changed(model, name)
      |> without_auth_check

    admin_messages.CapabilityCreateSubmitted ->
      handle_capability_create_submitted(model, context)
      |> without_auth_check

    admin_messages.CapabilityCreated(Ok(capability)) ->
      handle_capability_created_ok(model, capability, feedback)
      |> without_auth_check

    admin_messages.CapabilityCreated(Error(err)) ->
      handle_capability_created_error(
        model,
        permission_error_message(err, error_feedback),
      )
      |> with_auth_check_and_effect(
        err,
        permission_warning_effect(err, error_feedback),
      )

    admin_messages.CapabilityDeleteDialogOpened(capability_id) ->
      handle_capability_delete_dialog_opened(model, capability_id)
      |> without_auth_check

    admin_messages.CapabilityDeleteDialogClosed ->
      handle_capability_delete_dialog_closed(model)
      |> without_auth_check

    admin_messages.CapabilityDeleteSubmitted ->
      handle_capability_delete_submitted(model, context)
      |> without_auth_check

    admin_messages.CapabilityDeleted(Ok(deleted_id)) ->
      handle_capability_deleted_ok(model, deleted_id, feedback)
      |> without_auth_check

    admin_messages.CapabilityDeleted(Error(err)) ->
      handle_capability_deleted_error(
        model,
        permission_error_message(err, error_feedback),
      )
      |> with_auth_check(err)

    admin_messages.MemberCapabilitiesDialogOpened(user_id) ->
      handle_member_capabilities_dialog_opened(model, user_id, context)
      |> without_auth_check

    admin_messages.MemberCapabilitiesDialogClosed ->
      handle_member_capabilities_dialog_closed(model)
      |> without_auth_check

    admin_messages.MemberCapabilitiesToggled(capability_id) ->
      handle_member_capabilities_toggled(model, capability_id)
      |> without_auth_check

    admin_messages.MemberCapabilitiesSaveClicked ->
      handle_member_capabilities_save_clicked(model, context)
      |> without_auth_check

    admin_messages.MemberCapabilitiesFetched(Ok(result)) ->
      handle_member_capabilities_fetched_ok(model, result)
      |> without_auth_check

    admin_messages.MemberCapabilitiesFetched(Error(err)) ->
      handle_member_capabilities_fetched_error(model, err.message)
      |> with_auth_check(err)

    admin_messages.MemberCapabilitiesSaved(Ok(result)) ->
      handle_member_capabilities_saved_ok(model, result, feedback)
      |> without_auth_check

    admin_messages.MemberCapabilitiesSaved(Error(err)) ->
      handle_member_capabilities_saved_error(model, err.message)
      |> with_auth_check(err)

    admin_messages.CapabilityMembersDialogOpened(capability_id) ->
      handle_capability_members_dialog_opened(model, capability_id, context)
      |> without_auth_check

    admin_messages.CapabilityMembersDialogClosed ->
      handle_capability_members_dialog_closed(model)
      |> without_auth_check

    admin_messages.CapabilityMembersToggled(user_id) ->
      handle_capability_members_toggled(model, user_id)
      |> without_auth_check

    admin_messages.CapabilityMembersSaveClicked ->
      handle_capability_members_save_clicked(model, context)
      |> without_auth_check

    admin_messages.CapabilityMembersFetched(Ok(result)) ->
      handle_capability_members_fetched_ok(model, result)
      |> without_auth_check

    admin_messages.CapabilityMembersFetched(Error(err)) ->
      handle_capability_members_fetched_error(model, err.message)
      |> with_auth_check(err)

    admin_messages.CapabilityMembersSaved(Ok(result)) ->
      handle_capability_members_saved_ok(model, result, feedback)
      |> without_auth_check

    admin_messages.CapabilityMembersSaved(Error(err)) ->
      handle_capability_members_saved_error(model, err.message)
      |> with_auth_check(err)

    _ -> opt.None
  }
}

fn without_auth_check(
  result: #(admin_capabilities.Model, Effect(parent_msg)),
) -> opt.Option(Update(parent_msg)) {
  with_policy(result, NoAuthCheck)
}

fn with_auth_check(
  result: #(admin_capabilities.Model, Effect(parent_msg)),
  err: ApiError,
) -> opt.Option(Update(parent_msg)) {
  with_policy(result, CheckAuth(err))
}

fn with_auth_check_and_effect(
  result: #(admin_capabilities.Model, Effect(parent_msg)),
  err: ApiError,
  extra_fx: Effect(parent_msg),
) -> opt.Option(Update(parent_msg)) {
  let #(model, fx) = result
  opt.Some(Update(model, effect.batch([fx, extra_fx]), CheckAuth(err)))
}

fn with_policy(
  result: #(admin_capabilities.Model, Effect(parent_msg)),
  auth_policy: AuthPolicy,
) -> opt.Option(Update(parent_msg)) {
  let #(model, fx) = result
  opt.Some(Update(model, fx, auth_policy))
}

fn permission_error_message(
  err: ApiError,
  feedback: ErrorFeedbackContext(parent_msg),
) -> String {
  case err.status {
    403 -> feedback.not_permitted
    _ -> err.message
  }
}

fn permission_warning_effect(
  err: ApiError,
  feedback: ErrorFeedbackContext(parent_msg),
) -> Effect(parent_msg) {
  case err.status {
    403 -> feedback.on_warning_toast(feedback.not_permitted)
    _ -> effect.none()
  }
}

// =============================================================================
// Capabilities Fetch Handlers
// =============================================================================

/// Handle capabilities fetch success.
/// Also preloads member counts for each capability (AC16 optimization).
pub fn handle_capabilities_fetched_ok(
  model: admin_capabilities.Model,
  capabilities: List(Capability),
  context: Context(parent_msg),
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  // Preload member counts for all capabilities
  let preload_fx = case context.selected_project_id {
    opt.Some(project_id) ->
      capabilities
      |> list.map(fn(c) {
        api_projects.get_capability_members(
          project_id,
          c.id,
          context.on_capability_members_fetched,
        )
      })
      |> effect.batch
    opt.None -> effect.none()
  }

  #(
    admin_capabilities.Model(..model, capabilities: Loaded(capabilities)),
    preload_fx,
  )
}

/// Handle capabilities fetch error.
pub fn handle_capabilities_fetched_error(
  model: admin_capabilities.Model,
  err: ApiError,
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  #(admin_capabilities.Model(..model, capabilities: Failed(err)), effect.none())
}

// =============================================================================
// Member Capabilities Assignment Handlers
// =============================================================================

pub fn handle_member_capabilities_dialog_opened(
  model: admin_capabilities.Model,
  user_id: Int,
  context: Context(parent_msg),
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  case context.selected_project_id {
    opt.Some(project_id) -> {
      let selected = case dict.get(model.member_capabilities_cache, user_id) {
        Ok(ids) -> ids
        Error(_) -> []
      }

      #(
        admin_capabilities.Model(
          ..model,
          member_capabilities_dialog_user_id: opt.Some(user_id),
          member_capabilities_loading: True,
          member_capabilities_selected: selected,
          member_capabilities_error: opt.None,
        ),
        api_projects.get_member_capabilities(
          project_id,
          user_id,
          context.on_member_capabilities_fetched,
        ),
      )
    }

    opt.None -> #(model, effect.none())
  }
}

pub fn handle_member_capabilities_dialog_closed(
  model: admin_capabilities.Model,
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  #(
    admin_capabilities.Model(
      ..model,
      member_capabilities_dialog_user_id: opt.None,
      member_capabilities_selected: [],
      member_capabilities_error: opt.None,
    ),
    effect.none(),
  )
}

pub fn handle_member_capabilities_toggled(
  model: admin_capabilities.Model,
  capability_id: Int,
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  #(
    admin_capabilities.Model(
      ..model,
      member_capabilities_selected: toggle_id(
        model.member_capabilities_selected,
        capability_id,
      ),
    ),
    effect.none(),
  )
}

pub fn handle_member_capabilities_save_clicked(
  model: admin_capabilities.Model,
  context: Context(parent_msg),
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  case context.selected_project_id, model.member_capabilities_dialog_user_id {
    opt.Some(project_id), opt.Some(user_id) -> #(
      admin_capabilities.Model(..model, member_capabilities_saving: True),
      api_projects.set_member_capabilities(
        project_id,
        user_id,
        model.member_capabilities_selected,
        context.on_member_capabilities_saved,
      ),
    )

    _, _ -> #(model, effect.none())
  }
}

pub fn handle_member_capabilities_fetched_ok(
  model: admin_capabilities.Model,
  result: api_projects.MemberCapabilities,
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  #(
    admin_capabilities.Model(
      ..model,
      member_capabilities_loading: False,
      member_capabilities_cache: dict.insert(
        model.member_capabilities_cache,
        result.user_id,
        result.capability_ids,
      ),
      member_capabilities_selected: result.capability_ids,
    ),
    effect.none(),
  )
}

pub fn handle_member_capabilities_fetched_error(
  model: admin_capabilities.Model,
  message: String,
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  #(
    admin_capabilities.Model(
      ..model,
      member_capabilities_loading: False,
      member_capabilities_error: opt.Some(message),
    ),
    effect.none(),
  )
}

pub fn handle_member_capabilities_saved_ok(
  model: admin_capabilities.Model,
  result: api_projects.MemberCapabilities,
  feedback: FeedbackContext(parent_msg),
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  #(
    admin_capabilities.Model(
      ..model,
      member_capabilities_saving: False,
      member_capabilities_cache: dict.insert(
        model.member_capabilities_cache,
        result.user_id,
        result.capability_ids,
      ),
      member_capabilities_dialog_user_id: opt.None,
      member_capabilities_selected: [],
    ),
    success_effect(MemberCapabilitiesSaved, feedback),
  )
}

pub fn handle_member_capabilities_saved_error(
  model: admin_capabilities.Model,
  message: String,
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  #(
    admin_capabilities.Model(
      ..model,
      member_capabilities_saving: False,
      member_capabilities_error: opt.Some(message),
    ),
    effect.none(),
  )
}

// =============================================================================
// Capability Members Assignment Handlers
// =============================================================================

pub fn handle_capability_members_dialog_opened(
  model: admin_capabilities.Model,
  capability_id: Int,
  context: Context(parent_msg),
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  case context.selected_project_id {
    opt.Some(project_id) -> {
      let selected = case
        dict.get(model.capability_members_cache, capability_id)
      {
        Ok(ids) -> ids
        Error(_) -> []
      }

      #(
        admin_capabilities.Model(
          ..model,
          capability_members_dialog_capability_id: opt.Some(capability_id),
          capability_members_loading: True,
          capability_members_selected: selected,
          capability_members_error: opt.None,
        ),
        api_projects.get_capability_members(
          project_id,
          capability_id,
          context.on_capability_members_fetched,
        ),
      )
    }

    opt.None -> #(model, effect.none())
  }
}

pub fn handle_capability_members_dialog_closed(
  model: admin_capabilities.Model,
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  #(
    admin_capabilities.Model(
      ..model,
      capability_members_dialog_capability_id: opt.None,
      capability_members_selected: [],
      capability_members_error: opt.None,
    ),
    effect.none(),
  )
}

pub fn handle_capability_members_toggled(
  model: admin_capabilities.Model,
  user_id: Int,
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  #(
    admin_capabilities.Model(
      ..model,
      capability_members_selected: toggle_id(
        model.capability_members_selected,
        user_id,
      ),
    ),
    effect.none(),
  )
}

pub fn handle_capability_members_save_clicked(
  model: admin_capabilities.Model,
  context: Context(parent_msg),
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  case
    context.selected_project_id,
    model.capability_members_dialog_capability_id
  {
    opt.Some(project_id), opt.Some(capability_id) -> #(
      admin_capabilities.Model(..model, capability_members_saving: True),
      api_projects.set_capability_members(
        project_id,
        capability_id,
        model.capability_members_selected,
        context.on_capability_members_saved,
      ),
    )

    _, _ -> #(model, effect.none())
  }
}

pub fn handle_capability_members_fetched_ok(
  model: admin_capabilities.Model,
  result: api_projects.CapabilityMembers,
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  #(
    admin_capabilities.Model(
      ..model,
      capability_members_loading: False,
      capability_members_cache: dict.insert(
        model.capability_members_cache,
        result.capability_id,
        result.user_ids,
      ),
      capability_members_selected: result.user_ids,
    ),
    effect.none(),
  )
}

pub fn handle_capability_members_fetched_error(
  model: admin_capabilities.Model,
  message: String,
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  #(
    admin_capabilities.Model(
      ..model,
      capability_members_loading: False,
      capability_members_error: opt.Some(message),
    ),
    effect.none(),
  )
}

pub fn handle_capability_members_saved_ok(
  model: admin_capabilities.Model,
  result: api_projects.CapabilityMembers,
  feedback: FeedbackContext(parent_msg),
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  #(
    admin_capabilities.Model(
      ..model,
      capability_members_saving: False,
      capability_members_cache: dict.insert(
        model.capability_members_cache,
        result.capability_id,
        result.user_ids,
      ),
      capability_members_dialog_capability_id: opt.None,
      capability_members_selected: [],
    ),
    success_effect(CapabilityMembersSaved, feedback),
  )
}

pub fn handle_capability_members_saved_error(
  model: admin_capabilities.Model,
  message: String,
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  #(
    admin_capabilities.Model(
      ..model,
      capability_members_saving: False,
      capability_members_error: opt.Some(message),
    ),
    effect.none(),
  )
}

fn toggle_id(ids: List(Int), id: Int) -> List(Int) {
  case list.contains(ids, id) {
    True -> list.filter(ids, fn(existing) { existing != id })
    False -> [id, ..ids]
  }
}

// =============================================================================
// Capability Dialog Handlers
// =============================================================================

/// Handle capability create dialog open.
pub fn handle_capability_dialog_opened(
  model: admin_capabilities.Model,
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  #(
    admin_capabilities.Model(
      ..model,
      capabilities_dialog_mode: dialog_mode.DialogCreate,
    ),
    effect.none(),
  )
}

/// Handle capability create dialog close.
pub fn handle_capability_dialog_closed(
  model: admin_capabilities.Model,
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  #(
    admin_capabilities.Model(
      ..model,
      capabilities_dialog_mode: dialog_mode.DialogClosed,
      capabilities_create_name: "",
      capabilities_create_error: opt.None,
    ),
    effect.none(),
  )
}

// =============================================================================
// Capability Create Handlers
// =============================================================================

/// Handle capability create name input change.
pub fn handle_capability_create_name_changed(
  model: admin_capabilities.Model,
  name: String,
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  #(
    admin_capabilities.Model(..model, capabilities_create_name: name),
    effect.none(),
  )
}

/// Handle capability create form submission.
pub fn handle_capability_create_submitted(
  model: admin_capabilities.Model,
  context: Context(parent_msg),
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  case model.capabilities_create_in_flight {
    True -> #(model, effect.none())
    False -> {
      let name = string.trim(model.capabilities_create_name)

      case name == "", context.selected_project_id {
        True, _ -> #(
          admin_capabilities.Model(
            ..model,
            capabilities_create_error: opt.Some(context.name_required),
          ),
          effect.none(),
        )
        _, opt.None -> #(model, effect.none())
        False, opt.Some(project_id) -> {
          let model =
            admin_capabilities.Model(
              ..model,
              capabilities_create_in_flight: True,
              capabilities_create_error: opt.None,
            )
          #(
            model,
            api_org.create_project_capability(
              project_id,
              name,
              context.on_capability_created,
            ),
          )
        }
      }
    }
  }
}

/// Handle capability created success.
pub fn handle_capability_created_ok(
  model: admin_capabilities.Model,
  capability: Capability,
  feedback: FeedbackContext(parent_msg),
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  let updated = case model.capabilities {
    Loaded(capabilities) -> [capability, ..capabilities]
    _ -> [capability]
  }

  #(
    admin_capabilities.Model(
      ..model,
      capabilities: Loaded(updated),
      capabilities_dialog_mode: dialog_mode.DialogClosed,
      capabilities_create_in_flight: False,
      capabilities_create_name: "",
    ),
    success_effect(CapabilityCreated, feedback),
  )
}

/// Handle capability created error.
pub fn handle_capability_created_error(
  model: admin_capabilities.Model,
  message: String,
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  #(
    admin_capabilities.Model(
      ..model,
      capabilities_create_in_flight: False,
      capabilities_create_error: opt.Some(message),
    ),
    effect.none(),
  )
}

// =============================================================================
// Capability Delete Handlers (Story 4.9 AC9)
// =============================================================================

/// Handle capability delete dialog open.
pub fn handle_capability_delete_dialog_opened(
  model: admin_capabilities.Model,
  capability_id: Int,
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  #(
    admin_capabilities.Model(
      ..model,
      capabilities_dialog_mode: dialog_mode.DialogDelete,
      capability_delete_dialog_id: opt.Some(capability_id),
      capability_delete_in_flight: False,
      capability_delete_error: opt.None,
    ),
    effect.none(),
  )
}

/// Handle capability delete dialog close.
pub fn handle_capability_delete_dialog_closed(
  model: admin_capabilities.Model,
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  #(
    admin_capabilities.Model(
      ..model,
      capabilities_dialog_mode: dialog_mode.DialogClosed,
      capability_delete_dialog_id: opt.None,
      capability_delete_in_flight: False,
      capability_delete_error: opt.None,
    ),
    effect.none(),
  )
}

/// Handle capability delete form submission.
pub fn handle_capability_delete_submitted(
  model: admin_capabilities.Model,
  context: Context(parent_msg),
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  case
    model.capability_delete_in_flight,
    model.capability_delete_dialog_id,
    context.selected_project_id
  {
    True, _, _ -> #(model, effect.none())
    _, opt.None, _ -> #(model, effect.none())
    _, _, opt.None -> #(model, effect.none())
    False, opt.Some(capability_id), opt.Some(project_id) -> {
      let model =
        admin_capabilities.Model(
          ..model,
          capability_delete_in_flight: True,
          capability_delete_error: opt.None,
        )
      #(
        model,
        api_org.delete_project_capability(
          project_id,
          capability_id,
          context.on_capability_deleted,
        ),
      )
    }
  }
}

/// Handle capability deleted success.
pub fn handle_capability_deleted_ok(
  model: admin_capabilities.Model,
  deleted_id: Int,
  feedback: FeedbackContext(parent_msg),
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  let updated = case model.capabilities {
    Loaded(capabilities) ->
      Loaded(list.filter(capabilities, fn(c) { c.id != deleted_id }))
    other -> other
  }

  #(
    admin_capabilities.Model(
      ..model,
      capabilities: updated,
      capabilities_dialog_mode: dialog_mode.DialogClosed,
      capability_delete_dialog_id: opt.None,
      capability_delete_in_flight: False,
      capability_delete_error: opt.None,
    ),
    success_effect(CapabilityDeleted, feedback),
  )
}

/// Handle capability deleted error.
pub fn handle_capability_deleted_error(
  model: admin_capabilities.Model,
  message: String,
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  #(
    admin_capabilities.Model(
      ..model,
      capability_delete_in_flight: False,
      capability_delete_error: opt.Some(message),
    ),
    effect.none(),
  )
}

pub fn success_effect(
  success: Success,
  context: FeedbackContext(parent_msg),
) -> Effect(parent_msg) {
  context.on_success_toast(success_message(success, context))
}

fn success_message(success: Success, context: FeedbackContext(parent_msg)) {
  case success {
    CapabilityCreated -> context.capability_created
    CapabilityDeleted -> context.capability_deleted
    MemberCapabilitiesSaved -> context.member_capabilities_saved
    CapabilityMembersSaved -> context.capability_members_saved
  }
}
