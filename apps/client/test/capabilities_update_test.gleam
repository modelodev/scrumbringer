import gleam/dict
import gleam/option

import lustre/effect

import domain/api_error.{type ApiError, ApiError}
import domain/capability.{type Capability, Capability}
import domain/remote
import scrumbringer_client/api/member_capabilities
import scrumbringer_client/api/projects as api_projects
import scrumbringer_client/client_state/admin/capabilities as admin_capabilities
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/capabilities/types as capability_types
import scrumbringer_client/features/capabilities/update as capabilities_update

fn context(selected_project_id) -> capability_types.Context(Nil) {
  capability_types.Context(
    selected_project_id: selected_project_id,
    on_member_capabilities_fetched: fn(_result) { Nil },
    on_member_capabilities_saved: fn(_result) { Nil },
    on_capability_members_fetched: fn(_result) { Nil },
    on_capability_members_saved: fn(_result) { Nil },
    on_capability_created: fn(_result) { Nil },
    on_capability_updated: fn(_result) { Nil },
    on_capability_deleted: fn(_result) { Nil },
    name_required: "Name required",
  )
}

fn feedback_context() -> capability_types.FeedbackContext(Nil) {
  capability_types.FeedbackContext(
    capability_created: "Capability created",
    capability_updated: "Capability updated",
    capability_deleted: "Capability deleted",
    member_capabilities_saved: "Capabilities saved",
    capability_members_saved: "Members saved",
    on_success_toast: fn(_message) {
      effect.from(fn(dispatch) { dispatch(Nil) })
    },
  )
}

fn error_feedback_context() -> capability_types.ErrorFeedbackContext(Nil) {
  capability_types.ErrorFeedbackContext(
    not_permitted: "Not permitted",
    on_warning_toast: fn(_message) {
      effect.from(fn(dispatch) { dispatch(Nil) })
    },
  )
}

fn run(
  model: admin_capabilities.Model,
  inner: admin_messages.Msg,
  context: capability_types.Context(Nil),
  feedback: capability_types.FeedbackContext(Nil),
  error_feedback: capability_types.ErrorFeedbackContext(Nil),
) -> #(admin_capabilities.Model, effect.Effect(Nil)) {
  let assert option.Some(capabilities_update.Update(next, fx, _policy)) =
    capabilities_update.try_update(
      model,
      inner,
      context,
      feedback,
      error_feedback,
    )
  #(next, fx)
}

fn run_default(
  model: admin_capabilities.Model,
  inner: admin_messages.Msg,
) -> #(admin_capabilities.Model, effect.Effect(Nil)) {
  run(
    model,
    inner,
    context(option.None),
    feedback_context(),
    error_feedback_context(),
  )
}

fn api_error(message: String) -> ApiError {
  ApiError(status: 500, code: "ERROR", message: message)
}

fn handle_capabilities_fetched_ok(
  model: admin_capabilities.Model,
  capabilities: List(Capability),
  context: capability_types.Context(Nil),
) -> #(admin_capabilities.Model, effect.Effect(Nil)) {
  run(
    model,
    admin_messages.CapabilitiesFetched(Ok(capabilities)),
    context,
    feedback_context(),
    error_feedback_context(),
  )
}

fn handle_member_capabilities_dialog_opened(
  model: admin_capabilities.Model,
  user_id: Int,
  context: capability_types.Context(Nil),
) -> #(admin_capabilities.Model, effect.Effect(Nil)) {
  run(
    model,
    admin_messages.MemberCapabilitiesDialogOpened(user_id),
    context,
    feedback_context(),
    error_feedback_context(),
  )
}

fn handle_member_capabilities_toggled(
  model: admin_capabilities.Model,
  capability_id: Int,
) -> #(admin_capabilities.Model, effect.Effect(Nil)) {
  run_default(model, admin_messages.MemberCapabilitiesToggled(capability_id))
}

fn handle_member_capabilities_save_clicked(
  model: admin_capabilities.Model,
  context: capability_types.Context(Nil),
) -> #(admin_capabilities.Model, effect.Effect(Nil)) {
  run(
    model,
    admin_messages.MemberCapabilitiesSaveClicked,
    context,
    feedback_context(),
    error_feedback_context(),
  )
}

fn handle_member_capabilities_fetched_ok(
  model: admin_capabilities.Model,
  result: member_capabilities.MemberCapabilities,
) -> #(admin_capabilities.Model, effect.Effect(Nil)) {
  run_default(model, admin_messages.MemberCapabilitiesFetched(Ok(result)))
}

