import gleam/dict
import gleam/option as opt
import lustre/effect

import domain/api_error.{ApiError}
import scrumbringer_client/client_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/skills as member_skills
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/pool/skills_route

fn model_with_skills(skills: member_skills.Model) -> client_state.Model {
  client_state.update_member(client_state.default_model(), fn(member) {
    member_state.MemberModel(..member, skills: skills)
  })
}

pub fn try_update_routes_skill_toggle_test() {
  let assert opt.Some(#(next, fx)) =
    skills_route.try_update(
      client_state.default_model(),
      pool_messages.MemberToggleCapability(7),
    )

  let assert Ok(True) =
    dict.get(next.member.skills.member_my_capability_ids_edit, 7)
  let assert True = fx == effect.none()
}

pub fn try_update_handles_unauthorized_before_apply_test() {
  let err =
    ApiError(status: 401, code: "UNAUTHORIZED", message: "Sign in again")
  let model =
    model_with_skills(
      member_skills.Model(
        ..member_skills.default_model(),
        member_my_capabilities_in_flight: True,
      ),
    )

  let assert opt.Some(#(next, fx)) =
    skills_route.try_update(
      model,
      pool_messages.MemberMyCapabilityIdsSaved(Error(err)),
    )

  let assert client_state.Login = next.core.page
  let assert opt.None = next.core.user
  let assert True = next.member.skills.member_my_capabilities_in_flight
  let assert opt.None = next.member.skills.member_my_capabilities_error
  let assert True = fx == effect.none()
}

pub fn try_update_ignores_non_skills_messages_test() {
  let assert opt.None =
    skills_route.try_update(
      client_state.default_model(),
      pool_messages.MemberPoolFiltersToggled,
    )
}
