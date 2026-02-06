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
import domain/remote.{Failed, Loaded}
import scrumbringer_client/api/tasks as api_tasks
import scrumbringer_client/client_state.{
  type Model, type Msg, PoolMsg, update_member,
}
import scrumbringer_client/client_state/member.{MemberModel}
import scrumbringer_client/client_state/member/skills as member_skills
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/helpers/auth as helpers_auth
import scrumbringer_client/helpers/dicts as helpers_dicts
import scrumbringer_client/helpers/i18n as helpers_i18n
import scrumbringer_client/helpers/toast as helpers_toast
import scrumbringer_client/i18n/text as i18n_text

// =============================================================================
// Fetch Handlers
// =============================================================================

/// Handle successful my capability IDs fetch.
pub fn handle_my_capability_ids_fetched_ok(
  model: Model,
  ids: List(Int),
) -> #(Model, Effect(Msg)) {
  #(
    update_member_skills(model, fn(skills) {
      member_skills.Model(
        ..skills,
        member_my_capability_ids: Loaded(ids),
        member_my_capability_ids_edit: helpers_dicts.ids_to_bool_dict(ids),
      )
    }),
    effect.none(),
  )
}

/// Handle failed my capability IDs fetch.
pub fn handle_my_capability_ids_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  helpers_auth.handle_401_or(model, err, fn() {
    #(
      update_member_skills(model, fn(skills) {
        member_skills.Model(..skills, member_my_capability_ids: Failed(err))
      }),
      effect.none(),
    )
  })
}

// =============================================================================
// Toggle Handlers
// =============================================================================

/// Toggle a capability checkbox in the edit state.
pub fn handle_toggle_capability(model: Model, id: Int) -> #(Model, Effect(Msg)) {
  let next = case
    dict.get(model.member.skills.member_my_capability_ids_edit, id)
  {
    Ok(v) -> !v
    Error(_) -> True
  }

  #(
    update_member_skills(model, fn(skills) {
      member_skills.Model(
        ..skills,
        member_my_capability_ids_edit: dict.insert(
          model.member.skills.member_my_capability_ids_edit,
          id,
          next,
        ),
      )
    }),
    effect.none(),
  )
}

// =============================================================================
// Save Handlers
// =============================================================================

/// Handle save capabilities button click.
pub fn handle_save_capabilities_clicked(model: Model) -> #(Model, Effect(Msg)) {
  case
    model.member.skills.member_my_capabilities_in_flight,
    model.core.selected_project_id,
    model.core.user
  {
    True, _, _ -> #(model, effect.none())
    _, opt.None, _ -> #(model, effect.none())
    _, _, opt.None -> #(model, effect.none())
    False, opt.Some(project_id), opt.Some(user) -> {
      let ids =
        helpers_dicts.bool_dict_to_ids(
          model.member.skills.member_my_capability_ids_edit,
        )
      let model =
        update_member_skills(model, fn(skills) {
          member_skills.Model(
            ..skills,
            member_my_capabilities_in_flight: True,
            member_my_capabilities_error: opt.None,
          )
        })
      #(
        model,
        api_tasks.put_member_capability_ids(
          project_id,
          user.id,
          ids,
          fn(result) -> Msg {
            PoolMsg(pool_messages.MemberMyCapabilityIdsSaved(result))
          },
        ),
      )
    }
  }
}

/// Handle successful save capabilities response.
pub fn handle_save_capabilities_ok(
  model: Model,
  ids: List(Int),
) -> #(Model, Effect(Msg)) {
  let model =
    update_member_skills(model, fn(skills) {
      member_skills.Model(
        ..skills,
        member_my_capabilities_in_flight: False,
        member_my_capability_ids: Loaded(ids),
        member_my_capability_ids_edit: helpers_dicts.ids_to_bool_dict(ids),
      )
    })
  let toast_fx =
    helpers_toast.toast_success(helpers_i18n.i18n_t(
      model,
      i18n_text.SkillsSaved,
    ))
  #(model, toast_fx)
}

/// Handle failed save capabilities response.
pub fn handle_save_capabilities_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  helpers_auth.handle_401_or(model, err, fn() {
    let refetch_effect = case model.core.selected_project_id, model.core.user {
      opt.Some(project_id), opt.Some(user) ->
        api_tasks.get_member_capability_ids(
          project_id,
          user.id,
          fn(result) -> Msg {
            PoolMsg(pool_messages.MemberMyCapabilityIdsFetched(result))
          },
        )
      _, _ -> effect.none()
    }
    let model =
      update_member_skills(model, fn(skills) {
        member_skills.Model(
          ..skills,
          member_my_capabilities_in_flight: False,
          member_my_capabilities_error: opt.Some(err.message),
        )
      })
    let toast_fx = helpers_toast.toast_error(err.message)
    #(model, effect.batch([refetch_effect, toast_fx]))
  })
}

fn update_member_skills(
  model: Model,
  f: fn(member_skills.Model) -> member_skills.Model,
) -> Model {
  update_member(model, fn(member) {
    let skills = member.skills
    MemberModel(..member, skills: f(skills))
  })
}
