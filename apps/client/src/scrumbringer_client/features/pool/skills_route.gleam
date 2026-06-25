//// Root-aware adapter for member skills updates in the pool.

import gleam/option as opt
import lustre/effect

import domain/api_error.{type ApiError}
import scrumbringer_client/app/effects as app_effects
import scrumbringer_client/client_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/skills as member_skills
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/route_support
import scrumbringer_client/features/skills/update as skills_workflow
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/text as i18n_text

pub fn try_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case skills_workflow.try_update(model.member.skills, inner, context(model)) {
    opt.Some(update) -> opt.Some(apply_update(model, update))
    opt.None -> opt.None
  }
}

fn apply_update(
  model: client_state.Model,
  update: skills_workflow.Update(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let skills_workflow.Update(skills, fx, auth_policy) = update

  route_support.apply_auth_check_before(model, auth_error(auth_policy), fn() {
    #(set_member_skills(model, skills), fx)
  })
}

fn context(
  model: client_state.Model,
) -> skills_workflow.Context(client_state.Msg) {
  skills_workflow.Context(
    selected_project_id: model.core.selected_project_id,
    user_id: selected_user_id(model),
    on_my_capability_ids_fetched: fn(result) {
      client_state.pool_msg(pool_messages.MemberMyCapabilityIdsFetched(result))
    },
    on_my_capability_ids_saved: fn(result) {
      client_state.pool_msg(pool_messages.MemberMyCapabilityIdsSaved(result))
    },
    skills_saved: i18n.t(model.ui.locale, i18n_text.SkillsSaved),
    on_success_toast: app_effects.toast_success,
    on_error_toast: app_effects.toast_error,
  )
}

fn auth_error(policy: skills_workflow.AuthPolicy) -> opt.Option(ApiError) {
  case policy {
    skills_workflow.NoAuthCheck -> opt.None
    skills_workflow.CheckAuth(err) -> opt.Some(err)
  }
}

fn selected_user_id(model: client_state.Model) -> opt.Option(Int) {
  model.core.user
  |> opt.map(fn(user) { user.id })
}

fn set_member_skills(
  model: client_state.Model,
  skills: member_skills.Model,
) -> client_state.Model {
  client_state.update_member(model, fn(member) {
    member_state.MemberModel(..member, skills: skills)
  })
}
