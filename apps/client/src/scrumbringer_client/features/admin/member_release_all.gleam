////
//// ## Mission
////
//// Handles releasing all claimed tasks for a project member.
////
//// ## Responsibilities
////
//// - Show release-all confirmation dialog
//// - Submit release-all request
//// - Handle result feedback
////
//// ## Relations
////
//// - **features/admin/update.gleam**: Re-exports handlers
//// - **api/projects.gleam**: Release-all API call

import gleam/int
import gleam/list
import gleam/option as opt

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError}
import domain/org.{type OrgUser, OrgUser}
import domain/org_role
import domain/project.{type ProjectMember, ProjectMember}
import domain/remote.{Loaded}
import scrumbringer_client/api/projects as api_projects
import scrumbringer_client/client_state.{
  type Model, type Msg, admin_msg, update_admin,
}
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/admin/members as admin_members
import scrumbringer_client/client_state/types as state_types
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/helpers/auth as helpers_auth
import scrumbringer_client/helpers/i18n as helpers_i18n
import scrumbringer_client/helpers/lookup as helpers_lookup
import scrumbringer_client/helpers/toast as helpers_toast
import scrumbringer_client/i18n/text as i18n_text

// =============================================================================
// Confirmation Handlers
// =============================================================================

/// Handle release-all click (show confirmation).
pub fn handle_member_release_all_clicked(
  model: Model,
  user_id: Int,
  claimed_count: Int,
) -> #(Model, Effect(Msg)) {
  let maybe_user =
    helpers_lookup.resolve_org_user(
      model.admin.members.org_users_cache,
      user_id,
    )

  let user = case maybe_user {
    opt.Some(user) -> user
    opt.None -> fallback_org_user(user_id)
  }

  #(
    update_admin(model, fn(admin) {
      update_members(admin, fn(members_state) {
        admin_members.Model(
          ..members_state,
          members_release_confirm: opt.Some(state_types.ReleaseAllTarget(
            user: user,
            claimed_count: claimed_count,
          )),
          members_release_error: opt.None,
        )
      })
    }),
    effect.none(),
  )
}

/// Handle release-all cancel.
pub fn handle_member_release_all_cancelled(
  model: Model,
) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      update_members(admin, fn(members_state) {
        admin_members.Model(
          ..members_state,
          members_release_confirm: opt.None,
          members_release_error: opt.None,
        )
      })
    }),
    effect.none(),
  )
}

/// Handle release-all confirmation.
pub fn handle_member_release_all_confirmed(
  model: Model,
) -> #(Model, Effect(Msg)) {
  case model.admin.members.members_release_in_flight {
    opt.Some(_) -> #(model, effect.none())
    opt.None ->
      case
        model.core.selected_project_id,
        model.admin.members.members_release_confirm
      {
        opt.Some(project_id),
          opt.Some(state_types.ReleaseAllTarget(user: user, ..))
        -> {
          let model =
            update_admin(model, fn(admin) {
              update_members(admin, fn(members_state) {
                admin_members.Model(
                  ..members_state,
                  members_release_in_flight: opt.Some(user.id),
                  members_release_error: opt.None,
                )
              })
            })
          #(
            model,
            api_projects.release_all_member_tasks(
              project_id,
              user.id,
              fn(result) {
                admin_msg(admin_messages.MemberReleaseAllResult(result))
              },
            ),
          )
        }
        _, _ -> #(model, effect.none())
      }
  }
}

// =============================================================================
// Result Handlers
// =============================================================================

/// Handle release-all success.
pub fn handle_member_release_all_ok(
  model: Model,
  result: api_projects.ReleaseAllResult,
) -> #(Model, Effect(Msg)) {
  let #(user_name, user_id, _claimed_count) = case
    model.admin.members.members_release_confirm
  {
    opt.Some(state_types.ReleaseAllTarget(
      user: user,
      claimed_count: claimed_count,
    )) -> #(user.email, user.id, claimed_count)
    opt.None -> #("", 0, 0)
  }

  let api_projects.ReleaseAllResult(released_count: released_count, ..) = result

  let updated_members = case model.admin.members.members {
    Loaded(members) ->
      Loaded(
        list.map(members, fn(m: ProjectMember) {
          case m.user_id == user_id {
            True -> ProjectMember(..m, claimed_count: 0)
            False -> m
          }
        }),
      )
    other -> other
  }

  let model =
    update_admin(model, fn(admin) {
      update_members(admin, fn(members_state) {
        admin_members.Model(
          ..members_state,
          members_release_confirm: opt.None,
          members_release_in_flight: opt.None,
          members_release_error: opt.None,
          members: updated_members,
        )
      })
    })

  let toast_fx = case released_count == 0 {
    True ->
      helpers_toast.toast_warning(helpers_i18n.i18n_t(
        model,
        i18n_text.ReleaseAllNone(user_name),
      ))
    False ->
      helpers_toast.toast_success(helpers_i18n.i18n_t(
        model,
        i18n_text.ReleaseAllSuccess(released_count, user_name),
      ))
  }

  #(model, toast_fx)
}

/// Handle release-all error.
pub fn handle_member_release_all_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  let user_name = case model.admin.members.members_release_confirm {
    opt.Some(state_types.ReleaseAllTarget(user: user, ..)) -> user.email
    opt.None -> ""
  }

  helpers_auth.handle_401_or(model, err, fn() {
    let message = case err.code {
      "FORBIDDEN" -> helpers_i18n.i18n_t(model, i18n_text.NotPermitted)
      "SELF_RELEASE" ->
        helpers_i18n.i18n_t(model, i18n_text.ReleaseAllSelfError)
      "NOT_FOUND" -> err.message
      _ -> helpers_i18n.i18n_t(model, i18n_text.ReleaseAllError(user_name))
    }

    #(
      update_admin(model, fn(admin) {
        update_members(admin, fn(members_state) {
          admin_members.Model(
            ..members_state,
            members_release_in_flight: opt.None,
            members_release_error: opt.Some(message),
          )
        })
      }),
      helpers_toast.toast_warning(message),
    )
  })
}

// =============================================================================
// Private Helpers
// =============================================================================

fn fallback_org_user(user_id: Int) -> OrgUser {
  OrgUser(
    id: user_id,
    email: "User #" <> int.to_string(user_id),
    org_role: org_role.Member,
    created_at: "",
  )
}

fn update_members(
  admin: admin_state.AdminModel,
  f: fn(admin_members.Model) -> admin_members.Model,
) -> admin_state.AdminModel {
  admin_state.AdminModel(..admin, members: f(admin.members))
}
