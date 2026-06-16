//// Capability CRUD update handlers.

import gleam/list
import gleam/option as opt
import gleam/string

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError}
import domain/capability.{type Capability}
import domain/remote.{Failed, Loaded}
import scrumbringer_client/api/org as api_org
import scrumbringer_client/api/projects as api_projects
import scrumbringer_client/client_state/admin/capabilities as admin_capabilities
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/capabilities/types as capability_types

pub fn try_update(
  model: admin_capabilities.Model,
  inner: admin_messages.Msg,
  context: capability_types.Context(parent_msg),
  feedback: capability_types.FeedbackContext(parent_msg),
  error_feedback: capability_types.ErrorFeedbackContext(parent_msg),
) -> opt.Option(
  #(admin_capabilities.Model, Effect(parent_msg), opt.Option(ApiError)),
) {
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

    admin_messages.CapabilityEditDialogOpened(capability_id, name) ->
      handle_capability_edit_dialog_opened(model, capability_id, name)
      |> without_auth_check

    admin_messages.CapabilityEditDialogClosed ->
      handle_capability_edit_dialog_closed(model)
      |> without_auth_check

    admin_messages.CapabilityEditNameChanged(name) ->
      handle_capability_edit_name_changed(model, name)
      |> without_auth_check

    admin_messages.CapabilityEditSubmitted ->
      handle_capability_edit_submitted(model, context)
      |> without_auth_check

    admin_messages.CapabilityUpdated(Ok(capability)) ->
      handle_capability_updated_ok(model, capability, feedback)
      |> without_auth_check

    admin_messages.CapabilityUpdated(Error(err)) ->
      handle_capability_updated_error(
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

    _ -> opt.None
  }
}

