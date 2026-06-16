import gleam/dict
import gleam/option
import lustre/effect

import domain/api_error.{type ApiResult, ApiError}
import domain/capability.{Capability}
import domain/remote
import scrumbringer_client/client_state/member/skills as member_skills
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/skills/update as skills_update

fn context() -> skills_update.Context(Nil) {
  skills_update.Context(
    selected_project_id: option.Some(11),
    user_id: option.Some(22),
    on_my_capability_ids_fetched: fn(_result: ApiResult(List(Int))) { Nil },
    on_my_capability_ids_saved: fn(_result: ApiResult(List(Int))) { Nil },
    skills_saved: "Skills saved",
    on_success_toast: fn(_message) { effect.from(fn(_dispatch) { Nil }) },
    on_error_toast: fn(_message) { effect.none() },
  )
}

pub fn capability_ids_success_loads_edit_state_test() {
  let assert option.Some(skills_update.Update(
    next,
    fx,
    skills_update.NoAuthCheck,
  )) =
    skills_update.try_update(
      member_skills.default_model(),
      pool_messages.MemberMyCapabilityIdsFetched(Ok([2, 4])),
      context(),
    )

  let assert True = next.member_my_capability_ids == remote.Loaded([2, 4])
  let assert Ok(True) = dict.get(next.member_my_capability_ids_edit, 2)
  let assert Ok(True) = dict.get(next.member_my_capability_ids_edit, 4)
  let assert True = fx == effect.none()
}

pub fn try_update_handles_capability_ids_success_without_auth_test() {
  let assert option.Some(skills_update.Update(
    next,
    fx,
    skills_update.NoAuthCheck,
  )) =
    skills_update.try_update(
      member_skills.default_model(),
      pool_messages.MemberMyCapabilityIdsFetched(Ok([2, 4])),
      context(),
    )

  let assert True = next.member_my_capability_ids == remote.Loaded([2, 4])
  let assert Ok(True) = dict.get(next.member_my_capability_ids_edit, 2)
  let assert True = fx == effect.none()
}

pub fn project_capabilities_error_sets_failed_state_test() {
  let err = ApiError(status: 500, code: "CAPABILITIES", message: "Boom")

  let assert option.Some(skills_update.Update(
    next,
    fx,
    skills_update.NoAuthCheck,
  )) =
    skills_update.try_update(
      member_skills.default_model(),
      pool_messages.MemberProjectCapabilitiesFetched(Error(err)),
      context(),
    )

  let assert True = next.member_capabilities == remote.Failed(err)
  let assert True = fx == effect.none()
}

pub fn project_capabilities_success_loads_state_test() {
  let capabilities = [Capability(id: 1, name: "Backend")]

  let assert option.Some(skills_update.Update(
    next,
    fx,
    skills_update.NoAuthCheck,
  )) =
    skills_update.try_update(
      member_skills.default_model(),
      pool_messages.MemberProjectCapabilitiesFetched(Ok(capabilities)),
      context(),
    )

  let assert True = next.member_capabilities == remote.Loaded(capabilities)
  let assert True = fx == effect.none()
}

pub fn toggle_capability_defaults_missing_id_to_selected_test() {
  let assert option.Some(skills_update.Update(
    next,
    fx,
    skills_update.NoAuthCheck,
  )) =
    skills_update.try_update(
      member_skills.default_model(),
      pool_messages.MemberToggleCapability(7),
      context(),
    )

  let assert Ok(True) = dict.get(next.member_my_capability_ids_edit, 7)
  let assert True = fx == effect.none()
}

pub fn try_update_handles_toggle_capability_test() {
  let assert option.Some(skills_update.Update(
    next,
    fx,
    skills_update.NoAuthCheck,
  )) =
    skills_update.try_update(
      member_skills.default_model(),
      pool_messages.MemberToggleCapability(7),
      context(),
    )

  let assert Ok(True) = dict.get(next.member_my_capability_ids_edit, 7)
  let assert True = fx == effect.none()
}

