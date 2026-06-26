//// Capability assignment update handlers.

import gleam/dict
import gleam/list
import gleam/option as opt

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError}
import scrumbringer_client/api/member_capabilities
import scrumbringer_client/api/projects as api_projects
import scrumbringer_client/client_state/admin/capabilities as admin_capabilities
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/capabilities/types as capability_types

pub fn try_update(
  model: admin_capabilities.Model,
  inner: admin_messages.Msg,
  context: capability_types.Context(parent_msg),
  feedback: capability_types.FeedbackContext(parent_msg),
) -> opt.Option(
  #(admin_capabilities.Model, Effect(parent_msg), opt.Option(ApiError)),
) {
  case inner {
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

fn handle_member_capabilities_dialog_opened(
  model: admin_capabilities.Model,
  user_id: Int,
  context: capability_types.Context(parent_msg),
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  case context.selected_project_id {
    opt.Some(project_id) -> {
      #(
        admin_capabilities.Model(
          ..model,
          member_capabilities_dialog_user_id: opt.Some(user_id),
          member_capabilities_loading: True,
          member_capabilities_selected: cached_ids(
            model.member_capabilities_cache,
            user_id,
          ),
          member_capabilities_error: opt.None,
        ),
        member_capabilities.get_member_capabilities(
          project_id,
          user_id,
          context.on_member_capabilities_fetched,
        ),
      )
    }

    opt.None -> no_effect(model)
  }
}

fn handle_member_capabilities_dialog_closed(
  model: admin_capabilities.Model,
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  admin_capabilities.Model(
    ..model,
    member_capabilities_dialog_user_id: opt.None,
    member_capabilities_selected: [],
    member_capabilities_error: opt.None,
  )
  |> no_effect
}

fn handle_member_capabilities_toggled(
  model: admin_capabilities.Model,
  capability_id: Int,
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  admin_capabilities.Model(
    ..model,
    member_capabilities_selected: toggle_id(
      model.member_capabilities_selected,
      capability_id,
    ),
  )
  |> no_effect
}

fn handle_member_capabilities_save_clicked(
  model: admin_capabilities.Model,
  context: capability_types.Context(parent_msg),
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  case context.selected_project_id, model.member_capabilities_dialog_user_id {
    opt.Some(project_id), opt.Some(user_id) -> #(
      admin_capabilities.Model(..model, member_capabilities_saving: True),
      member_capabilities.set_member_capabilities(
        project_id,
        user_id,
        model.member_capabilities_selected,
        context.on_member_capabilities_saved,
      ),
    )

    _, _ -> no_effect(model)
  }
}

fn handle_member_capabilities_fetched_ok(
  model: admin_capabilities.Model,
  result: member_capabilities.MemberCapabilities,
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  admin_capabilities.Model(
    ..model,
    member_capabilities_loading: False,
    member_capabilities_cache: dict.insert(
      model.member_capabilities_cache,
      result.user_id,
      result.capability_ids,
    ),
    member_capabilities_selected: result.capability_ids,
  )
  |> no_effect
}

fn handle_member_capabilities_fetched_error(
  model: admin_capabilities.Model,
  message: String,
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  admin_capabilities.Model(
    ..model,
    member_capabilities_loading: False,
    member_capabilities_error: opt.Some(message),
  )
  |> no_effect
}

fn handle_member_capabilities_saved_ok(
  model: admin_capabilities.Model,
  result: member_capabilities.MemberCapabilities,
  feedback: capability_types.FeedbackContext(parent_msg),
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
    capability_types.success_effect(
      capability_types.MemberCapabilitiesSaved,
      feedback,
    ),
  )
}

fn handle_member_capabilities_saved_error(
  model: admin_capabilities.Model,
  message: String,
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  admin_capabilities.Model(
    ..model,
    member_capabilities_saving: False,
    member_capabilities_error: opt.Some(message),
  )
  |> no_effect
}

fn handle_capability_members_dialog_opened(
  model: admin_capabilities.Model,
  capability_id: Int,
  context: capability_types.Context(parent_msg),
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  case context.selected_project_id {
    opt.Some(project_id) -> {
      #(
        admin_capabilities.Model(
          ..model,
          capability_members_dialog_capability_id: opt.Some(capability_id),
          capability_members_loading: True,
          capability_members_selected: cached_ids(
            model.capability_members_cache,
            capability_id,
          ),
          capability_members_error: opt.None,
        ),
        api_projects.get_capability_members(
          project_id,
          capability_id,
          context.on_capability_members_fetched,
        ),
      )
    }

    opt.None -> no_effect(model)
  }
}

fn handle_capability_members_dialog_closed(
  model: admin_capabilities.Model,
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  admin_capabilities.Model(
    ..model,
    capability_members_dialog_capability_id: opt.None,
    capability_members_selected: [],
    capability_members_error: opt.None,
  )
  |> no_effect
}

fn handle_capability_members_toggled(
  model: admin_capabilities.Model,
  user_id: Int,
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  admin_capabilities.Model(
    ..model,
    capability_members_selected: toggle_id(
      model.capability_members_selected,
      user_id,
    ),
  )
  |> no_effect
}

fn handle_capability_members_save_clicked(
  model: admin_capabilities.Model,
  context: capability_types.Context(parent_msg),
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

    _, _ -> no_effect(model)
  }
}

fn handle_capability_members_fetched_ok(
  model: admin_capabilities.Model,
  result: api_projects.CapabilityMembers,
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  admin_capabilities.Model(
    ..model,
    capability_members_loading: False,
    capability_members_cache: dict.insert(
      model.capability_members_cache,
      result.capability_id,
      result.user_ids,
    ),
    capability_members_selected: result.user_ids,
  )
  |> no_effect
}

fn handle_capability_members_fetched_error(
  model: admin_capabilities.Model,
  message: String,
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  admin_capabilities.Model(
    ..model,
    capability_members_loading: False,
    capability_members_error: opt.Some(message),
  )
  |> no_effect
}

fn handle_capability_members_saved_ok(
  model: admin_capabilities.Model,
  result: api_projects.CapabilityMembers,
  feedback: capability_types.FeedbackContext(parent_msg),
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
    capability_types.success_effect(
      capability_types.CapabilityMembersSaved,
      feedback,
    ),
  )
}

fn handle_capability_members_saved_error(
  model: admin_capabilities.Model,
  message: String,
) -> #(admin_capabilities.Model, Effect(parent_msg)) {
  admin_capabilities.Model(
    ..model,
    capability_members_saving: False,
    capability_members_error: opt.Some(message),
  )
  |> no_effect
}

fn cached_ids(cache: dict.Dict(Int, List(Int)), id: Int) -> List(Int) {
  case dict.get(cache, id) {
    Ok(ids) -> ids
    Error(_) -> []
  }
}

fn toggle_id(ids: List(Int), id: Int) -> List(Int) {
  case list.contains(ids, id) {
    True -> list.filter(ids, fn(existing) { existing != id })
    False -> [id, ..ids]
  }
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