fn handle_member_capabilities_fetched_error(
  model: admin_capabilities.Model,
  message: String,
) -> #(admin_capabilities.Model, effect.Effect(Nil)) {
  run_default(
    model,
    admin_messages.MemberCapabilitiesFetched(Error(api_error(message))),
  )
}

fn handle_member_capabilities_saved_ok(
  model: admin_capabilities.Model,
  result: member_capabilities.MemberCapabilities,
  feedback: capability_types.FeedbackContext(Nil),
) -> #(admin_capabilities.Model, effect.Effect(Nil)) {
  run(
    model,
    admin_messages.MemberCapabilitiesSaved(Ok(result)),
    context(option.None),
    feedback,
    error_feedback_context(),
  )
}

fn handle_member_capabilities_saved_error(
  model: admin_capabilities.Model,
  message: String,
) -> #(admin_capabilities.Model, effect.Effect(Nil)) {
  run_default(
    model,
    admin_messages.MemberCapabilitiesSaved(Error(api_error(message))),
  )
}

fn handle_capability_members_dialog_opened(
  model: admin_capabilities.Model,
  capability_id: Int,
  context: capability_types.Context(Nil),
) -> #(admin_capabilities.Model, effect.Effect(Nil)) {
  run(
    model,
    admin_messages.CapabilityMembersDialogOpened(capability_id),
    context,
    feedback_context(),
    error_feedback_context(),
  )
}

fn handle_capability_members_toggled(
  model: admin_capabilities.Model,
  user_id: Int,
) -> #(admin_capabilities.Model, effect.Effect(Nil)) {
  run_default(model, admin_messages.CapabilityMembersToggled(user_id))
}

fn handle_capability_members_save_clicked(
  model: admin_capabilities.Model,
  context: capability_types.Context(Nil),
) -> #(admin_capabilities.Model, effect.Effect(Nil)) {
  run(
    model,
    admin_messages.CapabilityMembersSaveClicked,
    context,
    feedback_context(),
    error_feedback_context(),
  )
}

fn handle_capability_members_fetched_ok(
  model: admin_capabilities.Model,
  result: api_projects.CapabilityMembers,
) -> #(admin_capabilities.Model, effect.Effect(Nil)) {
  run_default(model, admin_messages.CapabilityMembersFetched(Ok(result)))
}

fn handle_capability_members_fetched_error(
  model: admin_capabilities.Model,
  message: String,
) -> #(admin_capabilities.Model, effect.Effect(Nil)) {
  run_default(
    model,
    admin_messages.CapabilityMembersFetched(Error(api_error(message))),
  )
}

fn handle_capability_members_saved_ok(
  model: admin_capabilities.Model,
  result: api_projects.CapabilityMembers,
  feedback: capability_types.FeedbackContext(Nil),
) -> #(admin_capabilities.Model, effect.Effect(Nil)) {
  run(
    model,
    admin_messages.CapabilityMembersSaved(Ok(result)),
    context(option.None),
    feedback,
    error_feedback_context(),
  )
}

fn handle_capability_members_saved_error(
  model: admin_capabilities.Model,
  message: String,
) -> #(admin_capabilities.Model, effect.Effect(Nil)) {
  run_default(
    model,
    admin_messages.CapabilityMembersSaved(Error(api_error(message))),
  )
}

fn handle_capability_dialog_opened(
  model: admin_capabilities.Model,
) -> #(admin_capabilities.Model, effect.Effect(Nil)) {
  run_default(model, admin_messages.CapabilityCreateDialogOpened)
}

fn handle_capability_create_submitted(
  model: admin_capabilities.Model,
  context: capability_types.Context(Nil),
) -> #(admin_capabilities.Model, effect.Effect(Nil)) {
  run(
    model,
    admin_messages.CapabilityCreateSubmitted,
    context,
    feedback_context(),
    error_feedback_context(),
  )
}

fn handle_capability_created_ok(
  model: admin_capabilities.Model,
  capability: Capability,
  feedback: capability_types.FeedbackContext(Nil),
) -> #(admin_capabilities.Model, effect.Effect(Nil)) {
  run(
    model,
    admin_messages.CapabilityCreated(Ok(capability)),
    context(option.None),
    feedback,
    error_feedback_context(),
  )
}

fn handle_capability_delete_submitted(
  model: admin_capabilities.Model,
  context: capability_types.Context(Nil),
) -> #(admin_capabilities.Model, effect.Effect(Nil)) {
  run(
    model,
    admin_messages.CapabilityDeleteSubmitted,
    context,
    feedback_context(),
    error_feedback_context(),
  )
}

