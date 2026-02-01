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
import domain/project.{type ProjectMember, ProjectMember}
import scrumbringer_client/api/projects as api_projects
import scrumbringer_client/client_state.{
  type Model, type Msg, AdminModel, Loaded, MemberReleaseAllResult,
  ReleaseAllTarget, admin_msg, update_admin,
}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/update_helpers

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
    update_helpers.resolve_org_user(model.admin.org_users_cache, user_id)

  let user = case maybe_user {
    opt.Some(user) -> user
    opt.None -> fallback_org_user(user_id)
  }

  #(
    update_admin(model, fn(admin) {
      AdminModel(
        ..admin,
        members_release_confirm: opt.Some(ReleaseAllTarget(
          user: user,
          claimed_count: claimed_count,
        )),
        members_release_error: opt.None,
      )
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
      AdminModel(
        ..admin,
        members_release_confirm: opt.None,
        members_release_error: opt.None,
      )
    }),
    effect.none(),
  )
}

/// Handle release-all confirmation.
pub fn handle_member_release_all_confirmed(
  model: Model,
) -> #(Model, Effect(Msg)) {
  case model.admin.members_release_in_flight {
    opt.Some(_) -> #(model, effect.none())
    opt.None ->
      case model.core.selected_project_id, model.admin.members_release_confirm {
        opt.Some(project_id), opt.Some(ReleaseAllTarget(user: user, ..)) -> {
          let model =
            update_admin(model, fn(admin) {
              AdminModel(
                ..admin,
                members_release_in_flight: opt.Some(user.id),
                members_release_error: opt.None,
              )
            })
          #(
            model,
            api_projects.release_all_member_tasks(
              project_id,
              user.id,
              fn(result) { admin_msg(MemberReleaseAllResult(result)) },
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
    model.admin.members_release_confirm
  {
    opt.Some(ReleaseAllTarget(user: user, claimed_count: claimed_count)) -> #(
      user.email,
      user.id,
      claimed_count,
    )
    opt.None -> #("", 0, 0)
  }

  let api_projects.ReleaseAllResult(released_count: released_count, ..) = result

  let updated_members = case model.admin.members {
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
      AdminModel(
        ..admin,
        members_release_confirm: opt.None,
        members_release_in_flight: opt.None,
        members_release_error: opt.None,
        members: updated_members,
      )
    })

  let toast_fx = case released_count == 0 {
    True ->
      update_helpers.toast_warning(update_helpers.i18n_t(
        model,
        i18n_text.ReleaseAllNone(user_name),
      ))
    False ->
      update_helpers.toast_success(update_helpers.i18n_t(
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
  let user_name = case model.admin.members_release_confirm {
    opt.Some(ReleaseAllTarget(user: user, ..)) -> user.email
    opt.None -> ""
  }

  update_helpers.handle_401_or(model, err, fn() {
    let message = case err.code {
      "FORBIDDEN" -> update_helpers.i18n_t(model, i18n_text.NotPermitted)
      "SELF_RELEASE" ->
        update_helpers.i18n_t(model, i18n_text.ReleaseAllSelfError)
      "NOT_FOUND" -> err.message
      _ -> update_helpers.i18n_t(model, i18n_text.ReleaseAllError(user_name))
    }

    #(
      update_admin(model, fn(admin) {
        AdminModel(
          ..admin,
          members_release_in_flight: opt.None,
          members_release_error: opt.Some(message),
        )
      }),
      update_helpers.toast_warning(message),
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
    org_role: "",
    created_at: "",
  )
}