pub fn toggle_capability_flips_existing_id_test() {
  let model =
    member_skills.Model(
      ..member_skills.default_model(),
      member_my_capability_ids_edit: dict.from_list([#(7, True)]),
    )

  let assert option.Some(skills_update.Update(
    next,
    fx,
    skills_update.NoAuthCheck,
  )) =
    skills_update.try_update(
      model,
      pool_messages.MemberToggleCapability(7),
      context(),
    )

  let assert Ok(False) = dict.get(next.member_my_capability_ids_edit, 7)
  let assert True = fx == effect.none()
}

pub fn save_clicked_sets_in_flight_when_context_is_complete_test() {
  let model =
    member_skills.Model(
      ..member_skills.default_model(),
      member_my_capability_ids_edit: dict.from_list([#(1, True), #(2, False)]),
      member_my_capabilities_error: option.Some("old error"),
    )

  let assert option.Some(skills_update.Update(
    next,
    _fx,
    skills_update.NoAuthCheck,
  )) =
    skills_update.try_update(
      model,
      pool_messages.MemberSaveCapabilitiesClicked,
      context(),
    )

  let assert True = next.member_my_capabilities_in_flight
  let assert True = next.member_my_capabilities_error == option.None
}

pub fn save_error_records_message_and_stops_in_flight_test() {
  let model =
    member_skills.Model(
      ..member_skills.default_model(),
      member_my_capabilities_in_flight: True,
    )
  let err = ApiError(status: 500, code: "SAVE", message: "Save failed")

  let assert option.Some(skills_update.Update(
    next,
    fx,
    skills_update.CheckAuth(auth_err),
  )) =
    skills_update.try_update(
      model,
      pool_messages.MemberMyCapabilityIdsSaved(Error(err)),
      context(),
    )

  let assert True = auth_err == err
  let assert False = next.member_my_capabilities_in_flight
  let assert True =
    next.member_my_capabilities_error == option.Some("Save failed")
  let assert False = fx == effect.none()
}

pub fn try_update_handles_save_error_with_auth_policy_test() {
  let model =
    member_skills.Model(
      ..member_skills.default_model(),
      member_my_capabilities_in_flight: True,
    )
  let err = ApiError(status: 500, code: "SAVE", message: "Save failed")

  let assert option.Some(skills_update.Update(
    next,
    fx,
    skills_update.CheckAuth(auth_err),
  )) =
    skills_update.try_update(
      model,
      pool_messages.MemberMyCapabilityIdsSaved(Error(err)),
      context(),
    )

  let assert True = auth_err == err
  let assert False = next.member_my_capabilities_in_flight
  let assert True =
    next.member_my_capabilities_error == option.Some("Save failed")
  let assert False = fx == effect.none()
}

pub fn save_success_updates_ids_and_emits_feedback_test() {
  let model =
    member_skills.Model(
      ..member_skills.default_model(),
      member_my_capabilities_in_flight: True,
      member_my_capability_ids_edit: dict.from_list([#(99, True)]),
    )

  let assert option.Some(skills_update.Update(
    next,
    fx,
    skills_update.NoAuthCheck,
  )) =
    skills_update.try_update(
      model,
      pool_messages.MemberMyCapabilityIdsSaved(Ok([1, 2])),
      context(),
    )

  let assert False = next.member_my_capabilities_in_flight
  let assert True = next.member_my_capability_ids == remote.Loaded([1, 2])
  let assert Ok(True) = dict.get(next.member_my_capability_ids_edit, 1)
  let assert Ok(True) = dict.get(next.member_my_capability_ids_edit, 2)
  let assert True = fx != effect.none()
}

pub fn try_update_ignores_non_skills_messages_test() {
  let assert option.None =
    skills_update.try_update(
      member_skills.default_model(),
      pool_messages.MemberPoolSearchChanged("qa"),
      context(),
    )
}