fn handle_capability_deleted_ok(
  model: admin_capabilities.Model,
  deleted_id: Int,
  feedback: capability_types.FeedbackContext(Nil),
) -> #(admin_capabilities.Model, effect.Effect(Nil)) {
  run(
    model,
    admin_messages.CapabilityDeleted(Ok(deleted_id)),
    context(option.None),
    feedback,
    error_feedback_context(),
  )
}

pub fn fetched_ok_loads_capabilities_test() {
  let capabilities = [Capability(id: 1, name: "Backend")]

  let #(next, _fx) =
    handle_capabilities_fetched_ok(
      admin_capabilities.default_model(),
      capabilities,
      context(option.None),
    )

  let assert True = next.capabilities == remote.Loaded(capabilities)
}

pub fn member_capabilities_opened_uses_cache_and_fetches_test() {
  let model =
    admin_capabilities.Model(
      ..admin_capabilities.default_model(),
      member_capabilities_cache: dict.from_list([#(7, [1, 2])]),
    )

  let #(next, fx) =
    handle_member_capabilities_dialog_opened(model, 7, context(option.Some(3)))

  let assert option.Some(7) = next.member_capabilities_dialog_user_id
  let assert True = next.member_capabilities_loading
  let assert [1, 2] = next.member_capabilities_selected
  let assert option.None = next.member_capabilities_error
  let assert False = fx == effect.none()
}

pub fn member_capabilities_opened_ignores_missing_project_test() {
  let #(next, fx) =
    handle_member_capabilities_dialog_opened(
      admin_capabilities.default_model(),
      7,
      context(option.None),
    )

  let assert option.None = next.member_capabilities_dialog_user_id
  let assert False = next.member_capabilities_loading
  let assert True = fx == effect.none()
}

pub fn member_capabilities_toggled_adds_and_removes_id_test() {
  let model =
    admin_capabilities.Model(
      ..admin_capabilities.default_model(),
      member_capabilities_selected: [1, 2],
    )

  let #(without_two, remove_fx) = handle_member_capabilities_toggled(model, 2)
  let #(with_three, add_fx) = handle_member_capabilities_toggled(without_two, 3)

  let assert [1] = without_two.member_capabilities_selected
  let assert [3, 1] = with_three.member_capabilities_selected
  let assert True = remove_fx == effect.none()
  let assert True = add_fx == effect.none()
}

pub fn member_capabilities_save_sets_in_flight_when_valid_test() {
  let model =
    admin_capabilities.Model(
      ..admin_capabilities.default_model(),
      member_capabilities_dialog_user_id: option.Some(7),
      member_capabilities_selected: [1, 2],
    )

  let #(next, fx) =
    handle_member_capabilities_save_clicked(model, context(option.Some(3)))

  let assert True = next.member_capabilities_saving
  let assert False = fx == effect.none()
}

pub fn member_capabilities_fetched_ok_updates_cache_and_selection_test() {
  let model =
    admin_capabilities.Model(
      ..admin_capabilities.default_model(),
      member_capabilities_loading: True,
    )

  let #(next, fx) =
    handle_member_capabilities_fetched_ok(
      model,
      member_capabilities.MemberCapabilities(user_id: 7, capability_ids: [1, 2]),
    )

  let assert False = next.member_capabilities_loading
  let assert [1, 2] = next.member_capabilities_selected
  let assert Ok([1, 2]) = dict.get(next.member_capabilities_cache, 7)
  let assert True = fx == effect.none()
}

pub fn member_capabilities_saved_ok_closes_dialog_and_updates_cache_test() {
  let model =
    admin_capabilities.Model(
      ..admin_capabilities.default_model(),
      member_capabilities_dialog_user_id: option.Some(7),
      member_capabilities_saving: True,
      member_capabilities_selected: [4],
    )

  let #(next, fx) =
    handle_member_capabilities_saved_ok(
      model,
      member_capabilities.MemberCapabilities(user_id: 7, capability_ids: [1, 2]),
      feedback_context(),
    )

  let assert False = next.member_capabilities_saving
  let assert option.None = next.member_capabilities_dialog_user_id
  let assert [] = next.member_capabilities_selected
  let assert Ok([1, 2]) = dict.get(next.member_capabilities_cache, 7)
  let assert False = fx == effect.none()
}

pub fn member_capabilities_errors_update_local_flags_test() {
  let loading_model =
    admin_capabilities.Model(
      ..admin_capabilities.default_model(),
      member_capabilities_loading: True,
    )
  let #(fetched_error, fetch_fx) =
    handle_member_capabilities_fetched_error(loading_model, "boom")

  let saving_model =
    admin_capabilities.Model(
      ..admin_capabilities.default_model(),
      member_capabilities_saving: True,
    )
  let #(saved_error, save_fx) =
    handle_member_capabilities_saved_error(saving_model, "nope")

  let assert False = fetched_error.member_capabilities_loading
  let assert option.Some("boom") = fetched_error.member_capabilities_error
  let assert False = saved_error.member_capabilities_saving
  let assert option.Some("nope") = saved_error.member_capabilities_error
  let assert True = fetch_fx == effect.none()
  let assert True = save_fx == effect.none()
}

pub fn capability_members_opened_uses_cache_and_fetches_test() {
  let model =
    admin_capabilities.Model(
      ..admin_capabilities.default_model(),
      capability_members_cache: dict.from_list([#(5, [7, 8])]),
    )

  let #(next, fx) =
    handle_capability_members_dialog_opened(model, 5, context(option.Some(3)))

  let assert option.Some(5) = next.capability_members_dialog_capability_id
  let assert True = next.capability_members_loading
  let assert [7, 8] = next.capability_members_selected
  let assert option.None = next.capability_members_error
  let assert False = fx == effect.none()
}

pub fn capability_members_toggled_adds_and_removes_user_test() {
  let model =
    admin_capabilities.Model(
      ..admin_capabilities.default_model(),
      capability_members_selected: [7, 8],
    )

  let #(without_eight, remove_fx) = handle_capability_members_toggled(model, 8)
  let #(with_nine, add_fx) = handle_capability_members_toggled(without_eight, 9)

  let assert [7] = without_eight.capability_members_selected
  let assert [9, 7] = with_nine.capability_members_selected
  let assert True = remove_fx == effect.none()
  let assert True = add_fx == effect.none()
}

pub fn capability_members_save_sets_in_flight_when_valid_test() {
  let model =
    admin_capabilities.Model(
      ..admin_capabilities.default_model(),
      capability_members_dialog_capability_id: option.Some(5),
      capability_members_selected: [7, 8],
    )

  let #(next, fx) =
    handle_capability_members_save_clicked(model, context(option.Some(3)))

  let assert True = next.capability_members_saving
  let assert False = fx == effect.none()
}

pub fn capability_members_fetched_ok_updates_cache_and_selection_test() {
  let model =
    admin_capabilities.Model(
      ..admin_capabilities.default_model(),
      capability_members_loading: True,
    )

  let #(next, fx) =
    handle_capability_members_fetched_ok(
      model,
      api_projects.CapabilityMembers(capability_id: 5, user_ids: [7, 8]),
    )

  let assert False = next.capability_members_loading
  let assert [7, 8] = next.capability_members_selected
  let assert Ok([7, 8]) = dict.get(next.capability_members_cache, 5)
  let assert True = fx == effect.none()
}

pub fn capability_members_saved_ok_closes_dialog_and_updates_cache_test() {
  let model =
    admin_capabilities.Model(
      ..admin_capabilities.default_model(),
      capability_members_dialog_capability_id: option.Some(5),
      capability_members_saving: True,
      capability_members_selected: [4],
    )

  let #(next, fx) =
    handle_capability_members_saved_ok(
      model,
      api_projects.CapabilityMembers(capability_id: 5, user_ids: [7, 8]),
      feedback_context(),
    )

  let assert False = next.capability_members_saving
  let assert option.None = next.capability_members_dialog_capability_id
  let assert [] = next.capability_members_selected
  let assert Ok([7, 8]) = dict.get(next.capability_members_cache, 5)
  let assert False = fx == effect.none()
}

pub fn capability_members_errors_update_local_flags_test() {
  let loading_model =
    admin_capabilities.Model(
      ..admin_capabilities.default_model(),
      capability_members_loading: True,
    )
  let #(fetched_error, fetch_fx) =
    handle_capability_members_fetched_error(loading_model, "boom")

  let saving_model =
    admin_capabilities.Model(
      ..admin_capabilities.default_model(),
      capability_members_saving: True,
    )
  let #(saved_error, save_fx) =
    handle_capability_members_saved_error(saving_model, "nope")

  let assert False = fetched_error.capability_members_loading
  let assert option.Some("boom") = fetched_error.capability_members_error
  let assert False = saved_error.capability_members_saving
  let assert option.Some("nope") = saved_error.capability_members_error
  let assert True = fetch_fx == effect.none()
  let assert True = save_fx == effect.none()
}

pub fn create_dialog_opened_sets_create_mode_test() {
  let #(next, fx) =
    handle_capability_dialog_opened(admin_capabilities.default_model())

  let assert dialog_mode.DialogCreate = next.capabilities_dialog_mode
  let assert True = fx == effect.none()
}

pub fn create_submit_requires_name_test() {
  let model =
    admin_capabilities.Model(
      ..admin_capabilities.default_model(),
      capabilities_create_name: "  ",
    )

  let #(next, fx) =
    handle_capability_create_submitted(model, context(option.Some(7)))

  let assert option.Some("Name required") = next.capabilities_create_error
  let assert True = fx == effect.none()
}

pub fn create_submit_sets_in_flight_when_valid_test() {
  let model =
    admin_capabilities.Model(
      ..admin_capabilities.default_model(),
      capabilities_create_name: " Backend ",
    )

  let #(next, _fx) =
    handle_capability_create_submitted(model, context(option.Some(7)))

  let assert True = next.capabilities_create_in_flight
  let assert option.None = next.capabilities_create_error
}

pub fn created_ok_closes_dialog_and_prepends_capability_test() {
  let model =
    admin_capabilities.Model(
      ..admin_capabilities.default_model(),
      capabilities: remote.Loaded([Capability(id: 1, name: "Backend")]),
      capabilities_dialog_mode: dialog_mode.DialogCreate,
      capabilities_create_in_flight: True,
      capabilities_create_name: "Frontend",
    )

  let #(next, fx) =
    handle_capability_created_ok(
      model,
      Capability(id: 2, name: "Frontend"),
      feedback_context(),
    )

  let assert remote.Loaded([
    Capability(id: 2, name: "Frontend"),
    Capability(id: 1, name: "Backend"),
  ]) = next.capabilities
  let assert dialog_mode.DialogClosed = next.capabilities_dialog_mode
  let assert False = next.capabilities_create_in_flight
  let assert "" = next.capabilities_create_name
  let assert False = fx == effect.none()
}

pub fn delete_submit_ignores_missing_project_test() {
  let model =
    admin_capabilities.Model(
      ..admin_capabilities.default_model(),
      capability_delete_dialog_id: option.Some(5),
    )

  let #(next, fx) =
    handle_capability_delete_submitted(model, context(option.None))

  let assert False = next.capability_delete_in_flight
  let assert True = fx == effect.none()
}

pub fn deleted_ok_removes_capability_and_closes_dialog_test() {
  let model =
    admin_capabilities.Model(
      ..admin_capabilities.default_model(),
      capabilities: remote.Loaded([
        Capability(id: 1, name: "Backend"),
        Capability(id: 2, name: "Frontend"),
      ]),
      capabilities_dialog_mode: dialog_mode.DialogDelete,
      capability_delete_dialog_id: option.Some(1),
      capability_delete_in_flight: True,
    )

  let #(next, fx) = handle_capability_deleted_ok(model, 1, feedback_context())

  let assert remote.Loaded([Capability(id: 2, name: "Frontend")]) =
    next.capabilities
  let assert dialog_mode.DialogClosed = next.capabilities_dialog_mode
  let assert option.None = next.capability_delete_dialog_id
  let assert False = next.capability_delete_in_flight
  let assert False = fx == effect.none()
}

pub fn try_update_fetched_ok_returns_local_update_test() {
  let capabilities = [Capability(id: 1, name: "Backend")]

  let assert option.Some(capabilities_update.Update(
    next,
    _fx,
    capabilities_update.NoAuthCheck,
  )) =
    capabilities_update.try_update(
      admin_capabilities.default_model(),
      admin_messages.CapabilitiesFetched(Ok(capabilities)),
      context(option.None),
      feedback_context(),
      error_feedback_context(),
    )

  let assert True = next.capabilities == remote.Loaded(capabilities)
}

pub fn try_update_created_forbidden_returns_auth_policy_and_warning_test() {
  let err = ApiError(status: 403, code: "FORBIDDEN", message: "backend")

  let assert option.Some(capabilities_update.Update(
    next,
    fx,
    capabilities_update.CheckAuth(auth_err),
  )) =
    capabilities_update.try_update(
      admin_capabilities.default_model(),
      admin_messages.CapabilityCreated(Error(err)),
      context(option.Some(7)),
      feedback_context(),
      error_feedback_context(),
    )

  let assert option.Some("Not permitted") = next.capabilities_create_error
  let assert True = auth_err == err
  let assert False = fx == effect.none()
}

pub fn try_update_ignores_non_capability_messages_test() {
  let assert option.None =
    capabilities_update.try_update(
      admin_capabilities.default_model(),
      admin_messages.InviteCreateDialogOpened,
      context(option.None),
      feedback_context(),
      error_feedback_context(),
    )
}