fn handle_capabilities_fetched_ok(
  model: admin_capabilities.Model,
  capabilities: List(Capability),
  context: capability_types.Context(parent_msg),
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
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

fn handle_capabilities_fetched_error(
  model: admin_capabilities.Model,
  err: ApiError,
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  admin_capabilities.Model(..model, capabilities: Failed(err))
  |> no_effect
}

fn handle_capability_dialog_opened(
  model: admin_capabilities.Model,
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  admin_capabilities.Model(
    ..model,
    capabilities_dialog_mode: dialog_mode.DialogCreate,
  )
  |> no_effect
}

fn handle_capability_dialog_closed(
  model: admin_capabilities.Model,
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  admin_capabilities.Model(
    ..model,
    capabilities_dialog_mode: dialog_mode.DialogClosed,
    capabilities_create_name: "",
    capabilities_create_error: opt.None,
  )
  |> no_effect
}

fn handle_capability_create_name_changed(
  model: admin_capabilities.Model,
  name: String,
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  admin_capabilities.Model(..model, capabilities_create_name: name)
  |> no_effect
}

fn handle_capability_create_submitted(
  model: admin_capabilities.Model,
  context: capability_types.Context(parent_msg),
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  case model.capabilities_create_in_flight {
    True -> no_effect(model)
    False -> {
      let name = string.trim(model.capabilities_create_name)

      case name == "", context.selected_project_id {
        True, _ ->
          admin_capabilities.Model(
            ..model,
            capabilities_create_error: opt.Some(context.name_required),
          )
          |> no_effect
        _, opt.None -> no_effect(model)
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

fn handle_capability_created_ok(
  model: admin_capabilities.Model,
  capability: Capability,
  feedback: capability_types.FeedbackContext(parent_msg),
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
    capability_types.success_effect(
      capability_types.CapabilityCreated,
      feedback,
    ),
  )
}

fn handle_capability_created_error(
  model: admin_capabilities.Model,
  message: String,
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  admin_capabilities.Model(
    ..model,
    capabilities_create_in_flight: False,
    capabilities_create_error: opt.Some(message),
  )
  |> no_effect
}

fn handle_capability_edit_dialog_opened(
  model: admin_capabilities.Model,
  capability_id: Int,
  name: String,
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  admin_capabilities.Model(
    ..model,
    capabilities_dialog_mode: dialog_mode.DialogEdit,
    capability_edit_dialog_id: opt.Some(capability_id),
    capability_edit_name: name,
    capability_edit_in_flight: False,
    capability_edit_error: opt.None,
  )
  |> no_effect
}

fn handle_capability_edit_dialog_closed(
  model: admin_capabilities.Model,
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  admin_capabilities.Model(
    ..model,
    capabilities_dialog_mode: dialog_mode.DialogClosed,
    capability_edit_dialog_id: opt.None,
    capability_edit_name: "",
    capability_edit_in_flight: False,
    capability_edit_error: opt.None,
  )
  |> no_effect
}

fn handle_capability_edit_name_changed(
  model: admin_capabilities.Model,
  name: String,
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  admin_capabilities.Model(
    ..model,
    capability_edit_name: name,
    capability_edit_error: opt.None,
  )
  |> no_effect
}

fn handle_capability_edit_submitted(
  model: admin_capabilities.Model,
  context: capability_types.Context(parent_msg),
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  case
    model.capability_edit_in_flight,
    model.capability_edit_dialog_id,
    context.selected_project_id
  {
    True, _, _ -> no_effect(model)
    _, opt.None, _ -> no_effect(model)
    _, _, opt.None -> no_effect(model)
    False, opt.Some(capability_id), opt.Some(project_id) -> {
      let name = string.trim(model.capability_edit_name)
      case name == "" {
        True ->
          admin_capabilities.Model(
            ..model,
            capability_edit_error: opt.Some(context.name_required),
          )
          |> no_effect
        False -> #(
          admin_capabilities.Model(
            ..model,
            capability_edit_name: name,
            capability_edit_in_flight: True,
            capability_edit_error: opt.None,
          ),
          api_org.update_project_capability(
            project_id,
            capability_id,
            name,
            context.on_capability_updated,
          ),
        )
      }
    }
  }
}

fn handle_capability_updated_ok(
  model: admin_capabilities.Model,
  capability: Capability,
  feedback: capability_types.FeedbackContext(parent_msg),
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  let updated = case model.capabilities {
    Loaded(capabilities) ->
      capabilities
      |> list.map(fn(existing) {
        case existing.id == capability.id {
          True -> capability
          False -> existing
        }
      })
      |> Loaded
    other -> other
  }

  #(
    admin_capabilities.Model(
      ..model,
      capabilities: updated,
      capabilities_dialog_mode: dialog_mode.DialogClosed,
      capability_edit_dialog_id: opt.None,
      capability_edit_name: "",
      capability_edit_in_flight: False,
      capability_edit_error: opt.None,
    ),
    capability_types.success_effect(
      capability_types.CapabilityUpdated,
      feedback,
    ),
  )
}

fn handle_capability_updated_error(
  model: admin_capabilities.Model,
  message: String,
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  admin_capabilities.Model(
    ..model,
    capability_edit_in_flight: False,
    capability_edit_error: opt.Some(message),
  )
  |> no_effect
}

fn handle_capability_delete_dialog_opened(
  model: admin_capabilities.Model,
  capability_id: Int,
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  admin_capabilities.Model(
    ..model,
    capabilities_dialog_mode: dialog_mode.DialogDelete,
    capability_delete_dialog_id: opt.Some(capability_id),
    capability_delete_in_flight: False,
    capability_delete_error: opt.None,
  )
  |> no_effect
}

fn handle_capability_delete_dialog_closed(
  model: admin_capabilities.Model,
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  admin_capabilities.Model(
    ..model,
    capabilities_dialog_mode: dialog_mode.DialogClosed,
    capability_delete_dialog_id: opt.None,
    capability_delete_in_flight: False,
    capability_delete_error: opt.None,
  )
  |> no_effect
}

fn handle_capability_delete_submitted(
  model: admin_capabilities.Model,
  context: capability_types.Context(parent_msg),
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  case
    model.capability_delete_in_flight,
    model.capability_delete_dialog_id,
    context.selected_project_id
  {
    True, _, _ -> no_effect(model)
    _, opt.None, _ -> no_effect(model)
    _, _, opt.None -> no_effect(model)
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

fn handle_capability_deleted_ok(
  model: admin_capabilities.Model,
  deleted_id: Int,
  feedback: capability_types.FeedbackContext(parent_msg),
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
    capability_types.success_effect(
      capability_types.CapabilityDeleted,
      feedback,
    ),
  )
}

fn handle_capability_deleted_error(
  model: admin_capabilities.Model,
  message: String,
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  admin_capabilities.Model(
    ..model,
    capability_delete_in_flight: False,
    capability_delete_error: opt.Some(message),
  )
  |> no_effect
}

fn no_effect(
  model: admin_capabilities.Model,
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  #(model, effect.none())
}

fn without_auth_check(
  result: #(admin_capabilities.Model, Effect(parent_msg)),
) -> opt.Option(
  #(admin_capabilities.Model, Effect(parent_msg), opt.Option(ApiError)),
) {
  let #(model, fx) = result
  opt.Some(#(model, fx, opt.None))
}

fn with_auth_check(
  result: #(admin_capabilities.Model, Effect(parent_msg)),
  err: ApiError,
) -> opt.Option(
  #(admin_capabilities.Model, Effect(parent_msg), opt.Option(ApiError)),
) {
  let #(model, fx) = result
  opt.Some(#(model, fx, opt.Some(err)))
}

fn with_auth_check_and_effect(
  result: #(admin_capabilities.Model, Effect(parent_msg)),
  err: ApiError,
  extra_fx: Effect(parent_msg),
) -> opt.Option(
  #(admin_capabilities.Model, Effect(parent_msg), opt.Option(ApiError)),
) {
  let #(model, fx) = result
  opt.Some(#(model, effect.batch([fx, extra_fx]), opt.Some(err)))
}

fn permission_error_message(
  err: ApiError,
  feedback: capability_types.ErrorFeedbackContext(parent_msg),
) -> String {
  case err.status {
    403 -> feedback.not_permitted
    _ -> err.message
  }
}

fn permission_warning_effect(
  err: ApiError,
  feedback: capability_types.ErrorFeedbackContext(parent_msg),
) -> Effect(parent_msg) {
  case err.status {
    403 -> feedback.on_warning_toast(feedback.not_permitted)
    _ -> effect.none()
  }
}
